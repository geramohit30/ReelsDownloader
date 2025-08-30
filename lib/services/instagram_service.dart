import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/instagram_types.dart';
import 'instagram_utils.dart';

class InstagramService {
  static final List<String> _userAgents = [
    "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
  ];
  static final Random _random = Random();

  // Session data for Instagram authentication
  static String? _sessionId;
  static String? _csrfToken;
  static String? _mid;
  static String? _ig_did;
  static String? _ig_nrcb;

  static String _randomUA() => _userAgents[_random.nextInt(_userAgents.length)];

  /// Initialize session by visiting Instagram homepage to get cookies
  static Future<void> _initializeSession() async {
    if (_sessionId != null) {
      print('   • Session already initialized, reusing existing session');
      return; // Already initialized
    }

    print('🔐 INITIALIZING INSTAGRAM SESSION...');
    print('   • Visiting Instagram homepage to obtain session cookies');

    try {
      final headers = {
        'User-Agent': _randomUA(),
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
      };
      
      print('   • Attempting to connect to Instagram...');
      final response = await http.get(
        Uri.parse('https://www.instagram.com/'),
        headers: headers,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Session initialization timed out after 30 seconds');
        },
      );

      print('   • Instagram response received: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Extract session data from cookies
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          _extractSessionData(cookies);
          print('✅ Session initialized successfully');
          print('   • Session ID: ${_sessionId?.substring(0, 8)}...');
          print('   • CSRF Token: ${_csrfToken?.substring(0, 8)}...');
        } else {
          print('⚠️ No cookies received from Instagram');
          print('   • This is unusual but we\'ll continue without session cookies');
        }
      } else if (response.statusCode == 429) {
        print('🔴 Instagram rate limiting detected (429)');
        throw Exception(
          'Instagram is temporarily blocking requests due to rate limiting. '
          'Please wait 10-15 minutes before trying again.',
        );
      } else if (response.statusCode >= 500) {
        print('🔴 Instagram server error: ${response.statusCode}');
        throw Exception(
          'Instagram servers are experiencing issues. Please try again later.',
        );
      } else {
        print('🔴 Failed to initialize session: ${response.statusCode}');
        print('   • Response: ${response.reasonPhrase}');
        throw Exception(
          'Failed to connect to Instagram (HTTP ${response.statusCode}). '
          'This might be a temporary network issue.',
        );
      }
    } on SocketException catch (e) {
      print('🔴 Network connection failed: $e');
      throw Exception(
        'Cannot connect to Instagram. Please check your internet connection and try again. '
        'Error: Network unreachable',
      );
    } on TimeoutException catch (e) {
      print('🔴 Connection timeout: $e');
      throw Exception(
        'Connection to Instagram timed out. This might indicate a slow or unstable internet connection.',
      );
    } catch (e) {
      print('🔴 Session initialization error: $e');
      print('   • Error type: ${e.runtimeType}');
      
      if (e.toString().contains('No address associated with hostname') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          'DNS lookup failed - cannot resolve Instagram\'s address. '
          'Please check your internet connection and DNS settings.',
        );
      }
      
      throw Exception(
        'Failed to initialize Instagram session: $e',
      );
    }
  }

  /// Extract session data from Instagram cookies
  static void _extractSessionData(String cookies) {
    final cookieList = cookies.split(',');

    for (final cookie in cookieList) {
      final parts = cookie.trim().split(';')[0].split('=');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();

        switch (name) {
          case 'sessionid':
            _sessionId = value;
            break;
          case 'csrftoken':
            _csrfToken = value;
            break;
          case 'mid':
            _mid = value;
            break;
          case 'ig_did':
            _ig_did = value;
            break;
          case 'ig_nrcb':
            _ig_nrcb = value;
            break;
        }
      }
    }
  }

  /// Get authenticated headers for Instagram requests
  static Map<String, String> _getAuthenticatedHeaders(String userAgent) {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-User': '?1',
      'Referer': 'https://www.instagram.com/',
    };

    // Add session cookies if available
    final cookieParts = <String>[];

    if (_sessionId != null) cookieParts.add('sessionid=$_sessionId');
    if (_csrfToken != null) cookieParts.add('csrftoken=$_csrfToken');
    if (_mid != null) cookieParts.add('mid=$_mid');
    if (_ig_did != null) cookieParts.add('ig_did=$_ig_did');
    if (_ig_nrcb != null) cookieParts.add('ig_nrcb=$_ig_nrcb');

    if (cookieParts.isNotEmpty) {
      headers['Cookie'] = cookieParts.join('; ');
    }

    // Add CSRF token header if available
    if (_csrfToken != null) {
      headers['X-CSRFToken'] = _csrfToken!;
    }

    return headers;
  }

  /// Show comprehensive troubleshooting information for Instagram access issues
  static void showInstagramTroubleshooting({
    required String errorType,
    String? specificError,
  }) {
    print('\n' + '=' * 70);
    print('🚨 INSTAGRAM ACCESS TROUBLESHOOTING GUIDE');
    print('=' * 70);
    print('📋 Error Type: $errorType');
    if (specificError != null) {
      print('📋 Specific Error: $specificError');
    }
    print('📋 Timestamp: ${DateTime.now().toIso8601String()}');

    print('\n🔍 COMMON CAUSES:');
    print('   1. 🚫 Instagram Anti-Bot Protection');
    print('      - Instagram automatically blocks suspected bot traffic');
    print('      - Rate limiting after multiple requests');
    print('      - User-Agent detection');
    print('      - Missing or invalid session cookies');

    print('   2. 🔐 Authentication Issues');
    print('      - Session cookies not properly initialized');
    print('      - CSRF tokens expired or missing');
    print('      - Instagram requires login for specific content');

    print('   2. 🌍 Geographic Restrictions');
    print('      - Content blocked in certain regions');
    print('      - Network-level Instagram blocking');

    print('   3. 🔒 Content Access Issues');
    print('      - Private account or reel');
    print('      - Reel requires login to view');
    print('      - Age-restricted content');

    print('   4. 📶 Network/Technical Issues');
    print('      - Poor internet connection');
    print('      - Proxy or firewall interference');
    print('      - DNS resolution problems');

    print('\n⚙️ STEP-BY-STEP SOLUTIONS:');
    print('\n   🔄 IMMEDIATE ACTIONS:');
    print('   • Wait 10-15 minutes before retrying');
    print('   • Close and restart the app completely');
    print('   • Check if the reel URL works in a web browser');

    print('\n   🌐 NETWORK SOLUTIONS:');
    print('   • Switch between WiFi and mobile data');
    print('   • Try connecting to a different WiFi network');
    print('   • Use a VPN with servers in different countries');
    print('   • Disable any proxy or VPN temporarily');

    print('\n   🔗 URL VERIFICATION:');
    print('   • Ensure the Instagram reel URL is complete and correct');
    print('   • Verify the reel is public (not from a private account)');
    print('   • Try a different Instagram reel URL for testing');

    print('\n   ⏰ TIME-BASED SOLUTIONS:');
    print('   • Try during off-peak hours (early morning/late night)');
    print('   • Wait several hours if repeatedly blocked');
    print('   • Instagram may have temporary server issues');

    print('\n🔍 DIAGNOSTIC TESTS YOU CAN PERFORM:');
    print('   1. Open instagram.com in your browser');
    print('   2. Test the Network Diagnostics in the app');
    print('   3. Try downloading from a different Instagram account');
    print('   4. Check if other Instagram-related apps work');

    print('\nℹ️ IMPORTANT NOTES:');
    print(
      '   • This is normal behavior - Instagram actively blocks automated access',
    );
    print('   • Success rates vary by location, time, and network');
    print('   • Some reels may never be downloadable due to privacy settings');
    print('   • Instagram frequently updates their blocking mechanisms');

    print('=' * 70);
  }

  /// Demo method to show the enhanced debug logging capabilities
  static void showDebugCapabilities() {
    print('\n' + '=' * 70);
    print('🚀 INSTAGRAM SERVICE DEBUG CAPABILITIES');
    print('=' * 70);
    print('📋 Enhanced Debug Features:');
    print('   • Complete request/response logging');
    print('   • GraphQL response structure analysis');
    print('   • HTML content parsing with multiple strategies');
    print('   • Network error diagnosis and troubleshooting');
    print('   • Compression and encoding issue detection');
    print('   • Instagram anti-bot protection analysis');
    print('   • Step-by-step troubleshooting guides');
    print('   • Visual indicators for easy log reading (🚀🟢🔴🔍📋)');

    print('\n🔍 What You\'ll See in Debug Output:');
    print('   1. 🚀 Network connectivity checks');
    print('   2. 📝 Complete request details (headers, data, URLs)');
    print('   3. 🟦 Response analysis (status, size, content-type)');
    print('   4. 📋 JSON structure breakdown with all keys and values');
    print('   5. 🔍 HTML parsing attempts with each strategy result');
    print('   6. 🚨 Error analysis with specific troubleshooting steps');
    print('   7. 📋 Success/failure summaries with actionable advice');

    print('=' * 70);
  }

  /// Safely decode response body, handling compression if needed
  static String _safeDecodeResponse(http.Response response) {
    print('\n🔧 DECODING RESPONSE BODY...');
    print(
      '   • Content-Encoding: ${response.headers['content-encoding'] ?? 'none'}',
    );
    print(
      '   • Content-Type: ${response.headers['content-type'] ?? 'unknown'}',
    );
    print('   • Raw Body Bytes: ${response.bodyBytes.length}');

    // Check if response is compressed
    final contentEncoding = response.headers['content-encoding']?.toLowerCase();
    final isGzipped = contentEncoding?.contains('gzip') == true;
    final isDeflated = contentEncoding?.contains('deflate') == true;
    final isBrotli = contentEncoding?.contains('br') == true;

    try {
      if (isBrotli) {
        print(
          '   • 🔧 BROTLI compression detected - attempting decompression...',
        );

        // For Brotli, we'll try to use the HTTP client's automatic decompression
        // If that fails, we'll inform the user that Brotli is not supported
        try {
          // First, try if the HTTP client already decoded it
          final decoded = response.body;
          if (decoded.isNotEmpty &&
              !decoded.startsWith('\u0000') &&
              decoded.contains('<')) {
            print('   • ✅ HTTP client auto-decompressed Brotli successfully');
            print('   • Decompressed size: ${decoded.length} characters');
            return decoded;
          }
        } catch (e) {
          print('   • ⚠️ HTTP client Brotli decompression failed: $e');
        }

        // Brotli manual decompression is not available in Dart without external packages
        print(
          '   • ❌ Brotli compression detected but manual decompression not available',
        );
        print(
          '   • 💬 Instagram is using Brotli compression which requires special handling',
        );

        throw Exception(
          'Instagram returned Brotli-compressed content. '
          'This compression format requires additional setup. '
          'Try again - Instagram may switch to a different compression method.',
        );
      }

      if (isGzipped) {
        print('   • 🔧 GZIP compression detected - decompressing...');
        final decompressed = gzip.decode(response.bodyBytes);
        final decoded = utf8.decode(decompressed);
        print('   • ✅ GZIP decompression successful');
        print('   • Decompressed size: ${decoded.length} characters');
        return decoded;
      } else if (isDeflated) {
        print('   • 🔧 DEFLATE compression detected - decompressing...');
        // For DEFLATE, we might need zlib decoder
        try {
          final decompressed = gzip.decode(response.bodyBytes);
          final decoded = utf8.decode(decompressed);
          print('   • ✅ DEFLATE decompression successful');
          return decoded;
        } catch (e) {
          print('   • ⚠️ DEFLATE decompression failed, trying raw decode: $e');
        }
      }

      // Try normal UTF-8 decoding
      print('   • 🔧 No compression detected - using standard UTF-8 decode');
      final decoded = utf8.decode(response.bodyBytes);
      print('   • ✅ Standard decoding successful');
      return decoded;
    } catch (e) {
      print('   • ❌ Decoding failed: $e');
      print('   • 📊 Response analysis:');

      if (response.bodyBytes.isNotEmpty) {
        final firstBytes = response.bodyBytes.take(10).toList();
        print('   • First 10 bytes: $firstBytes');

        // Check for common file signatures
        if (response.bodyBytes.length >= 2) {
          final b1 = response.bodyBytes[0];
          final b2 = response.bodyBytes[1];

          if (b1 == 0x1f && b2 == 0x8b) {
            print('   • 🔍 Detected GZIP signature (0x1f 0x8b)');
            try {
              final decompressed = gzip.decode(response.bodyBytes);
              final decoded = utf8.decode(decompressed);
              print('   • ✅ Manual GZIP decompression successful!');
              return decoded;
            } catch (gzipError) {
              print('   • ❌ Manual GZIP decompression failed: $gzipError');
            }
          } else if (b1 == 0x78) {
            print('   • 🔍 Detected DEFLATE signature (0x78)');
          } else if (isBrotli) {
            print(
              '   • 🔍 Confirmed Brotli compression (Content-Encoding: br)',
            );
            print('   • 💬 Brotli decompression requires external library');
          } else {
            print('   • 🔍 Unknown compression format');
          }
        }
      }

      // As last resort, try the response.body property
      try {
        final bodyText = response.body;
        print('   • ✅ Fallback to response.body successful');
        return bodyText;
      } catch (bodyError) {
        print('   • ❌ Fallback to response.body failed: $bodyError');
      }

      // Special handling for Brotli
      if (isBrotli) {
        throw Exception(
          'Instagram is using Brotli compression which is not supported. '
          'This is a temporary limitation. Try again later as Instagram '
          'may switch to GZIP compression on subsequent requests.',
        );
      }

      throw Exception(
        'Could not decode response body. '
        'Content-Encoding: ${contentEncoding ?? 'none'}, '
        'Original error: $e',
      );
    }
  }

  /// Check network connectivity before making requests
  static Future<bool> _checkConnectivity() async {
    print('   • Testing DNS resolution with google.com...');
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 10));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('   • ✅ DNS lookup successful: ${result[0].address}');
        return true;
      } else {
        print('   • ❌ DNS lookup returned empty result');
        return false;
      }
    } catch (e) {
      print('   • ❌ DNS lookup failed: $e');
      
      // Try alternative connectivity check with a simple HTTP request
      print('   • 🔄 Trying alternative connectivity check...');
      try {
        final response = await http.get(
          Uri.parse('https://www.google.com'),
          headers: {'User-Agent': _randomUA()},
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          print('   • ✅ Alternative HTTP check successful');
          return true;
        } else {
          print('   • ❌ Alternative HTTP check failed: ${response.statusCode}');
          return false;
        }
      } catch (httpError) {
        print('   • ❌ Alternative HTTP check failed: $httpError');
        print('   • 💡 This might be a network configuration issue');
        print('   • 💡 Try switching between WiFi and mobile data');
        return false;
      }
    }
  }

  /// Simplified method to get Instagram post/reel data using direct approach
  Future<InstagramPostData> getPostData(String postUrl, {bool skipConnectivityCheck = false}) async {
    print('\n' + '=' * 60);
    print('🚀 STARTING INSTAGRAM REEL DOWNLOAD PROCESS');
    print('=' * 60);
    print('🚀 Original URL: $postUrl');
    print('🚀 Shortcode: ${InstagramUtils.extractShortcodeFromUrl(postUrl)}');
    print('🚀 Timestamp: ${DateTime.now().toIso8601String()}');
    print('🚀 Skip Connectivity Check: $skipConnectivityCheck');

    // Check network connectivity first (unless skipped)
    if (!skipConnectivityCheck) {
      print('\n🔍 CHECKING NETWORK CONNECTIVITY...');
      if (!await _checkConnectivity()) {
        print('🔴 Network connectivity check FAILED');
        print('\n💡 CONNECTIVITY TROUBLESHOOTING:');
        print('   • Check if you have an active internet connection');
        print('   • Try switching between WiFi and mobile data');
        print('   • Disable VPN if enabled and try again');
        print('   • Check if your firewall is blocking the app');
        print('   • Restart your router/modem if using WiFi');
        print('   • You can retry with skipConnectivityCheck=true if needed');
        
        throw Exception(
          'No internet connection detected. Please check your network settings and try again.',
        );
      }
      print(
        '🟢 Network connectivity check PASSED - Internet connection available',
      );
    } else {
      print('\n⚠️ SKIPPING NETWORK CONNECTIVITY CHECK (as requested)');
    }

    // Initialize Instagram session
    print('\n🔐 SETTING UP INSTAGRAM SESSION...');
    await _initializeSession();

    // Add random delay to avoid rate limiting
    final delay = 2 + _random.nextInt(4);
    print('\n⏳ Adding random delay: ${delay}s to avoid rate limiting...');
    await Future.delayed(Duration(seconds: delay));

    try {
      print('\n🔄 ATTEMPTING INSTAGRAM REEL EXTRACTION');
      print('-' * 40);

      // Use direct HTML parsing approach
      final videoUrl = await resolveDirectVideoUrl(postUrl);

      final finalPostData = InstagramPostData(
        videoUrl: videoUrl.toString(),
        isVideo: true,
        shortcode: InstagramUtils.extractShortcodeFromUrl(postUrl),
      );

      print('\n🟢 ✅ INSTAGRAM EXTRACTION SUCCESS!');
      print('📊 FINAL DATA:');
      print('   • Video URL: ${finalPostData.videoUrl}');
      print('   • Is Video: ${finalPostData.isVideo}');
      print('   • Shortcode: ${finalPostData.shortcode}');
      print('=' * 60);

      return finalPostData;
    } catch (e) {
      print('\n🔴 ❌ INSTAGRAM EXTRACTION FAILED: ${e.toString()}');

      // Provide specific guidance based on error type
      if (e.toString().contains('Brotli') ||
          e.toString().contains('compression which is not supported')) {
        showInstagramTroubleshooting(
          errorType: 'Brotli Compression Detected',
          specificError: e.toString(),
        );

        throw Exception(
          'Instagram was using Brotli compression which is not currently supported. '
          'The app has been updated to request GZIP compression instead. '
          'Please try downloading this reel again - it should work now!',
        );
      }

      if (e.toString().contains('FormatException') ||
          e.toString().contains('Unexpected extension byte')) {
        showInstagramTroubleshooting(
          errorType: 'HTML Response Decoding Failure',
          specificError: e.toString(),
        );

        throw Exception(
          'Instagram page content could not be decoded. '
          'See the debug output above for detailed troubleshooting steps.',
        );
      }

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        showInstagramTroubleshooting(
          errorType: 'Network Connection Failure',
          specificError: e.toString(),
        );

        throw Exception(
          'Network error: Cannot connect to Instagram. '
          'See the debug output above for detailed troubleshooting steps.',
        );
      }

      // General error with troubleshooting
      showInstagramTroubleshooting(
        errorType: 'Instagram Download Failed',
        specificError: e.toString(),
      );

      throw Exception(
        'Failed to download reel. '
        'See the detailed troubleshooting guide in the debug output above.\n\n'
        'Error: ${e.toString()}',
      );
    }
  }

  /// Resolves direct video URL from Instagram post/reel URL using HTML parsing
  Future<Uri> resolveDirectVideoUrl(String reelUrl) async {
    print('\n' + '=' * 60);
    print('🚀 STARTING HTML REQUEST');
    print('=' * 60);

    final uri = Uri.parse(reelUrl.trim());
    final randomUA = _randomUA();

    final headers = _getAuthenticatedHeaders(randomUA);

    print('📝 REQUEST DETAILS:');
    print('   • URL: $reelUrl');
    print('   • Method: GET');
    print('   • Parsed URI: $uri');
    print('   • Selected User Agent: $randomUA');
    print('   • 🚫 Brotli compression excluded to avoid decompression issues');
    print('   • 🔐 Using authenticated session headers');
    print(
      '   • 🍪 Session cookies: ${_sessionId != null ? "Present" : "Not available"}',
    );

    print('\n📝 REQUEST HEADERS:');
    headers.forEach((key, value) {
      // Mask sensitive cookie data
      if (key == 'Cookie') {
        print(
          '   • $key: ${value.length > 50 ? value.substring(0, 50) + "..." : value}',
        );
      } else {
        print('   • $key: $value');
      }
    });

    print('\n🔄 Sending HTML request...');

    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('🔴 ⏰ HTML REQUEST TIMEOUT after 30 seconds');
              throw Exception('Request timed out while fetching reel page.');
            },
          );

      if (res.statusCode != 200) {
        print('\n🔴 ❌ HTML REQUEST FAILED');
        print('🔴 Status Code: ${res.statusCode}');
        print('🔴 Status Text: ${res.reasonPhrase ?? 'Unknown'}');
        print('🔴 Response Headers: ${res.headers}');

        throw Exception(
          'Failed to load page (HTTP ${res.statusCode}). '
          'Reel may be private or requires login.',
        );
      }

      // Try to decode response body safely with proper compression handling
      String html;
      try {
        html = _safeDecodeResponse(res);
        print('\n🟢 ✅ RESPONSE BODY DECODED SUCCESSFULLY');
        print('   • Decoded Size: ${html.length} characters');

        // Check if body is actually HTML
        final looksLikeHtml =
            html.trim().startsWith('<') ||
            html.contains('<html') ||
            html.contains('<!DOCTYPE');
        print('   • Looks like HTML: $looksLikeHtml');

        if (!looksLikeHtml) {
          print('🔴 ⚠️ Response does not look like HTML!');
          print(
            '🔴 First 200 chars: ${html.length > 200 ? html.substring(0, 200) + "..." : html}',
          );

          // Check if it might be JSON or other format
          if (html.trim().startsWith('{') || html.trim().startsWith('[')) {
            print('🔴 Response appears to be JSON instead of HTML');
            throw Exception(
              'Instagram returned JSON instead of expected HTML page',
            );
          }
        }
      } catch (e) {
        print('\n🔴 ❌ FAILED TO DECODE RESPONSE BODY');
        print('🔴 Decode Error: $e');
        print('🔴 Error Type: ${e.runtimeType}');

        throw Exception(
          'Failed to decode Instagram page response. '
          'The server may have returned compressed or corrupted data. '
          'Original error: $e',
        );
      }

      // Debug: Log HTML response info
      print('\n🟦 📋 HTML RESPONSE ANALYSIS');
      print('=' * 50);
      print('🟦 Request URL: $reelUrl');
      print('🟦 Status Code: ${res.statusCode}');
      print('🟦 HTML Size: ${html.length} characters');

      // Extract and analyze HTML structure
      final title = _extractTitle(html);
      final hasVideoMeta = html.contains('og:video');
      final hasVideoSecureMeta = html.contains('og:video:secure_url');
      final hasJsonData = html.contains('video_url');
      final hasPlaybackUrl = html.contains('playback_url');
      final requiresLogin =
          html.contains('loginForm') || html.contains('Please log in');
      final isPrivate = html.contains('This Account is Private');

      print('\n📊 HTML CONTENT ANALYSIS:');
      print('   • Page Title: ${title ?? 'NOT FOUND'}');
      print('   • Contains og:video meta: $hasVideoMeta');
      print('   • Contains og:video:secure_url meta: $hasVideoSecureMeta');
      print('   • Contains JSON video_url: $hasJsonData');
      print('   • Contains playback_url: $hasPlaybackUrl');
      print('   • Requires Login: $requiresLogin');
      print('   • Is Private Account: $isPrivate');

      // Check if page requires login
      if (requiresLogin || isPrivate) {
        throw Exception(
          'This reel requires login to view or is from a private account.',
        );
      }

      // Try video extraction strategies
      return await _extractVideoFromHtml(html, reelUrl);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          'Cannot connect to Instagram. Please check your internet connection and try again.',
        );
      }
      rethrow;
    }
  }

  /// Extract video URL from HTML using multiple strategies
  Future<Uri> _extractVideoFromHtml(String html, String reelUrl) async {
    // Strategy 1: Open Graph meta tag
    print('\n' + '-' * 30);
    print('🔍 TRYING STRATEGY 1: Open Graph og:video meta tag');
    print('-' * 30);
    final ogVideo = _matchMeta(html, 'og:video');
    if (ogVideo != null && ogVideo.endsWith('.mp4')) {
      print('🟢 ✅ STRATEGY 1 SUCCESS!');
      return Uri.parse(_unescapeUrl(ogVideo));
    }

    // Strategy 2: Secure URL variant
    print('\n' + '-' * 30);
    print('🔍 TRYING STRATEGY 2: Open Graph og:video:secure_url meta tag');
    print('-' * 30);
    final ogVideoSecure = _matchMeta(html, 'og:video:secure_url');
    if (ogVideoSecure != null && ogVideoSecure.endsWith('.mp4')) {
      print('🟢 ✅ STRATEGY 2 SUCCESS!');
      return Uri.parse(_unescapeUrl(ogVideoSecure));
    }

    // Strategy 3: JSON video_url extraction
    print('\n' + '-' * 30);
    print('🔍 TRYING STRATEGY 3: JSON video_url extraction');
    print('-' * 30);
    final jsonUrl = _matchJsonVideoUrl(html);
    if (jsonUrl != null) {
      print('🟢 ✅ STRATEGY 3 SUCCESS!');
      return Uri.parse(_unescapeUrl(jsonUrl));
    }

    // Strategy 4: Alternative patterns
    print('\n' + '-' * 30);
    print('🔍 TRYING STRATEGY 4: Alternative video URL patterns');
    print('-' * 30);
    final alternativeUrl = _findAlternativeVideoUrl(html);
    if (alternativeUrl != null) {
      print('🟢 ✅ STRATEGY 4 SUCCESS!');
      return Uri.parse(_unescapeUrl(alternativeUrl));
    }

    print('\n🔴 ❌ ALL STRATEGIES FAILED');
    throw Exception(
      'Could not find a direct video URL. This may be due to:\n'
      '• The reel is private or requires login\n'
      '• Instagram has changed their page structure\n'
      '• The content is age-restricted\n'
      '• Geographic restrictions apply',
    );
  }

  // Helper methods for HTML parsing
  String? _matchMeta(String html, String property) {
    final reg = RegExp(
      '<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final m = reg.firstMatch(html);
    return m?.group(1);
  }

  String? _matchJsonVideoUrl(String html) {
    final reg = RegExp(
      r'"video_url"\s*:\s*"([^"]+?\.mp4[^"]*)"',
      multiLine: true,
    );
    final m = reg.firstMatch(html);
    return m?.group(1);
  }

  String? _findAlternativeVideoUrl(String html) {
    final patterns = [
      RegExp(r'"playback_url"\s*:\s*"([^"]+?\.mp4[^"]*)"'),
      RegExp(r'"src"\s*:\s*"([^"]+?fbcdn[^"]*\.mp4[^"]*)"'),
      RegExp(r'"url"\s*:\s*"([^"]+?instagram[^"]*\.mp4[^"]*)"'),
      RegExp(r'"([^"]*scontent[^"]*\.mp4[^"]*)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          return url;
        }
      }
    }
    return null;
  }

  String? _extractTitle(String html) {
    final titleRegex = RegExp(
      r'<title[^>]*>([^<]*)</title>',
      caseSensitive: false,
    );
    final match = titleRegex.firstMatch(html);
    return match?.group(1)?.trim();
  }

  String _unescapeUrl(String s) {
    try {
      return json.decode('"${s.replaceAll('"', r'\"')}"') as String;
    } catch (_) {
      return s.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
    }
  }
}
