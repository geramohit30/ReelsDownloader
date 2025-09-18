import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reel_item.dart';
import '../models/instagram_types.dart';
import '../services/download_service.dart';
import '../services/instagram_service.dart';
import '../services/local_api_service.dart';
import '../services/network_diagnostics.dart';
import '../services/instagram_error_handler.dart';
import '../services/instagram_utils.dart';
import '../services/thumbnail_service.dart';
import '../services/web_download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final List<ReelItem> _items = [];
  final DownloadService _downloadService = DownloadService();
  final InstagramService _instagramService = InstagramService();
  double? _activeProgress; // 0..1
  bool _isDownloading = false;
  bool _isFetchingPreview = false;
  String? _errorMessage;

  List<ReelItem> get items => List.unmodifiable(_items);
  double? get activeProgress => _activeProgress;
  bool get isDownloading => _isDownloading;
  bool get isFetchingPreview => _isFetchingPreview;
  String? get errorMessage => _errorMessage;

  static const _prefsKey = 'downloads_v1';

  /// Fetches reel data using local API service with fallback to Instagram service
  Future<InstagramPostData> fetchReelFromLocalApi(String reelUrl) async {
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    _isFetchingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check content type to determine strategy
      final isReel = InstagramUtils.isReelUrl(reelUrl);
      final isStory = InstagramUtils.isStoryUrl(reelUrl);
      final isPost = InstagramUtils.isPostUrl(reelUrl);
      
      print('🔍 FETCH TYPE DETECTION:');
      print('   • URL: $reelUrl');
      print('   • Is Reel: $isReel');
      print('   • Is Story: $isStory');
      print('   • Is Post: $isPost');

      // For non-reel content (Stories, Posts, TV), ONLY use API
      if (!isReel) {
        print('🎯 NON-REEL FETCH: Using API-only strategy (no scraping fallback)');
        return await _fetchFromApiOnly(reelUrl);
      }

      // For reels, use Local API first with Instagram service fallback
      print('🎬 REEL FETCH: Using Local API with Instagram service fallback');
      
      // First test if the local API is available
      final isApiAvailable = await LocalApiService.testConnection();
      if (!isApiAvailable) {
        print(
          '⚠️ LOCAL API: Server test failed, trying fallback to Instagram service',
        );
        return await _fallbackToInstagramService(reelUrl);
      }

      // Fetch data from local API (handles both reels and stories)
      final reelData = await LocalApiService.fetchInstagramReel(
        reelUrl,
        maxRetries: 2,
        retryDelay: const Duration(seconds: 3),
      );

      print('✅ Local API returned: ${reelData.toString()}');

      // Detect content type from URL (JPG = story, MP4 = reel)
      final isStoryContent = reelData.mediaUrl.toLowerCase().contains('.jpg');
      print('   • Content Type: ${isStoryContent ? "Story (JPG)" : "Reel (MP4)"}');

      // Convert to InstagramPostData format
      final postData = InstagramPostData(
        id: reelData.id,
        shortcode: reelData.id,
        videoUrl:
            isStoryContent ? null : reelData.mediaUrl, // Video URL only for reels
        displayUrl:
            isStoryContent
                ? reelData.mediaUrl
                : reelData.thumbnailUrl, // Image URL for stories
        caption: reelData.title,
        username: reelData.author,
        isVideo: !isStoryContent, // Stories are images, reels are videos
        takenAtTimestamp: DateTime.now(),
      );

      return postData;
    } catch (e) {
      print('❌ Local API failed: ${e.toString()}');

      // Only allow fallback for reels
      final isReel = InstagramUtils.isReelUrl(reelUrl);
      if (isReel) {
        // If Local API fails for reels, try fallback to Instagram service
        if (e is LocalApiException &&
            (e.type == LocalApiErrorType.timeout ||
                e.type == LocalApiErrorType.connectionError ||
                e.type == LocalApiErrorType.serverError)) {
          print('🔄 FALLBACK: Attempting Instagram service as backup for reel...');
          try {
            return await _fallbackToInstagramService(reelUrl);
          } catch (fallbackError) {
            print('❌ FALLBACK FAILED: ${fallbackError.toString()}');
            _errorMessage = e.userFriendlyMessage;
            rethrow;
          }
        }
      } else {
        // For non-reel content, no fallback allowed
        print('❌ NON-REEL CONTENT: API-only strategy failed, no fallback available');
      }

      final exception = e is Exception ? e : Exception(e.toString());
      if (e is LocalApiException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = 'Local API Error: ${e.toString()}';
      }
      rethrow;
    } finally {
      _isFetchingPreview = false;
      notifyListeners();
    }
  }

  /// Fallback method to use Instagram service when Local API fails
  Future<InstagramPostData> _fallbackToInstagramService(String reelUrl) async {
    print('🔄 FALLBACK: Using Instagram service for: $reelUrl');

    try {
      final postData = await _instagramService.getPostDataOptimized(reelUrl);
      print('✅ FALLBACK SUCCESS: Instagram service returned data');
      return postData;
    } catch (e) {
      print('❌ FALLBACK ERROR: Instagram service failed: ${e.toString()}');

      final exception = e is Exception ? e : Exception(e.toString());
      if (InstagramErrorHandler.isNetworkIssue(exception)) {
        try {
          final diagnostics = await NetworkDiagnostics.runDiagnostics();
          final report = NetworkDiagnostics.generateTroubleshootingReport(
            diagnostics,
          );
          throw Exception('Network Connection Issue\n\n$report');
        } catch (diagError) {
          throw Exception(
            InstagramErrorHandler.getHelpfulErrorMessage(exception),
          );
        }
      } else {
        throw Exception(
          InstagramErrorHandler.getHelpfulErrorMessage(exception),
        );
      }
    }
  }

  /// Helper method to fetch data only from API (no scraping fallback)
  Future<InstagramPostData> _fetchFromApiOnly(String reelUrl) async {
    print('🔥 API-ONLY MODE: Fetching data exclusively from API');
    
    // Test if the local API is available
    final isApiAvailable = await LocalApiService.testConnection();
    if (!isApiAvailable) {
      throw Exception('Local API server is not available. Non-reel content requires API access.');
    }

    // Fetch data from local API
    final reelData = await LocalApiService.fetchInstagramReel(
      reelUrl,
      maxRetries: 2,
      retryDelay: const Duration(seconds: 3),
    );

    print('✅ API SUCCESS: Local API returned data');

    // Detect content type from URL (JPG = story, MP4 = reel)
    final isStoryContent = reelData.mediaUrl.toLowerCase().contains('.jpg');
    print('   • Content Type: ${isStoryContent ? "Story (JPG)" : "Reel (MP4)"}');

    // Convert to InstagramPostData format
    final postData = InstagramPostData(
      id: reelData.id,
      shortcode: reelData.id,
      videoUrl:
          isStoryContent ? null : reelData.mediaUrl, // Video URL only for reels
      displayUrl:
          isStoryContent
              ? reelData.mediaUrl
              : reelData.thumbnailUrl, // Image URL for stories
      caption: reelData.title,
      username: reelData.author,
      isVideo: !isStoryContent, // Stories are images, reels are videos
      takenAtTimestamp: DateTime.now(),
    );

    return postData;
  }

  /// Helper method to download content only from API (no scraping fallback)
  Future<void> _downloadFromApiOnly(String reelUrl) async {
    print('🔥 API-ONLY DOWNLOAD: Using API exclusively for non-reel content');
    
    // Test if the local API is available
    final isApiAvailable = await LocalApiService.testConnection();
    if (!isApiAvailable) {
      throw Exception('Local API server is not available. Non-reel content requires API access.');
    }

    // Get download URL from Local API
    final reelData = await LocalApiService.fetchInstagramReel(
      reelUrl,
      maxRetries: 2,
      retryDelay: const Duration(seconds: 3),
    );

    // Download directly from the provided URL
    final reelItem = await _downloadFromUrl(
      downloadUrl: reelData.mediaUrl,
      originalUrl: reelUrl,
      title: reelData.title,
      author: reelData.author,
      onProgress: (progress) {
        _activeProgress = progress;
        notifyListeners();
      },
    );

    await addItem(reelItem);
    _activeProgress = null;
  }

  /// Fetches reel data for preview without downloading with Local API fallback
  Future<InstagramPostData> fetchReelForPreview(String reelUrl) async {
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    _isFetchingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if this is a reel or other content type
      final isReel = InstagramUtils.isReelUrl(reelUrl);
      final isStory = InstagramUtils.isStoryUrl(reelUrl);
      final isPost = InstagramUtils.isPostUrl(reelUrl);
      
      print('🔍 CONTENT TYPE DETECTION:');
      print('   • URL: $reelUrl');
      print('   • Is Reel: $isReel');
      print('   • Is Story: $isStory');
      print('   • Is Post: $isPost');

      // For non-reel content (Stories, Posts, TV), ONLY use API - no scraping fallback
      if (!isReel) {
        print('🎯 NON-REEL CONTENT: Using API-only strategy (no scraping fallback)');
        return await _fetchFromApiOnly(reelUrl);
      }

      // For reels, use the existing strategy (Instagram service first, then API fallback)
      print('🎬 REEL CONTENT: Using Instagram service with API fallback');
      
      try {
        // First try the Instagram service (primary method for reels)
        final postData = await _instagramService.getPostDataOptimized(reelUrl);
        print('✅ PRIMARY SUCCESS: Instagram service returned data for reel preview');
        return postData;
      } catch (e) {
        print('❌ PRIMARY FAILED: Instagram service failed for reel: ${e.toString()}');
        print('🔄 FALLBACK: Trying Local API as backup for reel...');

        // If Instagram service fails for reels, try Local API as fallback
        return await _fetchFromApiOnly(reelUrl);
      }
    } catch (e) {
      print('❌ ALL METHODS FAILED: ${e.toString()}');
      
      final exception = e is Exception ? e : Exception(e.toString());
      if (InstagramErrorHandler.isNetworkIssue(exception)) {
        try {
          final diagnostics = await NetworkDiagnostics.runDiagnostics();
          final report = NetworkDiagnostics.generateTroubleshootingReport(
            diagnostics,
          );
          _errorMessage = 'Network Connection Issue\n\n$report';
        } catch (diagError) {
          _errorMessage = InstagramErrorHandler.getHelpfulErrorMessage(exception);
        }
      } else {
        _errorMessage = InstagramErrorHandler.getHelpfulErrorMessage(exception);
      }
      rethrow;
    } finally {
      _isFetchingPreview = false;
      notifyListeners();
    }
  }

  /// Downloads a reel/story from Instagram URL using Local API first
  Future<void> downloadReel(String reelUrl) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    _isDownloading = true;
    _errorMessage = null;
    _activeProgress = 0.0;
    notifyListeners();

    try {
      // Check if we're running on web
      bool isWeb = identical(0, 0.0); // Hack to detect web platform

      if (isWeb) {
        // On web, we'll use a different approach
        await _downloadReelForWeb(reelUrl);
        return;
      }

      // Check content type to determine strategy
      final isReel = InstagramUtils.isReelUrl(reelUrl);
      final isStory = InstagramUtils.isStoryUrl(reelUrl);
      final isPost = InstagramUtils.isPostUrl(reelUrl);
      
      print('🔍 DOWNLOAD TYPE DETECTION:');
      print('   • URL: $reelUrl');
      print('   • Is Reel: $isReel');
      print('   • Is Story: $isStory');
      print('   • Is Post: $isPost');

      // For non-reel content (Stories, Posts, TV), ONLY use API
      if (!isReel) {
        print('🎯 NON-REEL DOWNLOAD: Using API-only strategy');
        await _downloadFromApiOnly(reelUrl);
        return;
      }

      // For reels, try Local API first, then Instagram service fallback
      print('🎬 REEL DOWNLOAD: Using Local API with Instagram service fallback');
      
      final isApiAvailable = await LocalApiService.testConnection();

      if (isApiAvailable) {
        try {
          print('🚀 DOWNLOAD: Using Local API for reel: $reelUrl');

          // Get download URL from Local API
          final reelData = await LocalApiService.fetchInstagramReel(
            reelUrl,
            maxRetries: 2,
            retryDelay: const Duration(seconds: 3),
          );

          // Download directly from the provided URL
          final reelItem = await _downloadFromUrl(
            downloadUrl: reelData.mediaUrl,
            originalUrl: reelUrl,
            title: reelData.title,
            author: reelData.author,
            onProgress: (progress) {
              _activeProgress = progress;
              notifyListeners();
            },
          );

          await addItem(reelItem);
          _activeProgress = null;
          return;
        } catch (e) {
          print('❌ Local API download failed for reel: ${e.toString()}');
          // Fall through to Instagram service
        }
      }

      // Fallback to Instagram service for reels only
      print('🔄 FALLBACK: Using Instagram service for reel download');
      final reelItem = await _downloadService.downloadInstagramReel(
        reelUrl: reelUrl,
        onProgress: (progress) {
          _activeProgress = progress;
          notifyListeners();
        },
      );

      await addItem(reelItem);
      _activeProgress = null;
    } catch (e) {
      _activeProgress = null;

      // If it's a network error, run diagnostics for better error reporting
      final exception = e is Exception ? e : Exception(e.toString());

      if (InstagramErrorHandler.isNetworkIssue(exception)) {
        try {
          final diagnostics = await NetworkDiagnostics.runDiagnostics();
          final report = NetworkDiagnostics.generateTroubleshootingReport(
            diagnostics,
          );
          _errorMessage = 'Network Connection Issue\n\n$report';
        } catch (diagError) {
          _errorMessage = InstagramErrorHandler.getHelpfulErrorMessage(
            exception,
          );
        }
      } else {
        _errorMessage = InstagramErrorHandler.getHelpfulErrorMessage(exception);
      }

      rethrow;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Special download method for web environment
  Future<void> _downloadReelForWeb(String reelUrl) async {
    try {
      print('🌐 WEB DOWNLOAD: Using Local API for: $reelUrl');

      // Get download URL from Local API
      final reelData = await LocalApiService.fetchInstagramReel(
        reelUrl,
        maxRetries: 2,
        retryDelay: const Duration(seconds: 3),
      );

      // Download the content directly to browser downloads
      final shortcode = reelData.id;
      final fileExtension = reelData.mediaUrl.toLowerCase().contains('.mp4') ? '.mp4' : '.jpg';
      final fileName = 'reel_${shortcode}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      
      // Use the improved web download service
      final filePath = await WebDownloadService.downloadMedia(
        mediaUrl: reelData.mediaUrl,
        fileName: fileName,
        onProgress: (progress) {
          _activeProgress = progress;
          notifyListeners();
        },
      );

      // Create a reel item for the downloads list
      final reelItem = ReelItem(
        id: shortcode,
        sourceUrl: reelUrl,
        filePath: filePath, // This will be a web-download:// path
        createdAt: DateTime.now(),
        thumbnailPath: reelData.thumbnailUrl,
      );

      await addItem(reelItem);
      _activeProgress = null;
      
      // Show success message
      _errorMessage = null;
      
    } catch (e) {
      print('❌ WEB DOWNLOAD FAILED: ${e.toString()}');
      
      // Provide helpful error message for web users
      if (e.toString().contains('CORS') || e.toString().contains('blocked')) {
        _errorMessage = 'Download blocked by browser security.\n\n'
            'This can happen due to CORS restrictions. Try:\n'
            '1. Using a different browser\n'
            '2. Disabling ad blockers temporarily\n'
            '3. Trying again in an incognito/private window\n\n'
            'The download URL will be opened in a new tab as a fallback.';
      } else {
        _errorMessage = 'Web download failed: ${e.toString()}\n\n'
            'For the best experience, please use the mobile app.';
      }
      
      rethrow;
    }
  }

  /// Download directly from a provided URL (used for Local API downloads)
  Future<ReelItem> _downloadFromUrl({
    required String downloadUrl,
    required String originalUrl,
    required String title,
    required String author,
    required void Function(double progress) onProgress,
  }) async {
    // Detect file type from URL
    final isImage =
        downloadUrl.toLowerCase().contains('.jpg') ||
        downloadUrl.toLowerCase().contains('.jpeg');
    final fileExtension = isImage ? 'jpg' : 'mp4';

    // Generate filename
    final shortcode = InstagramUtils.extractShortcodeFromUrl(originalUrl);
    final filename =
        '${isImage ? "story" : "reel"}_${shortcode}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    print('📥 DOWNLOADING: $filename');
    print('   • Source: $downloadUrl');
    print('   • Type: ${isImage ? "Story (JPG)" : "Reel (MP4)"}');

    // Download using the download service helper method
    final filePath = await _downloadService.downloadToAppDir(
      mediaUrl: Uri.parse(downloadUrl),
      onProgress: onProgress,
      suggestedName: filename,
    );

    // Generate thumbnail
    String? thumbnailPath;
    try {
      if (isImage) {
        thumbnailPath = filePath; // Use image as its own thumbnail
      } else {
        thumbnailPath = await ThumbnailService().generate(filePath);
      }
    } catch (_) {
      thumbnailPath = null;
    }

    return ReelItem(
      id: shortcode,
      sourceUrl: originalUrl,
      filePath: filePath,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }

  /// Clears any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return;
    final list =
        (jsonDecode(jsonStr) as List)
            .cast<Map<String, dynamic>>()
            .map(ReelItem.fromJson)
            .toList();
    _items
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  void setProgress(double? p) {
    _activeProgress = p;
    notifyListeners();
  }

  Future<void> addItem(ReelItem item) async {
    _items.insert(0, item);
    await _save();
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final item = _items.removeAt(idx);
    try {
      final f = File(item.filePath);
      if (await f.exists()) await f.delete();
      if (item.thumbnailPath != null) {
        final t = File(item.thumbnailPath!);
        if (await t.exists()) await t.delete();
      }
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  void setIsDownloading(bool v) {
    _isDownloading = v;
    notifyListeners();
  }

  void setIsFetchingPreview(bool v) {
    _isFetchingPreview = v;
    notifyListeners();
  }
}
