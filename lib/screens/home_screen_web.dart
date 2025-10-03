// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web-specific implementations for platform views

Widget _buildWebVideoPlayerWeb(String videoUrl) {
  final viewType = 'web-video-${videoUrl.hashCode}';
  
  // Register the view factory using the correct web API
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final videoElement = html.VideoElement()
        ..src = videoUrl
        ..controls = true
        ..autoplay = false
        ..muted = false
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..attributes['playsinline'] = 'true';
      return videoElement;
    },
  );

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: HtmlElementView(viewType: viewType),
  );
}

Widget _buildWebImageViewerWeb(String imageUrl) {
  final viewType = 'web-image-${imageUrl.hashCode}';
  
  // Register the view factory using the correct web API
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final imgElement = html.ImageElement()
        ..src = imageUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      return imgElement;
    },
  );

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: HtmlElementView(viewType: viewType),
  );
}