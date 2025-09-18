import 'package:video_player/video_player.dart';

VideoPlayerController createVideoController(String path) {
  // Check if path is a URL (for network videos) or a local file path
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return VideoPlayerController.networkUrl(Uri.parse(path));
  } else {
    // For local files in web, we need to serve them through a URL
    // This is a simplified approach - in a real app, you might need to
    // implement a proper solution for serving local files in web
    // For now, we'll throw an error to indicate web limitations
    throw UnsupportedError(
      'Local file playback not supported in web environment. Please use the mobile app for full functionality.',
    );
  }
}
