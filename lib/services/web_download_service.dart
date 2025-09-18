import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Conditional import for web-specific functionality
import 'web_download_service_stub.dart'
    if (dart.library.html) 'web_download_service_web.dart';

/// Web-specific download service that uses browser APIs to trigger downloads
class WebDownloadService {
  /// Downloads a media file on web by triggering browser download
  /// Returns a synthetic file path for consistency with mobile API
  static Future<String> downloadMedia({
    required String mediaUrl,
    required String fileName,
    required void Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      return await downloadMediaWeb(
        mediaUrl: mediaUrl,
        fileName: fileName,
        onProgress: onProgress,
      );
    } else {
      throw UnsupportedError('Web download service is only available on web platform');
    }
  }

  /// Downloads media content as bytes (for preview purposes)
  static Future<Uint8List> downloadMediaBytes({
    required String mediaUrl,
    required void Function(double progress) onProgress,
  }) async {
    try {
      print('🌐 WEB DOWNLOAD: Downloading bytes for preview');
      
      onProgress(0.0);
      
      final response = await http.get(Uri.parse(mediaUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download media bytes: HTTP ${response.statusCode}');
      }
      
      onProgress(1.0);
      
      return response.bodyBytes;
      
    } catch (e) {
      print('❌ WEB DOWNLOAD: Error downloading bytes: $e');
      rethrow;
    }
  }

  /// Checks if the current platform is web
  static bool get isWeb {
    return kIsWeb;
  }

  /// Gets a user-friendly download location message for web
  static String getDownloadLocationMessage() {
    return 'Files will be downloaded to your browser\'s default download folder (usually ~/Downloads)';
  }

  /// Generates a safe filename for web downloads
  static String sanitizeFileName(String fileName) {
    // Remove or replace characters that might cause issues in web downloads
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}