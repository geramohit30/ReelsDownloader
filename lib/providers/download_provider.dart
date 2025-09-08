import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reel_item.dart';
import '../models/story_item.dart';
import '../services/download_service.dart';
import '../services/network_diagnostics.dart';
import '../services/instagram_error_handler.dart';

class DownloadProvider extends ChangeNotifier {
  final List<ReelItem> _items = [];
  final List<StoryItem> _stories = [];
  final DownloadService _downloadService = DownloadService();
  double? _activeProgress; // 0..1
  bool _isDownloading = false;
  String? _errorMessage;

  List<ReelItem> get items => List.unmodifiable(_items);
  List<StoryItem> get stories => List.unmodifiable(_stories);
  double? get activeProgress => _activeProgress;
  bool get isDownloading => _isDownloading;
  String? get errorMessage => _errorMessage;

  static const _prefsKey = 'downloads_v1';
  static const _storiesPrefsKey = 'stories_v1';

  /// Downloads content from Instagram URL (auto-detects Reel vs Story)
  Future<void> downloadFromUrl(String url) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    // Auto-detect content type and route to appropriate method
    if (url.contains('/stories/')) {
      await downloadStory(url);
    } else {
      await downloadReel(url);
    }
  }

  /// Downloads a reel from Instagram URL
  Future<void> downloadReel(String reelUrl) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    _isDownloading = true;
    _errorMessage = null;
    _activeProgress = 0.0;
    notifyListeners();

    try {
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

  /// Downloads a story from Instagram URL
  Future<void> downloadStory(String storyUrl) async {
    if (_isDownloading) {
      throw Exception('Another download is already in progress');
    }

    _isDownloading = true;
    _errorMessage = null;
    _activeProgress = 0.0;
    notifyListeners();

    try {
      final storyData = await _downloadService.downloadInstagramStory(
        storyUrl: storyUrl,
        onProgress: (progress) {
          _activeProgress = progress;
          notifyListeners();
        },
      );
      
      await addStory(storyData);
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

  /// Clears any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load reels
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null) {
      final list =
          (jsonDecode(jsonStr) as List)
              .cast<Map<String, dynamic>>()
              .map(ReelItem.fromJson)
              .toList();
      _items
        ..clear()
        ..addAll(list);
    }
    
    // Load stories
    final storiesJsonStr = prefs.getString(_storiesPrefsKey);
    if (storiesJsonStr != null) {
      final storiesList =
          (jsonDecode(storiesJsonStr) as List)
              .cast<Map<String, dynamic>>()
              .map(StoryItem.fromJson)
              .toList();
      _stories
        ..clear()
        ..addAll(storiesList);
    }
    
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  Future<void> _saveStories() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _stories.map((e) => e.toJson()).toList();
    await prefs.setString(_storiesPrefsKey, jsonEncode(list));
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

  Future<void> addStory(StoryItem story) async {
    _stories.insert(0, story);
    await _saveStories();
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

  Future<void> deleteStory(String id) async {
    final idx = _stories.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final story = _stories.removeAt(idx);
    try {
      final f = File(story.filePath);
      if (await f.exists()) await f.delete();
      if (story.thumbnailPath != null) {
        final t = File(story.thumbnailPath!);
        if (await t.exists()) await t.delete();
      }
    } catch (_) {}
    await _saveStories();
    notifyListeners();
  }

  void setIsDownloading(bool v) {
    _isDownloading = v;
    notifyListeners();
  }
}
