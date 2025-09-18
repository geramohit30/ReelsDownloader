/// Stub implementation for non-web platforms
/// This file provides empty implementations that should never be called on non-web platforms

import 'dart:async';

Future<String> downloadMediaWeb({
  required String mediaUrl,
  required String fileName,
  required void Function(double progress) onProgress,
}) async {
  throw UnsupportedError('Web download is not available on this platform');
}