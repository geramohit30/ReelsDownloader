/// IO-specific implementation for mobile/desktop platforms
/// This file uses dart:io for file operations

import 'dart:io';
import 'package:flutter/material.dart';

bool fileExists(String? path) {
  return path != null && path.isNotEmpty && File(path).existsSync();
}

Widget buildThumbnail(String? thumbnailPath, {
  required BoxFit fit,
  Widget? errorWidget,
}) {
  if (thumbnailPath == null || thumbnailPath.isEmpty || !File(thumbnailPath).existsSync()) {
    return errorWidget ?? Container();
  }
  
  return Image.file(
    File(thumbnailPath),
    fit: fit,
    errorBuilder: (context, error, stackTrace) => errorWidget ?? Container(),
  );
}