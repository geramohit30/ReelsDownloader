import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/reel_item.dart';
import '../models/story_item.dart';
import 'instagram_service.dart';
import 'instagram_utils.dart';

class DownloadService {
  final InstagramService _instagramService = InstagramService();

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

    // Generate filename
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
    return ReelItem(
      id: shortcode,
      sourceUrl: reelUrl,
      filePath: filePath,
      createdAt: DateTime.now(),
    );
  }

  /// Returns (filePath)
  Future<String> downloadToAppDir({
    required Uri videoUrl,
    required void Function(double progress) onProgress, // 0..1
    String? suggestedName,
    String? subdirectory, // Optional subdirectory (e.g., 'stories')
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = subdirectory != null 
        ? Directory('${dir.path}/$subdirectory')
        : Directory('${dir.path}/reels');
    
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final name =
        suggestedName ?? 'media_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = File('${targetDir.path}/$name');

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

  /// Downloads Instagram story from URL and returns StoryItem
  Future<StoryItem> downloadInstagramStory({
    required String storyUrl,
    required void Function(double progress) onProgress,
  }) async {
    // Validate URL
    if (!InstagramUtils.isInstagramUrl(storyUrl)) {
      throw Exception('Invalid Instagram URL');
    }

    // Get story data using new background automation approach
    final storyData = await _instagramService.getStoryData(storyUrl);

    if (storyData.videoUrl == null || storyData.videoUrl!.isEmpty) {
      throw Exception('Could not find media URL for this story');
    }

    // Extract username and story ID from URL
    final username = InstagramUtils.extractUsernameFromStoriesUrl(storyUrl) ?? 'unknown';
    final storyId = InstagramUtils.extractShortcodeFromUrl(storyUrl);
    
    // Determine file extension based on content type
    final isVideo = storyData.isVideo;
    final extension = isVideo ? 'mp4' : 'jpg';
    
    // Generate filename
    final filename = 'story_${username}_${storyId}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    // Download media
    final filePath = await downloadToAppDir(
      videoUrl: Uri.parse(storyData.videoUrl!),
      onProgress: onProgress,
      suggestedName: filename,
      subdirectory: 'stories',
    );

    // Calculate expiry time (24 hours from now, since we don't know exact creation time)
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    // Create StoryItem
    return StoryItem(
      id: storyId,
      sourceUrl: storyUrl,
      filePath: filePath,
      createdAt: now,
      authorUsername: username,
      isVideo: isVideo,
      expiresAt: expiresAt,
    );
  }
}
