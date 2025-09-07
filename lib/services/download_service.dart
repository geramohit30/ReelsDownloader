import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/reel_item.dart';
import 'instagram_service.dart';
import 'instagram_utils.dart';
import 'thumbnail_service.dart';

class DownloadService {
  final InstagramService _instagramService = InstagramService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  /// Downloads Instagram reel from URL and returns ReelItem
  Future<ReelItem> downloadInstagramReel({
    required String reelUrl,
    required void Function(double progress) onProgress,
  }) async {
    // Validate URL
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    // Get post data using optimized method for release mode compatibility
    final postData = await _instagramService.getPostDataOptimized(reelUrl);

    if (postData.videoUrl == null || postData.videoUrl!.isEmpty) {
      throw Exception('Could not find video URL for this reel');
    }

    // On web, do not download to local storage. Use network URLs directly.
    if (kIsWeb) {
      if (postData.videoUrl == null || postData.videoUrl!.isEmpty) {
        throw Exception('Could not find video URL for this reel');
      }
      final shortcode =
          postData.shortcode ?? InstagramUtils.extractShortcodeFromUrl(reelUrl);
      return ReelItem(
        id: shortcode,
        sourceUrl: reelUrl,
        filePath: postData.videoUrl!,
        createdAt: DateTime.now(),
        thumbnailPath: postData.displayUrl,
      );
    }

    // Generate filename (mobile/desktop)
    final shortcode =
        postData.shortcode ?? InstagramUtils.extractShortcodeFromUrl(reelUrl);
    final filename =
        'reel_${shortcode}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Download video
    final filePath = await downloadToAppDir(
      videoUrl: Uri.parse(postData.videoUrl!),
      onProgress: onProgress,
      suggestedName: filename,
    );

    // Create ReelItem
    String? thumbnailPath;
    if (kIsWeb) {
      // On web, use the remote displayUrl as thumbnail
      thumbnailPath = postData.displayUrl;
    } else {
      try {
        thumbnailPath = await _thumbnailService.generate(filePath);
      } catch (_) {
        // If thumbnail generation fails, proceed without it
        thumbnailPath = null;
      }
    }

    return ReelItem(
      id: shortcode,
      sourceUrl: reelUrl,
      filePath: filePath,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }

  /// Returns (filePath)
  Future<String> downloadToAppDir({
    required Uri videoUrl,
    required void Function(double progress) onProgress, // 0..1
    String? suggestedName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final reelsDir = Directory('${dir.path}/reels');
    if (!await reelsDir.exists()) await reelsDir.create(recursive: true);

    final name =
        suggestedName ?? 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = File('${reelsDir.path}/$name');

    final req = http.Request('GET', videoUrl);
    final res = await req.send();

    if (res.statusCode != 200) {
      throw Exception('Download failed (HTTP ${res.statusCode})');
    }

    final sink = file.openWrite();
    final contentLen = res.contentLength ?? 0;
    int received = 0;

    await for (final chunk in res.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (contentLen > 0) {
        onProgress(received / contentLen);
      }
    }

    await sink.flush();
    await sink.close();

    onProgress(1.0);
    return file.path;
  }
}
