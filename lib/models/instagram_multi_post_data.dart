/// Model for multiple Instagram posts data returned from local API
class InstagramMultiPostData {
  final String originalUrl;
  final bool success;
  final List<InstagramPostItem> allUrls;

  const InstagramMultiPostData({
    required this.originalUrl,
    required this.success,
    required this.allUrls,
  });

  /// Create from JSON response
  factory InstagramMultiPostData.fromJson(Map<String, dynamic> json) {
    final allUrlsData = json['allUrls'] as List<dynamic>? ?? [];
    final allUrls = allUrlsData
        .map((item) => InstagramPostItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return InstagramMultiPostData(
      originalUrl: json['originalUrl'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      allUrls: allUrls,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'originalUrl': originalUrl,
      'success': success,
      'allUrls': allUrls.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'InstagramMultiPostData(originalUrl: $originalUrl, success: $success, allUrls: ${allUrls.length} items)';
  }
}

/// Model for individual Instagram post item
class InstagramPostItem {
  final String url; // Image URL
  final String? vidUrl; // Video URL (nullable)

  const InstagramPostItem({
    required this.url,
    this.vidUrl,
  });

  /// Create from JSON
  factory InstagramPostItem.fromJson(Map<String, dynamic> json) {
    return InstagramPostItem(
      url: json['url'] as String? ?? '',
      vidUrl: json['vid_url'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'vid_url': vidUrl,
    };
  }

  /// Check if this item is a video
  bool get isVideo => vidUrl != null && vidUrl!.isNotEmpty;

  /// Get the appropriate media URL (video URL if available, otherwise image URL)
  String get mediaUrl => isVideo ? vidUrl! : url;

  @override
  String toString() {
    return 'InstagramPostItem(url: ${url.substring(0, 30)}..., vidUrl: ${vidUrl != null ? vidUrl!.substring(0, 30) + "..." : "null"})';
  }
}