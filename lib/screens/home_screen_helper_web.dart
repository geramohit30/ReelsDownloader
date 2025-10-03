// ignore_for_file: undefined_prefixed_name

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class HomeScreenHelper {
  static Widget buildWebVideoPlayer(String videoUrl) {
    final viewType = 'web-video-${videoUrl.hashCode}';
    try {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final element = html.VideoElement()
          ..src = videoUrl
          ..controls = true
          ..autoplay = false
          ..muted = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..attributes.addAll({'playsinline': 'true'});
        return element;
      });
    } catch (_) {}

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: viewType),
    );
  }

  static Widget buildWebImageViewer(String imageUrl) {
    final viewType = 'web-image-${imageUrl.hashCode}';
    try {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final element = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover';
        return element;
      });
    } catch (_) {}

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: viewType),
    );
  }
}


