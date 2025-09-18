/// Stub implementation for web platform
/// This file provides web-friendly implementations

import 'package:flutter/material.dart';

bool fileExists(String? path) {
  // On web, we can't check file existence, so assume true if path exists
  return path != null && path.isNotEmpty;
}

Widget buildThumbnail(String? thumbnailPath, {
  required BoxFit fit,
  Widget? errorWidget,
}) {
  if (thumbnailPath == null || thumbnailPath.isEmpty) {
    return errorWidget ?? Container();
  }
  
  // On web, treat thumbnailPath as a network URL or data URL
  return Image.network(
    thumbnailPath,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => errorWidget ?? Container(),
  );
}