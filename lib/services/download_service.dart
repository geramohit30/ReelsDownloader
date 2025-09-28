import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/reel_item.dart';
import '../models/instagram_types.dart';
import 'instagram_service.dart';
import 'instagram_utils.dart';
import 'thumbnail_service.dart';
import 'web_download_service.dart';
import 'local_api_service.dart';

class DownloadService {
  final InstagramService _instagramService = InstagramService();
  final ThumbnailService _thumbnailService = ThumbnailService();
  final Random _random = Random();

  /// Downloads Instagram content (reel/story) from URL and returns ReelItem
  Future<ReelItem> downloadInstagramReel({
    required String reelUrl,
    required void Function(double progress) onProgress,
  }) async {
    // Validate URL
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    // Get post data using optimized method - prioritize Strategy 4 for reels
    final postData = await getPostDataWithStrategy4Priority(reelUrl);

    // Determine media URL and file type
    String mediaUrl;
    String fileExtension;
    bool isVideo;

    if (postData.isVideo && postData.videoUrl != null) {
      // Video content (reels)
      mediaUrl = postData.videoUrl!;
      fileExtension = 'mp4';
      isVideo = true;
    } else if (postData.displayUrl != null) {
      // Image content (stories)
      mediaUrl = postData.displayUrl!;
      fileExtension = 'jpg';
      isVideo = false;
    } else {
      throw Exception('Could not find valid media URL for this content');
    }

    // Generate filename
    final shortcode =
        postData.shortcode ?? InstagramUtils.extractShortcodeFromUrl(reelUrl);
    final filename =
        '${isVideo ? "reel" : "story"}_${shortcode}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // Download media
    final filePath = await downloadToGallery(
      mediaUrl: Uri.parse(mediaUrl),
      onProgress: onProgress,
      suggestedName: filename,
    );

    // Create ReelItem (works for both videos and images)
    String? thumbnailPath;
    try {
      if (kIsWeb) {
        // On web, we can't generate thumbnails easily, so we'll use the original URL or a placeholder
        if (isVideo) {
          // For videos on web, we can't generate thumbnails easily
          // We'll use the source URL as a reference or null
          thumbnailPath = null;
        } else {
          // For images, use the web download path
          thumbnailPath = filePath;
        }
      } else {
        // Mobile/Desktop thumbnail generation
        if (isVideo) {
          // Generate thumbnail from video
          thumbnailPath = await _thumbnailService.generate(filePath);
        } else {
          // For images, use the image itself as thumbnail
          thumbnailPath = filePath;
        }
      }
    } catch (_) {
      thumbnailPath = null;
    }

    return ReelItem(
      id: shortcode,
      sourceUrl: reelUrl,
      filePath: filePath,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }

  /// Get post data with priority to Strategy 4 (Alternative video URL patterns) for reels
  /// If Strategy 4 fails, use our own API as fallback
  Future<InstagramPostData> getPostDataWithStrategy4Priority(String reelUrl) async {
    // Check if this is a reel URL
    final isReel = InstagramUtils.isReelUrl(reelUrl);
    
    if (isReel) {
      print('🎬 REEL DETECTED: Prioritizing Strategy 4 with API fallback');
      
      try {
        // Try Strategy 4 first (Alternative video URL patterns) directly
        print('🔍 TRYING STRATEGY 4: Alternative video URL patterns');
        final videoUrl = await _tryStrategy4Directly(reelUrl);
        
        if (videoUrl != null) {
          print('🟢 ✅ STRATEGY 4 SUCCESS!');
          final shortcode = InstagramUtils.extractShortcodeFromUrl(reelUrl);
          
          return InstagramPostData(
            videoUrl: videoUrl.toString(),
            isVideo: true,
            shortcode: shortcode,
          );
        }
      } catch (e) {
        print('🔴 STRATEGY 4 FAILED: $e');
        // Continue to API fallback
      }
      
      // If Strategy 4 fails, use our own API
      print('🔄 FALLBACK: Using our own API');
      try {
        final reelData = await LocalApiService.fetchInstagramReel(reelUrl);
        
        return InstagramPostData(
          videoUrl: reelData.mediaUrl,
          isVideo: true,
          shortcode: reelData.id,
          caption: reelData.title,
          username: reelData.author,
        );
      } catch (e) {
        print('🔴 API FALLBACK FAILED: $e');
        throw Exception('Both Strategy 4 and API fallback failed: $e');
      }
    } else {
      // For non-reel content, use the existing optimized method
      print('📱 NON-REEL CONTENT: Using existing optimized method');
      return await _instagramService.getPostDataOptimized(reelUrl);
    }
  }

  /// Try Strategy 4 directly: Alternative video URL patterns
  /// This bypasses the Instagram service's full flow and goes straight to Strategy 4
  Future<Uri?> _tryStrategy4Directly(String reelUrl) async {
    try {
      print('🚀 DIRECT STRATEGY 4: Fetching HTML directly for $reelUrl');
      
      // Create HTTP client
      final client = http.Client();
      
      try {
        // Get user agent
        final userAgent = _getOptimalUserAgent();
        
        // Set up headers
        final headers = {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        };

        print('📝 REQUEST HEADERS:');
        headers.forEach((key, value) => print('   • $key: $value'));

        // Make request
        final response = await client
            .get(Uri.parse(reelUrl), headers: headers)
            .timeout(Duration(seconds: 30));

        print('📊 RESPONSE:');
        print('   • Status Code: ${response.statusCode}');
        print('   • Content Length: ${response.body.length}');

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }

        // Get HTML content
        String html;
        try {
          // Try to decode with gzip if needed
          if (response.headers['content-encoding']?.contains('gzip') == true) {
            final decompressed = gzip.decode(response.bodyBytes);
            html = String.fromCharCodes(decompressed);
          } else {
            html = response.body;
          }
        } catch (e) {
          html = response.body; // Fallback to raw body
        }

        // Apply Strategy 4 patterns directly
        print('🔍 APPLYING STRATEGY 4 PATTERNS...');
        final videoUrl = _findAlternativeVideoUrl(html);
        
        if (videoUrl != null && videoUrl.contains('.mp4')) {
          print('🟢 ✅ STRATEGY 4 DIRECT SUCCESS!');
          print('   • Found video URL: $videoUrl');
          return Uri.parse(_unescapeUrl(videoUrl));
        } else {
          print('🔴 STRATEGY 4 DIRECT FAILED: No valid video URL found');
          return null;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Strategy 4 direct failed: $e');
      return null;
    }
  }

  /// Get optimal user agent for Instagram requests
  String _getOptimalUserAgent() {
    final userAgentPool = [
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    ];
    
    return userAgentPool[_random.nextInt(userAgentPool.length)];
  }

  /// Strategy 4 patterns - Alternative video URL patterns
  String? _findAlternativeVideoUrl(String html) {
    final patterns = [
      RegExp(r'"playback_url"\s*:\s*"([^"]+?\.mp4[^"]*)"'),
      RegExp(r'"src"\s*:\s*"([^"]+?fbcdn[^"]*\.mp4[^"]*)"'),
      RegExp(r'"url"\s*:\s*"([^"]+?instagram[^"]*\.mp4[^"]*)"'),
      RegExp(r'"([^"]*scontent[^"]*\.mp4[^"]*)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          print('   • Matched pattern: ${pattern.pattern}');
          return url;
        }
      }
    }
    return null;
  }

  /// Unescape URL
  String _unescapeUrl(String s) {
    try {
      return json.decode('"${s.replaceAll('"', r'\"')}"') as String;
    } catch (_) {
      return s.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
    }
  }

  /// Request storage permissions
  Future<bool> _requestStoragePermissions() async {
    try {
      // Check if we're on Android 13 or higher
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt >= 33) {
          // Android 13+: Request media permissions
          final imagePermission = await Permission.photos.status;
          final videoPermission = await Permission.videos.status;
          
          if (imagePermission.isGranted && videoPermission.isGranted) {
            return true;
          }
          
          // If permissions are permanently denied, open app settings
          if (imagePermission.isPermanentlyDenied || videoPermission.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          
          // Request permissions if not granted
          final imageResult = await Permission.photos.request();
          final videoResult = await Permission.videos.request();
          
          return imageResult.isGranted && videoResult.isGranted;
        } else {
          // Android < 13: Request storage permission
          final storagePermission = await Permission.storage.status;
          
          if (storagePermission.isGranted) {
            return true;
          }
          
          // If permission is permanently denied, open app settings
          if (storagePermission.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          
          // Request permission if not granted
          final result = await Permission.storage.request();
          return result.isGranted;
        }
      } else if (Platform.isIOS) {
        // iOS: Request photos permission
        final photosPermission = await Permission.photos.status;
        
        if (photosPermission.isGranted) {
          return true;
        }
        
        // If permission is permanently denied, open app settings
        if (photosPermission.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }
        
        // Request permission if not granted
        final result = await Permission.photos.request();
        return result.isGranted;
      }
      
      // For other platforms, assume permissions are granted
      return true;
    } catch (e) {
      print('❌ Error requesting storage permissions: $e');
      return false;
    }
  }

  /// Downloads media file to gallery-visible directory (mobile) or triggers browser download (web)
  /// Returns (filePath)
  Future<String> downloadToGallery({
    required Uri mediaUrl,
    required void Function(double progress) onProgress, // 0..1
    String? suggestedName,
  }) async {
    // Check if we're running on web
    if (kIsWeb) {
      print('🌐 WEB MODE: Using browser download for ${suggestedName ?? 'media'}');
      
      // Sanitize filename for web
      final fileName = suggestedName ?? 'media_${DateTime.now().millisecondsSinceEpoch}';
      final safeFileName = WebDownloadService.sanitizeFileName(fileName);
      
      // Use web download service
      return await WebDownloadService.downloadMedia(
        mediaUrl: mediaUrl.toString(),
        fileName: safeFileName,
        onProgress: onProgress,
      );
    }

    // Request storage permissions
    print('🔐 Requesting storage permissions...');
    final hasPermission = await _requestStoragePermissions();
    if (!hasPermission) {
      print('❌ Storage permissions denied');
      throw Exception('Storage permissions are required to save files to your device.');
    }

    // Mobile/Desktop implementation - save to gallery-visible directory
    print('📱 MOBILE MODE: Saving to gallery for ${suggestedName ?? 'media'}');
    
    // Force use of public Downloads directory with Instagram Reels subdirectory
    // Skip getDownloadsDirectory() as it often returns app-private directory
    Directory appDownloadsDir = Directory('/storage/emulated/0/Download/Instagram Reels');
    print('📁 Using forced public Downloads directory with Instagram Reels subdirectory: ${appDownloadsDir.path}');
    
    // Check if Downloads directory exists, if not try to create it
    if (!await appDownloadsDir.exists()) {
      try {
        await appDownloadsDir.create(recursive: true);
        print('📁 Created public Downloads directory with Instagram Reels subdirectory: ${appDownloadsDir.path}');
      } catch (e) {
        print('⚠️ Failed to create public Downloads directory with Instagram Reels subdirectory: $e');
        // Fallback to main Downloads directory
        appDownloadsDir = Directory('/storage/emulated/0/Download');
        if (!await appDownloadsDir.exists()) {
          try {
            await appDownloadsDir.create(recursive: true);
            print('📁 Created public Downloads directory: ${appDownloadsDir.path}');
          } catch (e2) {
            print('⚠️ Failed to create public Downloads directory: $e2');
            // Fallback to getDownloadsDirectory() if forced path fails
            try {
              final fallbackDir = await getDownloadsDirectory();
              if (fallbackDir != null && await fallbackDir.exists()) {
                appDownloadsDir = fallbackDir;
                print('📁 Using fallback Downloads directory: ${appDownloadsDir.path}');
              } else {
                // Final fallback to app documents directory
                final documentsDir = await getApplicationDocumentsDirectory();
                appDownloadsDir = Directory('${documentsDir.path}/Downloads');
                if (!await appDownloadsDir.exists()) {
                  await appDownloadsDir.create(recursive: true);
                }
                print('📁 Using app documents directory: ${appDownloadsDir.path}');
              }
            } catch (fallbackError) {
              print('⚠️ All directory methods failed: $fallbackError');
              // Last resort: use app documents directory
              final documentsDir = await getApplicationDocumentsDirectory();
              appDownloadsDir = Directory('${documentsDir.path}/Downloads');
              if (!await appDownloadsDir.exists()) {
                await appDownloadsDir.create(recursive: true);
              }
              print('📁 Using last resort app documents directory: ${appDownloadsDir.path}');
            }
          }
        }
      }
    }

    // Use a more visible filename format
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = suggestedName ?? 'Instagram_Reel_$timestamp.mp4';
    final file = File('${appDownloadsDir.path}/$name');
    
    print('💾 Saving file to: ${file.path}');

    final req = http.Request('GET', mediaUrl);
    final res = await req.send();

    if (res.statusCode != 200) {
      throw Exception('Download failed (HTTP ${res.statusCode})');
    }

    final sink = file.openWrite();
    final contentLen = res.contentLength ?? 0;
    int received = 0;

    await for (final chunk in res.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (contentLen > 0) {
        onProgress(received / contentLen);
      }
    }

    await sink.flush();
    await sink.close();

    // Notify media scanner to make the file visible in gallery
    try {
      await MediaScanner.loadMedia(path: file.path);
      print('✅ Media scanner notified for: ${file.path}');
    } catch (e) {
      print('⚠️ Failed to notify media scanner: $e');
      // Fallback: try to save to the root Downloads directory for better visibility
      await _saveToRootDownloads(file, name);
    }

    // Additional fallback: scan the directory
    try {
      final directory = file.parent;
      await MediaScanner.loadMedia(path: directory.path);
      print('🔄 Directory scanned for media');
    } catch (e) {
      print('⚠️ Failed to scan directory: $e');
    }

    onProgress(1.0);
    return file.path;
  }

  /// Fallback method to save to root Downloads directory for better gallery visibility
  Future<void> _saveToRootDownloads(File originalFile, String fileName) async {
    try {
      // Try to get the public Downloads directory with Instagram Reels subdirectory
      Directory? downloadsDir = Directory('/storage/emulated/0/Download/Instagram Reels');
      
      // Ensure directory exists
      if (!await downloadsDir.exists()) {
        try {
          await downloadsDir.create(recursive: true);
        } catch (e) {
          print('⚠️ Failed to create Instagram Reels subdirectory in fallback: $e');
          // Fallback to main Downloads directory
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            try {
              await downloadsDir.create(recursive: true);
            } catch (e2) {
              print('⚠️ Failed to create Downloads directory in fallback: $e2');
              // Try getDownloadsDirectory() as last resort
              try {
                downloadsDir = await getDownloadsDirectory();
              } catch (e3) {
                print('⚠️ Failed to get Downloads directory in fallback: $e3');
                return; // Give up if we can't get any directory
              }
            }
          }
        }
      }
      
      if (downloadsDir != null) {
        // Create a more visible filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = fileName.contains('.') ? fileName.split('.').last : 'mp4';
        final visibleFileName = 'Instagram_Reel_$timestamp.$extension';
        
        final rootFile = File('${downloadsDir.path}/$visibleFileName');
        await originalFile.copy(rootFile.path);
        await originalFile.delete(); // Remove the original file
        
        // Notify media scanner for the root file
        await MediaScanner.loadMedia(path: rootFile.path);
        print('✅ Fallback: Saved to root Downloads and notified media scanner');
      }
    } catch (e) {
      print('⚠️ Fallback save to root Downloads failed: $e');
    }
  }
}