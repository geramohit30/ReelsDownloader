import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reel_item.dart';
import '../services/download_service.dart';
import '../services/network_diagnostics.dart';
import '../services/instagram_error_handler.dart';

class DownloadProvider extends ChangeNotifier {
  final List<ReelItem> _items = [];
  final DownloadService _downloadService = DownloadService();
  double? _activeProgress; // 0..1
  bool _isDownloading = false;
  String? _errorMessage;

  List<ReelItem> get items => List.unmodifiable(_items);
  double? get activeProgress => _activeProgress;
  bool get isDownloading => _isDownloading;
  String? get errorMessage => _errorMessage;

  static const _prefsKey = 'downloads_v1';

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
}
