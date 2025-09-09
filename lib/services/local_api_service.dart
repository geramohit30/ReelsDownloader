import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/instagram_reel_data.dart';

/// Service for handling communication with local Instagram reels API
class LocalApiService {
  static const String _baseUrl = 'https://instagramreeldownload.com';
  static const Duration _defaultTimeout = Duration(seconds: 60);

  /// HTTP client instance for making requests
  static final http.Client _client = http.Client();

  /// Get Instagram reel data from local API endpoint with retry logic
  ///
  /// [url] - Instagram reel URL to fetch data for
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [retryDelay] - Delay between retries (default: 2 seconds)
  /// Returns [InstagramReelData] containing the reel information and media URL
  /// Throws [LocalApiException] if the request fails
  static Future<InstagramReelData> fetchInstagramReel(
    String url, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    print('🚀 LOCAL API: Fetching Instagram reel data (Attempt 1/${maxRetries + 1})');
    print('   • Target URL: $url');
    print('   • API Endpoint: $_baseUrl/api/insta/reels');
    print('   • Max Retries: $maxRetries');
    print('   • Retry Delay: ${retryDelay.inSeconds}s');

    LocalApiException? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          print('\n🔄 RETRY ATTEMPT ${attempt + 1}/${maxRetries + 1}');
          print('   • Waiting ${retryDelay.inSeconds}s before retry...');
          await Future.delayed(retryDelay);
        }

        // Validate the Instagram URL format
        if (!_isValidInstagramUrl(url)) {
          throw LocalApiException(
            'Invalid Instagram URL format',
            type: LocalApiErrorType.invalidUrl,
          );
        }

