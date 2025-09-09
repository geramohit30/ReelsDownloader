import 'dart:io';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/reel_item.dart';
import 'instagram_service.dart';
import 'instagram_utils.dart';
import 'thumbnail_service.dart';

class DownloadService {
  final InstagramService _instagramService = InstagramService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  /// Downloads Instagram content (reel/story) from URL and returns ReelItem
  Future<ReelItem> downloadInstagramReel({
    required String reelUrl,
    required void Function(double progress) onProgress,
  }) async {
    // Validate URL
    if (!InstagramUtils.isInstagramUrl(reelUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    // Get post data using optimized method
    final postData = await _instagramService.getPostDataOptimized(reelUrl);

    // Determine media URL and file type
    String mediaUrl;
    String fileExtension;
    bool isVideo;
    
    if (postData.isVideo && postData.videoUrl != null) {
      // Video content (reels)
      mediaUrl = postData.videoUrl!;
      fileExtension = 'mp4';
      isVideo = true;
    } else if (postData.displayUrl != null) {
      // Image content (stories)
      mediaUrl = postData.displayUrl!;
      fileExtension = 'jpg';
      isVideo = false;
    } else {
      throw Exception('Could not find valid media URL for this content');
    }

    // Generate filename
    final shortcode =
        postData.shortcode ?? InstagramUtils.extractShortcodeFromUrl(reelUrl);
    final filename =
        '${isVideo ? "reel" : "story"}_${shortcode}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // Download media
    final filePath = await downloadToAppDir(
      mediaUrl: Uri.parse(mediaUrl),
      onProgress: onProgress,
      suggestedName: filename,
    );

    // Create ReelItem (works for both videos and images)
    String? thumbnailPath;
    try {
      if (isVideo) {
        // Generate thumbnail from video
        thumbnailPath = await _thumbnailService.generate(filePath);
      } else {
        // For images, use the image itself as thumbnail
        thumbnailPath = filePath;
      }
    } catch (_) {
      thumbnailPath = null;
    }

    return ReelItem(
      id: shortcode,
      sourceUrl: reelUrl,
      filePath: filePath,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }

  /// Downloads media file to app directory
  /// Returns (filePath)
  Future<String> downloadToAppDir({
    required Uri mediaUrl,
    required void Function(double progress) onProgress, // 0..1
    String? suggestedName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final reelsDir = Directory('${dir.path}/reels');
    if (!await reelsDir.exists()) await reelsDir.create(recursive: true);

    final name =
        suggestedName ?? 'media_${DateTime.now().millisecondsSinceEpoch}';
    final file = File('${reelsDir.path}/$name');

    final req = http.Request('GET', mediaUrl);
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
