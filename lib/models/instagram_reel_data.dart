/// Model for Instagram reel data returned from local API
class InstagramReelData {
  final String id;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String title;
  final String author;
  final int duration;
  final String originalUrl;

  const InstagramReelData({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.title,
    required this.author,
    required this.duration,
    required this.originalUrl,
  });

  /// Create from JSON response
  factory InstagramReelData.fromJson(
    Map<String, dynamic> json,
    String originalUrl,
  ) {
    return InstagramReelData(
      id: json['id'] as String? ?? _extractReelId(originalUrl),
      mediaUrl:
          json['media_url'] as String? ??
          json['video_url'] as String? ??
          json['url'] as String? ??
          '',
      thumbnailUrl:
          json['thumbnail_url'] as String? ??
          json['thumbnail'] as String? ??
          json['poster'] as String?,
      title:
          json['title'] as String? ??
          json['caption'] as String? ??
          'Instagram Reel',
      author:
          json['author'] as String? ??
          json['username'] as String? ??
          json['user'] as String? ??
          'Unknown',
      duration: json['duration'] as int? ?? 0,
      originalUrl: originalUrl,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'title': title,
      'author': author,
      'duration': duration,
      'original_url': originalUrl,
    };
  }

  /// Extract reel ID from Instagram URL
  static String _extractReelId(String url) {
    final match = RegExp(r'/(reel|p|tv)/([A-Za-z0-9_-]+)').firstMatch(url);
    return match?.group(2) ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  String toString() {
    return 'InstagramReelData(id: $id, title: $title, author: $author, duration: ${duration}s)';
  }
}
