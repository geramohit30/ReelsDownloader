import 'dart:convert';

class InstagramUtils {
  /// Encodes GraphQL request data for Instagram API
  static String encodeGraphqlRequestData(String postId) {
    // Extract shortcode from various Instagram URL formats
    final shortcode = extractShortcodeFromUrl(postId);

    final variables = {
      "shortcode": shortcode,
      "child_comment_count": 3,
      "fetch_comment_count": 40,
      "parent_comment_count": 24,
      "has_threaded_comments": true,
    };

    final data = {
      "av": "0",
      "fb_api_caller_class": "RelayModern",
      "fb_api_req_friendly_name": "PolarisPostActionLoadPostQueryQuery",
      "variables": json.encode(variables),
      "server_timestamps": "true",
      "doc_id": "10015901848480474",
    };

    // Convert to URL-encoded form data
    return data.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  /// Extracts shortcode from Instagram URL
  static String extractShortcodeFromUrl(String url) {
    // Handle different Instagram URL formats:
    // https://www.instagram.com/p/SHORTCODE/
    // https://www.instagram.com/reel/SHORTCODE/
    // https://www.instagram.com/stories/USERNAME/STORY_ID/
    // https://instagram.com/p/SHORTCODE/
    // Just SHORTCODE

    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      // Handle stories format: /stories/username/story_id
      if (uri.pathSegments.length >= 3 && uri.pathSegments[0] == 'stories') {
        return uri.pathSegments[2]; // Return story_id
      }
      
      // Find 'p' or 'reel' segment and get the next one
      for (int i = 0; i < uri.pathSegments.length - 1; i++) {
        if (uri.pathSegments[i] == 'p' || uri.pathSegments[i] == 'reel') {
          return uri.pathSegments[i + 1];
        }
      }
    }

    // If URL parsing fails, try regex extraction
    final shortcodeRegex = RegExp(r'(?:p|reel|stories/[^/]+)/([A-Za-z0-9_-]+)');
    final match = shortcodeRegex.firstMatch(url);
    if (match != null) {
      return match.group(1)!;
    }

    // If all else fails, assume the input is already a shortcode
    return url.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  }
  
  /// Extracts username from Instagram stories URL
  static String? extractUsernameFromStoriesUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.length >= 2) {
      // Handle stories format: /stories/username/story_id
      if (uri.pathSegments[0] == 'stories') {
        return uri.pathSegments[1];
      }
    }
    
    // Try regex extraction
    final usernameRegex = RegExp(r'/stories/([^/]+)/');
    final match = usernameRegex.firstMatch(url);
    return match?.group(1);
  }

  /// Validates if a string looks like a valid Instagram shortcode
  static bool isValidShortcode(String shortcode) {
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(shortcode);
  }

  /// Validates if a URL is an Instagram post/reel/story URL
  static bool isInstagramUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return (uri.host.contains('instagram.com') || uri.host == 'instagr.am') &&
        (uri.path.contains('/p/') || uri.path.contains('/reel/') || uri.path.contains('/stories/'));
  }

  /// Generates a CSRF token (simplified version)
  static String generateCsrfToken() {
    // In a real implementation, this should be extracted from cookies
    // For now, we'll use a static token
    return 'RVDUooU5MYsBbS1CNN3CzVAuEP8oHB52';
  }

  /// Generates session headers for Instagram requests
  static Map<String, String> getSessionHeaders() {
    return {
      'X-CSRFToken': generateCsrfToken(),
      'X-IG-App-ID': '1217981644879628',
      'X-FB-LSD': 'AVqbxe3J_YA',
      'X-ASBD-ID': '129477',
    };
  }
}
