import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/instagram_reel_data.dart';

/// Service for handling communication with local Instagram reels API
class LocalApiService {
  static const String _baseUrl = 'http://localhost:3000';
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// HTTP client instance for making requests
  static final http.Client _client = http.Client();

  /// Get Instagram reel data from local API endpoint
  ///
  /// [url] - Instagram reel URL to fetch data for
  /// Returns [InstagramReelData] containing the reel information and media URL
  /// Throws [LocalApiException] if the request fails
  static Future<InstagramReelData> fetchInstagramReel(String url) async {
    print('🚀 LOCAL API: Fetching Instagram reel data');
    print('   • Target URL: $url');
    print('   • API Endpoint: $_baseUrl/api/insta/reels');

    try {
      // Validate the Instagram URL format
      if (!_isValidInstagramUrl(url)) {
        throw LocalApiException(
          'Invalid Instagram URL format',
          type: LocalApiErrorType.invalidUrl,
        );
      }

      // Prepare request headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'InstagramReelDownloader/1.0',
      };

      // Prepare request body
      final requestBody = jsonEncode({'url': url});

      print('📤 REQUEST DETAILS:');
      print('   • Method: POST');
      print('   • Headers: $headers');
      print('   • Body: $requestBody');

      // Make the HTTP POST request
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/insta/reels'),
            headers: headers,
            body: requestBody,
          )
          .timeout(
            _defaultTimeout,
            onTimeout: () {
              throw LocalApiException(
                'Request timed out after ${_defaultTimeout.inSeconds} seconds',
                type: LocalApiErrorType.timeout,
              );
            },
          );

      print('📥 RESPONSE DETAILS:');
      print('   • Status Code: ${response.statusCode}');
      print('   • Content-Type: ${response.headers['content-type']}');
      print('   • Content Length: ${response.body.length} bytes');

