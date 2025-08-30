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

  factory InstagramPostData.fromGraphQL(Map<String, dynamic> data) {
    final postData = data['xdt_shortcode_media'] ?? data['shortcode_media'];
    if (postData == null) return InstagramPostData();

    return InstagramPostData(
      id: postData['id'] as String?,
      shortcode: postData['shortcode'] as String?,
      displayUrl: postData['display_url'] as String?,
      videoUrl: postData['video_url'] as String?,
      isVideo: postData['is_video'] as bool? ?? false,
      caption: _extractCaption(postData),
      username: postData['owner']?['username'] as String?,
      userProfilePicUrl: postData['owner']?['profile_pic_url'] as String?,
      likeCount: postData['edge_media_preview_like']?['count'] as int?,
      commentCount: postData['edge_media_to_comment']?['count'] as int?,
      takenAtTimestamp: _parseTimestamp(postData['taken_at_timestamp']),
    );
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
