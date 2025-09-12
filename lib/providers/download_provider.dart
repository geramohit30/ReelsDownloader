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

  /// Fetches reel data using appropriate strategy based on content type
  /// Stories: Direct to Local API
  /// Reels: Local API with fallback to Instagram service 
  Future<InstagramPostData> fetchReelFromLocalApi(String reelUrl) async {
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    _isFetchingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if this is a story URL
      if (InstagramUtils.isInstagramStoryUrl(reelUrl)) {
        print('🚀 STORY DETECTED: Using Local API directly for: $reelUrl');
        return await _fetchStoryFromLocalApi(reelUrl);
      } else {
        print('🚀 REEL DETECTED: Using Local API with Instagram service fallback for: $reelUrl');
        return await _fetchReelWithFallback(reelUrl);
      }
    } finally {
      _isFetchingPreview = false;
      notifyListeners();
    }
  }

  /// Fetches story data directly from Local API (no scraping fallback)
  Future<InstagramPostData> _fetchStoryFromLocalApi(String storyUrl) async {
    try {
      print('📱 STORY: Direct API call to Local API for: $storyUrl');

      // Test if the local API is available
      final isApiAvailable = await LocalApiService.testConnection();
      if (!isApiAvailable) {
        throw Exception(
          'Local API server is not available. Stories require the Local API service to be running.',
        );
      }

      // Fetch data from local API for stories
      final reelData = await LocalApiService.fetchInstagramReel(
        storyUrl,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 3),
      );

      print('✅ STORY: Local API returned: ${reelData.toString()}');

      // Detect content type from URL (JPG = story, MP4 = reel)
      final isStory = reelData.mediaUrl.toLowerCase().contains('.jpg');
      print('   • Content Type: ${isStory ? "Story (JPG)" : "Story (MP4)"}');

      // Convert to InstagramPostData format
      final postData = InstagramPostData(
        id: reelData.id,
        shortcode: reelData.id,
        videoUrl: isStory ? null : reelData.mediaUrl, // Video URL only for video stories
        displayUrl: isStory ? reelData.mediaUrl : reelData.thumbnailUrl, // Image URL for image stories
        caption: reelData.title,
        username: reelData.author,
        isVideo: !isStory, // Most stories are images
        takenAtTimestamp: DateTime.now(),
      );

      return postData;
    } catch (e) {
      print('❌ STORY: Local API failed: ${e.toString()}');
      
      if (e is LocalApiException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = 'Story Download Error: ${e.toString()}';
      }
      rethrow;
    }
  }

  /// Fetches reel data using Local API first with Instagram service fallback
  Future<InstagramPostData> _fetchReelWithFallback(String reelUrl) async {
    try {
      print('🎬 REEL: Primary attempt with Local API for: $reelUrl');

      // First test if the local API is available
      final isApiAvailable = await LocalApiService.testConnection();
      if (!isApiAvailable) {
        print('⚠️ REEL: Local API server test failed, trying fallback to Instagram service');
        return await _fallbackToInstagramService(reelUrl);
      }

      // Fetch data from local API (handles both reels and stories)
      final reelData = await LocalApiService.fetchInstagramReel(
        reelUrl,
        maxRetries: 2,
        retryDelay: const Duration(seconds: 3),
      );

      print('✅ REEL: Local API returned: ${reelData.toString()}');

      // Detect content type from URL (JPG = story, MP4 = reel)
      final isStory = reelData.mediaUrl.toLowerCase().contains('.jpg');
      print('   • Content Type: ${isStory ? "Story (JPG)" : "Reel (MP4)"}');

      // Convert to InstagramPostData format
      final postData = InstagramPostData(
        id: reelData.id,
        shortcode: reelData.id,
        videoUrl: isStory ? null : reelData.mediaUrl, // Video URL only for reels
        displayUrl: isStory ? reelData.mediaUrl : reelData.thumbnailUrl, // Image URL for stories
        caption: reelData.title,
        username: reelData.author,
        isVideo: !isStory, // Stories are images, reels are videos
        takenAtTimestamp: DateTime.now(),
      );

      return postData;
    } catch (e) {
      print('❌ REEL: Local API failed: ${e.toString()}');

      // If Local API fails, try fallback to Instagram service
      if (e is LocalApiException &&
          (e.type == LocalApiErrorType.timeout ||
              e.type == LocalApiErrorType.connectionError ||
              e.type == LocalApiErrorType.serverError)) {
        print('🔄 REEL: FALLBACK: Attempting Instagram service as backup...');
        try {
          return await _fallbackToInstagramService(reelUrl);
        } catch (fallbackError) {
          print('❌ REEL: FALLBACK FAILED: ${fallbackError.toString()}');
          _errorMessage = e.userFriendlyMessage;
          rethrow;
        }
      }

      final exception = e is Exception ? e : Exception(e.toString());
      if (e is LocalApiException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = 'Local API Error: ${e.toString()}';
      }
      rethrow;
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

  /// Fetches reel data for preview with appropriate strategy based on content type
  /// Stories: Direct to Local API
  /// Reels: Instagram service with Local API fallback
  Future<InstagramPostData> fetchReelForPreview(String reelUrl) async {
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    _isFetchingPreview = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if this is a story URL
      if (InstagramUtils.isInstagramStoryUrl(reelUrl)) {
        print('🚀 STORY PREVIEW: Using Local API directly for: $reelUrl');
        return await _fetchStoryFromLocalApi(reelUrl);
      } else {
        print('🚀 REEL PREVIEW: Using Instagram service with Local API fallback for: $reelUrl');
        return await _fetchReelPreviewWithFallback(reelUrl);
      }
    } finally {
      _isFetchingPreview = false;
      notifyListeners();
    }
  }

  /// Fetches reel preview using Instagram service first with Local API fallback
  Future<InstagramPostData> _fetchReelPreviewWithFallback(String reelUrl) async {
    try {
      print('🎬 REEL PREVIEW: Primary attempt with Instagram Service for: $reelUrl');

      // First try the Instagram service (primary method for reels)
      final postData = await _instagramService.getPostDataOptimized(reelUrl);
      print('✅ REEL PREVIEW: Instagram service returned data for preview');
      return postData;
    } catch (e) {
      print('❌ REEL PREVIEW: Instagram service failed: ${e.toString()}');
      print('🔄 REEL PREVIEW: Trying Local API as backup...');

      // If Instagram service fails, try Local API as fallback
      try {
        // Test if the local API is available
        final isApiAvailable = await LocalApiService.testConnection();
        if (!isApiAvailable) {
          print('⚠️ REEL PREVIEW: Local API server not available');
          throw e; // Re-throw original Instagram service error
        }

        // Fetch data from local API (handles both reels and stories)
        final reelData = await LocalApiService.fetchInstagramReel(
          reelUrl,
          maxRetries: 2,
          retryDelay: const Duration(seconds: 3),
        );

        print('✅ REEL PREVIEW: Local API returned data for preview');

        // Detect content type from URL (JPG = story, MP4 = reel)
        final isStory = reelData.mediaUrl.toLowerCase().contains('.jpg');
        print('   • Content Type: ${isStory ? "Story (JPG)" : "Reel (MP4)"}');

        // Convert to InstagramPostData format
        final postData = InstagramPostData(
          id: reelData.id,
          shortcode: reelData.id,
          videoUrl: isStory ? null : reelData.mediaUrl, // Video URL only for reels
          displayUrl: isStory ? reelData.mediaUrl : reelData.thumbnailUrl, // Image URL for stories
          caption: reelData.title,
          username: reelData.author,
          isVideo: !isStory, // Stories are images, reels are videos
          takenAtTimestamp: DateTime.now(),
        );

        return postData;
      } catch (fallbackError) {
        print('❌ REEL PREVIEW: Local API also failed: ${fallbackError.toString()}');
        print('🔴 REEL PREVIEW: Both Instagram service and Local API failed');

        // If both methods fail, prioritize the original Instagram service error
        // as it's the primary method, but mention the fallback attempt
        final exception = e is Exception ? e : Exception(e.toString());

        if (InstagramErrorHandler.isNetworkIssue(exception)) {
          try {
            final diagnostics = await NetworkDiagnostics.runDiagnostics();
            final report = NetworkDiagnostics.generateTroubleshootingReport(
              diagnostics,
            );
            _errorMessage = 'Network Connection Issue\n\n$report';
          } catch (diagError) {
            _errorMessage =
                InstagramErrorHandler.getHelpfulErrorMessage(exception) +
                '\n\nFallback to Local API also failed: ${fallbackError.toString()}';
          }
        } else {
          _errorMessage =
              InstagramErrorHandler.getHelpfulErrorMessage(exception) +
              '\n\nFallback to Local API also failed: ${fallbackError.toString()}';
        }

        rethrow;
      }
    }
  }

  /// Downloads a reel/story from Instagram URL using appropriate strategy
  /// Stories: Direct to Local API
  /// Reels: Local API with Instagram service fallback
  Future<void> downloadReel(String reelUrl) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    _isDownloading = true;
    _errorMessage = null;
    _activeProgress = 0.0;
    notifyListeners();

    try {
      // Check if this is a story URL
      if (InstagramUtils.isInstagramStoryUrl(reelUrl)) {
        print('🚀 STORY DOWNLOAD: Using Local API directly for: $reelUrl');
        await _downloadStoryFromLocalApi(reelUrl);
      } else {
        print('🚀 REEL DOWNLOAD: Using Local API with Instagram service fallback for: $reelUrl');
        await _downloadReelWithFallback(reelUrl);
      }

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

  /// Downloads story using Local API directly (no scraping fallback)
  Future<void> _downloadStoryFromLocalApi(String storyUrl) async {
    try {
      print('📱 STORY DOWNLOAD: Direct API call to Local API for: $storyUrl');

      // Test if the local API is available
      final isApiAvailable = await LocalApiService.testConnection();
      if (!isApiAvailable) {
        throw Exception(
          'Local API server is not available. Stories require the Local API service to be running.',
        );
      }

      // Get download URL from Local API
      final reelData = await LocalApiService.fetchInstagramReel(
        storyUrl,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 3),
      );

      // Download directly from the provided URL
      final reelItem = await _downloadFromUrl(
        downloadUrl: reelData.mediaUrl,
        originalUrl: storyUrl,
        title: reelData.title,
        author: reelData.author,
        onProgress: (progress) {
          _activeProgress = progress;
          notifyListeners();
        },
      );

      await addItem(reelItem);
    } catch (e) {
      print('❌ STORY DOWNLOAD: Local API failed: ${e.toString()}');
      rethrow;
    }
  }

  /// Downloads reel using Local API first with Instagram service fallback
  Future<void> _downloadReelWithFallback(String reelUrl) async {
    // Try Local API first
    final isApiAvailable = await LocalApiService.testConnection();

    if (isApiAvailable) {
      try {
        print('🎬 REEL DOWNLOAD: Using Local API for: $reelUrl');

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
        return;
      } catch (e) {
        print('❌ REEL DOWNLOAD: Local API failed: ${e.toString()}');
        // Fall through to Instagram service
      }
    }

    // Fallback to Instagram service
    print('🔄 REEL DOWNLOAD: Using Instagram service fallback');
    final reelItem = await _downloadService.downloadInstagramReel(
      reelUrl: reelUrl,
      onProgress: (progress) {
        _activeProgress = progress;
        notifyListeners();
      },
    );

    await addItem(reelItem);
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
