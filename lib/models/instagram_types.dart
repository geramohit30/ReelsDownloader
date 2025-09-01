class GraphQLResponse {
  final Map<String, dynamic> data;
  final List<dynamic>? errors;
  final Map<String, dynamic>? extensions;

  GraphQLResponse({required this.data, this.errors, this.extensions});

  factory GraphQLResponse.fromJson(Map<String, dynamic> json) {
    return GraphQLResponse(
      data: json['data'] as Map<String, dynamic>? ?? {},
      errors: json['errors'] as List<dynamic>?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      if (errors != null) 'errors': errors,
      if (extensions != null) 'extensions': extensions,
    };
  }
}

class InstagramPostData {
  final String? id;
  final String? shortcode;
  final String? displayUrl;
  final String? videoUrl;
  final bool isVideo;
  final String? caption;
  final String? username;
  final String? userProfilePicUrl;
  final int? likeCount;
  final int? commentCount;
  final DateTime? takenAtTimestamp;

  InstagramPostData({
    this.id,
    this.shortcode,
    this.displayUrl,
    this.videoUrl,
    this.isVideo = false,
    this.caption,
    this.username,
    this.userProfilePicUrl,
    this.likeCount,
    this.commentCount,
    this.takenAtTimestamp,
  });

  factory InstagramPostData.fromGraphQL(Map<String, dynamic> mediaData) {
    // MediaData is already the xdt_shortcode_media object
    return InstagramPostData(
      id: mediaData['id'] as String?,
      shortcode: mediaData['shortcode'] as String?,
      displayUrl: mediaData['display_url'] as String?,
      videoUrl: _extractVideoUrl(mediaData),
      isVideo: mediaData['is_video'] as bool? ?? false,
      caption: _extractCaption(mediaData),
      username: mediaData['owner']?['username'] as String?,
      userProfilePicUrl: mediaData['owner']?['profile_pic_url'] as String?,
      likeCount: mediaData['edge_media_preview_like']?['count'] as int?,
      commentCount: mediaData['edge_media_to_comment']?['count'] as int?,
      takenAtTimestamp: _parseTimestamp(mediaData['taken_at_timestamp']),
    );
  }
  
  /// Extract video URL from GraphQL media data with multiple strategies
  static String? _extractVideoUrl(Map<String, dynamic> mediaData) {
    // Strategy 1: Direct video_url field
    final directVideoUrl = mediaData['video_url'] as String?;
    if (directVideoUrl != null && directVideoUrl.isNotEmpty) {
      return directVideoUrl;
    }
    
    // Strategy 2: Video resources array
    final videoResources = mediaData['video_resources'] as List<dynamic>?;
    if (videoResources != null && videoResources.isNotEmpty) {
      // Find the highest quality video
      Map<String, dynamic>? bestVideo;
      int maxConfig = 0;
      
      for (final resource in videoResources) {
        if (resource is Map<String, dynamic>) {
          final configWidth = resource['config_width'] as int? ?? 0;
          final configHeight = resource['config_height'] as int? ?? 0;
          final score = configWidth * configHeight;
          
          if (score > maxConfig) {
            maxConfig = score;
            bestVideo = resource;
          }
        }
      }
      
      if (bestVideo != null) {
        return bestVideo['src'] as String?;
      }
    }
    
    // Strategy 3: Media candidates (for videos)
    final edgeMediaToVideo = mediaData['edge_media_to_tagged_user'];
    if (edgeMediaToVideo != null) {
      // This is a fallback for tagged media structure
    }
    
    // Strategy 4: Playback URL (for video playback)
    final playbackUrl = mediaData['video_playback_url'] as String?;
    if (playbackUrl != null && playbackUrl.isNotEmpty) {
      return playbackUrl;
    }
    
    return null;
  }

  static String? _extractCaption(Map<String, dynamic> postData) {
    try {
      final edges = postData['edge_media_to_caption']?['edges'] as List?;
      if (edges != null && edges.isNotEmpty) {
        return edges.first['node']['text'] as String?;
      }
    } catch (e) {
      // Ignore caption extraction errors
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else if (timestamp is String) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp) * 1000);
      }
    } catch (e) {
      // Ignore timestamp parsing errors
    }
    return null;
  }
}