      // Handle different status codes
      if (response.statusCode == 200) {
        return _handleSuccessResponse(response, url);
      } else {
        return _handleErrorResponse(response);
      }
    } on SocketException catch (e) {
      print('❌ NETWORK ERROR: ${e.message}');
      throw LocalApiException(
        'Cannot connect to local API server. Please ensure the server is running on localhost:3000',
        type: LocalApiErrorType.connectionError,
        originalError: e,
      );
    } on TimeoutException catch (e) {
      print('❌ TIMEOUT ERROR: ${e.message}');
      throw LocalApiException(
        'Request timed out. The local API server may be unresponsive',
        type: LocalApiErrorType.timeout,
        originalError: e,
      );
    } on FormatException catch (e) {
      print('❌ JSON PARSE ERROR: ${e.message}');
      throw LocalApiException(
        'Invalid JSON response from local API server',
        type: LocalApiErrorType.parseError,
        originalError: e,
      );
    } catch (e) {
      print('❌ UNEXPECTED ERROR: $e');
      throw LocalApiException(
        'Unexpected error occurred: ${e.toString()}',
        type: LocalApiErrorType.unknown,
        originalError: e,
      );
    }
  }

  /// Handle successful API response
  static InstagramReelData _handleSuccessResponse(
    http.Response response,
    String originalUrl,
  ) {
    try {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      print('✅ SUCCESS RESPONSE:');
      print('   • Response parsed successfully');
      print('   • JSON keys: ${jsonData.keys.toList()}');

      // Extract media information from the response
      // Extract media information from the response
      // Support your API format with downloadUrl field
      final mediaUrl =
          jsonData['downloadUrl'] as String? ??
          jsonData['media_url'] as String? ??
          jsonData['video_url'] as String? ??
          jsonData['url'] as String?;

      final thumbnailUrl =
          jsonData['thumbnailUrl'] as String? ??
          jsonData['thumbnail_url'] as String? ??
          jsonData['thumbnail'] as String? ??
          jsonData['poster'] as String?;

      final title =
          jsonData['title'] as String? ??
          jsonData['caption'] as String? ??
          'Instagram Reel';

      final duration = jsonData['duration'] as int? ?? 0;

      final author =
          jsonData['author'] as String? ??
          jsonData['username'] as String? ??
          jsonData['user'] as String? ??
          'Unknown';

      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw LocalApiException(
          'No media URL found in API response',
          type: LocalApiErrorType.noMediaFound,
        );
      }

      print(
        '   • Media URL: ${mediaUrl.length > 100 ? "${mediaUrl.substring(0, 100)}..." : mediaUrl}',
      );
      print(
        '   • Thumbnail URL: ${thumbnailUrl?.length != null && thumbnailUrl!.length > 100 ? "${thumbnailUrl.substring(0, 100)}..." : thumbnailUrl ?? "Not provided"}',
      );
      print('   • Title: $title');
      print('   • Author: $author');
      print('   • Duration: ${duration}s');

      final apiOriginalUrl = jsonData['originalUrl'] as String? ?? originalUrl;

      return InstagramReelData(
        id: _extractReelId(apiOriginalUrl),
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        author: author,
        duration: duration,
        originalUrl: apiOriginalUrl,
      );
    } catch (e) {
      print('❌ ERROR PARSING SUCCESS RESPONSE: $e');
      throw LocalApiException(
        'Failed to parse successful API response: ${e.toString()}',
        type: LocalApiErrorType.parseError,
        originalError: e,
      );
    }
  }

  /// Handle API error response
  static Never _handleErrorResponse(http.Response response) {
    try {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage =
          jsonData['error'] as String? ??
          jsonData['message'] as String? ??
          'Unknown error from API';

      print('❌ API ERROR RESPONSE:');
      print('   • Status: ${response.statusCode}');
      print('   • Error: $errorMessage');

      throw LocalApiException(
        'API Error (${response.statusCode}): $errorMessage',
        type: _getErrorTypeFromStatusCode(response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is LocalApiException) rethrow;

      // If we can't parse the error response, create a generic error
      throw LocalApiException(
        'HTTP Error ${response.statusCode}: ${response.reasonPhrase ?? "Unknown error"}',
        type: _getErrorTypeFromStatusCode(response.statusCode),
        statusCode: response.statusCode,
      );
    }
  }

  /// Get error type based on HTTP status code
  static LocalApiErrorType _getErrorTypeFromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return LocalApiErrorType.badRequest;
      case 401:
        return LocalApiErrorType.unauthorized;
      case 403:
        return LocalApiErrorType.forbidden;
      case 404:
        return LocalApiErrorType.notFound;
      case 429:
        return LocalApiErrorType.rateLimited;
      case 500:
      case 502:
      case 503:
      case 504:
        return LocalApiErrorType.serverError;
      default:
        return LocalApiErrorType.unknown;
    }
  }

  /// Validate Instagram URL format (supports reels, posts, TV, and stories)
  static bool _isValidInstagramUrl(String url) {
    final instagramUrlPattern = RegExp(
      r'^https?://(www\.)?instagram\.com/(reel|p|tv|stories)/[A-Za-z0-9_-]+/?(/[A-Za-z0-9_-]+)?/?(\?.*)?$',
      caseSensitive: false,
    );
    return instagramUrlPattern.hasMatch(url);
  }

  /// Extract reel/story ID from Instagram URL
  static String _extractReelId(String url) {
    final match = RegExp(
      r'/(reel|p|tv|stories)/([A-Za-z0-9_-]+)',
    ).firstMatch(url);
    return match?.group(2) ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Test connection to local API server
  static Future<bool> testConnection() async {
    print('🔍 TESTING CONNECTION TO LOCAL API...');

    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: {'User-Agent': 'InstagramReelDownloader/1.0'},
          )
          .timeout(Duration(seconds: 5));

      final isHealthy = response.statusCode == 200;
      print(
        isHealthy
            ? '✅ Local API server is responsive'
            : '❌ Local API server returned status ${response.statusCode}',
      );
      return isHealthy;
    } catch (e) {
      print('❌ Cannot connect to local API server: $e');
      return false;
    }
  }

  /// Dispose of the HTTP client
  static void dispose() {
    _client.close();
  }
}

/// Custom exception for Local API errors
class LocalApiException implements Exception {
  final String message;
  final LocalApiErrorType type;
  final int? statusCode;
  final dynamic originalError;

  const LocalApiException(
    this.message, {
    required this.type,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() {
    return 'LocalApiException: $message (Type: $type)';
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case LocalApiErrorType.connectionError:
        return 'Cannot connect to the local API server. Please ensure the server is running on localhost:3000.';
      case LocalApiErrorType.timeout:
        return 'The request timed out. The local API server may be slow or unresponsive.';
      case LocalApiErrorType.invalidUrl:
        return 'Please provide a valid Instagram reel or story URL.';
      case LocalApiErrorType.noMediaFound:
        return 'No media content was found for this Instagram reel or story.';
      case LocalApiErrorType.rateLimited:
        return 'Too many requests. Please wait a moment and try again.';
      case LocalApiErrorType.serverError:
        return 'The local API server encountered an error. Please check the server logs.';
      case LocalApiErrorType.badRequest:
        return 'Invalid request. Please check the Instagram URL format (supports reels and stories).';
      case LocalApiErrorType.unauthorized:
        return 'Authentication required for the local API server.';
      case LocalApiErrorType.forbidden:
        return 'Access denied by the local API server.';
      case LocalApiErrorType.notFound:
        return 'The requested resource was not found on the local API server.';
      case LocalApiErrorType.parseError:
        return 'Failed to parse the response from the local API server.';
      case LocalApiErrorType.unknown:
      default:
        return 'An unexpected error occurred: $message';
    }
  }
}

/// Types of errors that can occur with the Local API
enum LocalApiErrorType {
  connectionError,
  timeout,
  invalidUrl,
  noMediaFound,
  rateLimited,
  serverError,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  parseError,
  unknown,
}