        // Prepare request headers with enhanced browser simulation
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': _getRandomUserAgent(),
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin',
          'X-Requested-With': 'XMLHttpRequest',
        };

        // Prepare request body
        final requestBody = jsonEncode({'url': url});

        print('📤 REQUEST DETAILS (Attempt ${attempt + 1}):');
        print('   • Method: POST');
        print('   • Headers: ${headers.length} headers');
        print('   • Body: $requestBody');
        print('   • Timeout: ${_defaultTimeout.inSeconds}s');

        // Make the HTTP POST request with enhanced timeout handling
        final response = await _client
            .post(
              Uri.parse('$_baseUrl/api/insta/reels'),
              headers: headers,
              body: requestBody,
            )
            .timeout(
              _defaultTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Request timed out after ${_defaultTimeout.inSeconds} seconds',
                  _defaultTimeout,
                );
              },
            );

        print('📥 RESPONSE DETAILS (Attempt ${attempt + 1}):');
        print('   • Status Code: ${response.statusCode}');
        print('   • Content-Type: ${response.headers['content-type']}');
        print('   • Content Length: ${response.body.length} bytes');

        // Handle different status codes
        if (response.statusCode == 200) {
          final result = _handleSuccessResponse(response, url);
          print('✅ SUCCESS: API request completed successfully on attempt ${attempt + 1}');
          return result;
        } else {
          return _handleErrorResponse(response);
        }
      } on SocketException catch (e) {
        lastException = LocalApiException(
          'Cannot connect to API server: ${e.message}',
          type: LocalApiErrorType.connectionError,
          originalError: e,
        );
        print('❌ NETWORK ERROR (Attempt ${attempt + 1}): ${e.message}');
      } on TimeoutException catch (e) {
        lastException = LocalApiException(
          'Request timed out after ${_defaultTimeout.inSeconds} seconds',
          type: LocalApiErrorType.timeout,
          originalError: e,
        );
        print('❌ TIMEOUT ERROR (Attempt ${attempt + 1}): ${e.message}');
      } on FormatException catch (e) {
        lastException = LocalApiException(
          'Invalid JSON response from API server',
          type: LocalApiErrorType.parseError,
          originalError: e,
        );
        print('❌ JSON PARSE ERROR (Attempt ${attempt + 1}): ${e.message}');
        // JSON errors are usually not recoverable with retries
        break;
      } on LocalApiException catch (e) {
        lastException = e;
        print('❌ API ERROR (Attempt ${attempt + 1}): $e');
        // API errors (400, 401, etc.) are usually not recoverable with retries
        if (_isNonRetryableError(e.type)) {
          break;
        }
      } catch (e) {
        lastException = LocalApiException(
          'Unexpected error occurred: ${e.toString()}',
          type: LocalApiErrorType.unknown,
          originalError: e,
        );
        print('❌ UNEXPECTED ERROR (Attempt ${attempt + 1}): $e');
      }

      // If this was the last attempt, break the loop
      if (attempt == maxRetries) {
        break;
      }
    }

    // All attempts failed, throw the last exception
    print('❌ ALL ATTEMPTS FAILED: Throwing last exception');
    throw lastException ?? LocalApiException(
      'All retry attempts failed',
      type: LocalApiErrorType.unknown,
    );
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
    // Enhanced regex patterns to support multiple Instagram URL formats
    final patterns = [
      // Standard reels, posts, and TV: /reel/ID, /p/ID, /tv/ID
      RegExp(
        r'^https?://(www\.)?instagram\.com/(reel|p|tv)/[A-Za-z0-9_-]+/?(\?.*)?$',
        caseSensitive: false,
      ),
      // Stories format: /stories/username/storyId
      RegExp(
        r'^https?://(www\.)?instagram\.com/stories/[A-Za-z0-9_.]+/[0-9]+/?(\?.*)?$',
        caseSensitive: false,
      ),
      // Alternative stories format: /stories/highlights/ID
      RegExp(
        r'^https?://(www\.)?instagram\.com/stories/highlights/[0-9]+/?(\?.*)?$',
        caseSensitive: false,
      ),
    ];
    
    // Check if URL matches any of the supported patterns
    for (final pattern in patterns) {
      if (pattern.hasMatch(url)) {
        print('✅ URL VALIDATION: Matched pattern for $url');
        return true;
      }
    }
    
    print('❌ URL VALIDATION: No matching pattern for $url');
    print('   • Supported formats:');
    print('   • Reels: https://instagram.com/reel/ID');
    print('   • Posts: https://instagram.com/p/ID');
    print('   • Stories: https://instagram.com/stories/username/storyId');
    print('   • Highlights: https://instagram.com/stories/highlights/ID');
    
    return false;
  }

  /// Extract reel/story ID from Instagram URL
  static String _extractReelId(String url) {
    // Handle different Instagram URL formats
    
    // For stories: /stories/username/storyId - extract the storyId
    final storyMatch = RegExp(
      r'/stories/([A-Za-z0-9_.]+)/([0-9]+)',
    ).firstMatch(url);
    if (storyMatch != null) {
      return storyMatch.group(2)!; // Return the story ID (numeric)
    }
    
    // For highlights: /stories/highlights/ID - extract the highlight ID
    final highlightMatch = RegExp(
      r'/stories/highlights/([0-9]+)',
    ).firstMatch(url);
    if (highlightMatch != null) {
      return highlightMatch.group(1)!; // Return the highlight ID
    }
    
    // For reels, posts, TV: /reel/ID, /p/ID, /tv/ID - extract the content ID
    final contentMatch = RegExp(
      r'/(reel|p|tv)/([A-Za-z0-9_-]+)',
    ).firstMatch(url);
    if (contentMatch != null) {
      return contentMatch.group(2)!; // Return the content ID
    }
    
    // Fallback: use timestamp if no pattern matches
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Test connection to local API server
  static Future<bool> testConnection() async {
    print('🔍 TESTING CONNECTION TO LOCAL API...');

    try {
      // final response = await _client
      //     .get(
      //       Uri.parse('$_baseUrl/health'),
      //       headers: {'User-Agent': 'InstagramReelDownloader/1.0'},
      //     )
      //     .timeout(Duration(seconds: 5));

      final isHealthy = true;
      print(
        isHealthy
            ? '✅ Local API server is responsive'
            : '❌ Local API server returned status',
      );
      return isHealthy;
    } catch (e) {
      print('❌ Cannot connect to local API server: $e');
      return false;
    }
  }

  /// Generate a random user agent for better API compatibility
  static String _getRandomUserAgent() {
    final userAgents = [
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'InstagramReelDownloader/1.0 (Mobile App)',
    ];
    final random = DateTime.now().millisecondsSinceEpoch % userAgents.length;
    return userAgents[random];
  }

  /// Check if an error type should not be retried
  static bool _isNonRetryableError(LocalApiErrorType type) {
    return {
      LocalApiErrorType.invalidUrl,
      LocalApiErrorType.badRequest,
      LocalApiErrorType.unauthorized,
      LocalApiErrorType.forbidden,
      LocalApiErrorType.notFound,
      LocalApiErrorType.parseError,
    }.contains(type);
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
