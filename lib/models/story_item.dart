import 'downloadable_item.dart';

class StoryItem implements DownloadableItem {
  @override
  final String id;              // e.g., timestamp-based
  @override
  final String sourceUrl;       // Instagram story URL
  @override
  final String filePath;        // Local path to downloaded mp4/jpg
  @override
  final String? thumbnailPath;  // Local path to generated thumbnail
  @override
  final DateTime createdAt;
  
  // Story-specific properties
  final String? authorUsername; // Story author's username
  final bool isVideo;          // true for video stories, false for photos
  final Duration? duration;    // Duration for video stories
  final DateTime? expiresAt;   // When the story expires (24h from creation)

  @override
  ContentType get contentType => ContentType.story;

  StoryItem({
    required this.id,
    required this.sourceUrl,
    required this.filePath,
    required this.createdAt,
    this.thumbnailPath,
    this.authorUsername,
    this.isVideo = true,
    this.duration,
    this.expiresAt,
  });

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceUrl': sourceUrl,
    'filePath': filePath,
    'thumbnailPath': thumbnailPath,
    'createdAt': createdAt.toIso8601String(),
    'contentType': contentType.name,
    'authorUsername': authorUsername,
    'isVideo': isVideo,
    'duration': duration?.inSeconds,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] as String,
      sourceUrl: json['sourceUrl'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      authorUsername: json['authorUsername'] as String?,
      isVideo: json['isVideo'] as bool? ?? true,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  /// Check if this story has expired (24 hours rule)
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get remaining time before story expires
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }
}