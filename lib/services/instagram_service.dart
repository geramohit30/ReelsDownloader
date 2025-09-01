import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/instagram_types.dart';
import 'instagram_utils.dart';

class InstagramService {
  // Enhanced user agent pool with better mobile/desktop distribution
  static final List<Map<String, dynamic>> _userAgentPool = [
    // Mobile User Agents (Higher success rate for Instagram)
    {
      'ua': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'type': 'mobile',
      'weight': 3,
    },
    {
      'ua': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
      'type': 'mobile',
      'weight': 2,
    },
    {
      'ua': 'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
      'type': 'mobile',
      'weight': 3,
    },
    {
      'ua': 'Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Mobile Safari/537.36',
      'type': 'mobile',
      'weight': 2,
    },
    {
      'ua': 'Mozilla/5.0 (Linux; Android 11; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.101 Mobile Safari/537.36',
      'type': 'mobile',
      'weight': 2,
    },
    // Desktop User Agents (Fallback options)
    {
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'type': 'desktop',
      'weight': 1,
    },
    {
      'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'type': 'desktop',
      'weight': 1,
    },
    {
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
      'type': 'desktop',
      'weight': 1,
    },
  ];
  
  // Track success rates for each user agent
  static final Map<String, int> _userAgentSuccess = {};
  static final Map<String, int> _userAgentAttempts = {};
  static final math.Random _random = math.Random();

  // Session data for Instagram authentication with persistence
  static String? _sessionId;
  static String? _csrfToken;
  static String? _mid;
  static String? _ig_did;
  static String? _ig_nrcb;
  static DateTime? _sessionExpiry;
  static const int _sessionValidityHours = 6; // Sessions expire after 6 hours

  /// Select user agent based on success rates, weights, and content type preference
  static String _selectOptimalUserAgent({String preference = 'mobile'}) {
    // Filter agents by preference
    List<Map<String, dynamic>> preferredAgents;
    if (preference == 'desktop') {
      preferredAgents = _userAgentPool.where((agent) => agent['type'] == 'desktop').toList();
    } else {
      preferredAgents = _userAgentPool.where((agent) => agent['type'] == 'mobile').toList();
    }
    
    // If no preferred agents, use all
    if (preferredAgents.isEmpty) preferredAgents = _userAgentPool;
    
    // Calculate weighted user agents based on success rates
    final weightedAgents = <String>[];
    
    for (final agent in preferredAgents) {
      final ua = agent['ua'] as String;
      final baseWeight = agent['weight'] as int;
      
      // Calculate success rate (default to 50% for new agents)
      final attempts = _userAgentAttempts[ua] ?? 0;
      final successes = _userAgentSuccess[ua] ?? 0;
      final successRate = attempts > 0 ? successes / attempts : 0.5;
      
      // Boost weight for agents with good success rates
      double adjustedWeight = baseWeight * (1 + successRate);
      
      // Add recency bonus (prefer recently successful agents)
      if (attempts > 0 && successes > 0) {
        adjustedWeight *= 1.2;
      }
      
      // Calculate final weight
      final finalWeight = adjustedWeight.round();
      
      // Add multiple entries based on weight
      for (int i = 0; i < finalWeight; i++) {
        weightedAgents.add(ua);
      }
    }
    
    if (weightedAgents.isEmpty) {
      // Fallback to first mobile agent
      return _userAgentPool.first['ua'] as String;
    }
    
    final selected = weightedAgents[_random.nextInt(weightedAgents.length)];
    
    // Log selection for debugging
    final agentType = _userAgentPool.firstWhere((a) => a['ua'] == selected)['type'];
    final attempts = _userAgentAttempts[selected] ?? 0;
    final successes = _userAgentSuccess[selected] ?? 0;
    final rate = attempts > 0 ? (successes / attempts * 100).toStringAsFixed(1) : 'New';
    
    print('\n🎯 SELECTED USER AGENT:');
    print('   • Type: $agentType');
    print('   • Success Rate: $rate% ($successes/$attempts)');
    print('   • Agent: ${selected.substring(0, math.min(80, selected.length))}...');
    
    return selected;
  }
  
  /// Record success/failure for user agent optimization
  static void _recordUserAgentResult(String userAgent, bool success) {
    _userAgentAttempts[userAgent] = (_userAgentAttempts[userAgent] ?? 0) + 1;
    if (success) {
      _userAgentSuccess[userAgent] = (_userAgentSuccess[userAgent] ?? 0) + 1;
    }
    
    // Log success rates periodically
    if (_userAgentAttempts[userAgent]! % 5 == 0) {
      final attempts = _userAgentAttempts[userAgent]!;
      final successes = _userAgentSuccess[userAgent] ?? 0;
      final rate = (successes / attempts * 100).toStringAsFixed(1);
      print('📊 User Agent Success Rate: ${userAgent.substring(0, 50)}... = $rate% ($successes/$attempts)');
    }
  }

  /// Initialize session by visiting Instagram homepage to get cookies with persistence
  static Future<void> _initializeSession() async {
    // Check if existing session is still valid
    if (_isSessionValid()) {
      print('   • Session already initialized and valid, reusing existing session');
      print('   • Session expires: ${_sessionExpiry?.toIso8601String()}');
      return;
    }

    print('🔐 INITIALIZING INSTAGRAM SESSION...');
    print('   • Visiting Instagram homepage to obtain session cookies');

    try {
      final headers = {
        'User-Agent': _selectOptimalUserAgent(),
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
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
          
          // Set session expiry
          _sessionExpiry = DateTime.now().add(Duration(hours: _sessionValidityHours));
          
          print('✅ Session initialized successfully');
          print('   • Session ID: ${_sessionId?.substring(0, 8)}...');
          print('   • CSRF Token: ${_csrfToken?.substring(0, 8)}...');
          print('   • Valid until: ${_sessionExpiry?.toIso8601String()}');
          
          // Log session quality
          final sessionQuality = _assessSessionQuality();
          print('   • Session quality: $sessionQuality');
        } else {
          print('⚠️ No cookies received from Instagram');
          print('   • This is unusual but we\'ll continue without session cookies');
          _setMinimalSession();
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
  
  /// Check if current session is still valid
  static bool _isSessionValid() {
    if (_sessionExpiry == null) return false;
    if (DateTime.now().isAfter(_sessionExpiry!)) {
      print('   • Session expired, reinitializing...');
      _clearSession();
      return false;
    }
    return _csrfToken != null; // At minimum we need a CSRF token
  }
  
  /// Clear expired or invalid session data
  static void _clearSession() {
    _sessionId = null;
    _csrfToken = null;
    _mid = null;
    _ig_did = null;
    _ig_nrcb = null;
    _sessionExpiry = null;
  }
  
  /// Set minimal session for cases where cookies aren't received
  static void _setMinimalSession() {
    _csrfToken = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    _sessionExpiry = DateTime.now().add(Duration(hours: 1)); // Shorter expiry for fallback
  }
  
  /// Assess the quality of the current session
  static String _assessSessionQuality() {
    int score = 0;
    if (_sessionId != null) score += 2;
    if (_csrfToken != null) score += 2;
    if (_mid != null) score += 1;
    if (_ig_did != null) score += 1;
    if (_ig_nrcb != null) score += 1;
    
    if (score >= 6) return 'Excellent';
    if (score >= 4) return 'Good';
    if (score >= 2) return 'Fair';
    return 'Poor';
  }

  /// Extract session data from Instagram cookies with enhanced parsing
  static void _extractSessionData(String cookies) {
    final cookieList = cookies.split(',');
    final parsedCookies = <String, String>{};

    for (final cookie in cookieList) {
      final parts = cookie.trim().split(';')[0].split('=');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();
        parsedCookies[name] = value;
      }
    }
    
    // Extract known Instagram cookies
    _sessionId = parsedCookies['sessionid'];
    _csrfToken = parsedCookies['csrftoken'];
    _mid = parsedCookies['mid'];
    _ig_did = parsedCookies['ig_did'];
    _ig_nrcb = parsedCookies['ig_nrcb'];
    
    // Log what we extracted
    print('   • Extracted cookies: ${parsedCookies.keys.toList()}');
    
    // If we didn't get a CSRF token, generate a fallback
    if (_csrfToken == null || _csrfToken!.isEmpty) {
      _csrfToken = 'generated_${DateTime.now().millisecondsSinceEpoch}';
      print('   • Generated fallback CSRF token');
    }
  }

  /// Get authenticated headers for Instagram requests with enhanced session management
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
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
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
          headers: {'User-Agent': _selectOptimalUserAgent()},
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
  /// Primary method: Try GraphQL API first, fallback to HTML parsing with retry logic
  Future<InstagramPostData> getPostData(String postUrl, {bool skipConnectivityCheck = false}) async {
    print('\n' + '=' * 60);
    print('🚀 STARTING INSTAGRAM REEL DOWNLOAD PROCESS');
    print('=' * 60);
    print('🚀 Original URL: $postUrl');
    print('🚀 Shortcode: ${InstagramUtils.extractShortcodeFromUrl(postUrl)}');
    print('🚀 Timestamp: ${DateTime.now().toIso8601String()}');
    print('🚀 Skip Connectivity Check: $skipConnectivityCheck');

    final selectedUA = _selectOptimalUserAgent();
    
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
    await Future.delayed(Duration(seconds: delay.toInt()));

    // Try extraction with retry logic
    return await _performExtractionWithRetry(postUrl, selectedUA);
  }
  
  /// Perform extraction with retry logic and exponential backoff
  Future<InstagramPostData> _performExtractionWithRetry(String postUrl, String userAgent) async {
    const maxRetries = 3;
    const baseDelaySeconds = 2;
    String currentUserAgent = userAgent;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('\n🔄 EXTRACTION ATTEMPT $attempt/$maxRetries');
      print('=' * 50);
      
      try {
        // Strategy 1: Try GraphQL API first
        if (attempt <= 2) { // Try GraphQL for first 2 attempts
          try {
            print('\n🔄 ATTEMPTING STRATEGY 1: GraphQL API');
            print('-' * 40);
            
            final postData = await _tryGraphQLExtraction(postUrl, currentUserAgent);
            if (postData.videoUrl != null && postData.videoUrl!.isNotEmpty) {
              _recordUserAgentResult(currentUserAgent, true);
              print('🟢 ✅ GRAPHQL STRATEGY SUCCESS!');
              print('📊 EXTRACTED DATA:');
              print('   • Video URL: ${postData.videoUrl}');
              print('   • Username: ${postData.username ?? "N/A"}');
              print('   • Caption: ${postData.caption?.substring(0, math.min(50, postData.caption!.length)) ?? "N/A"}...');
              print('=' * 60);
              return postData;
            }
          } catch (e) {
            print('🔴 GraphQL Strategy FAILED: $e');
            
            // Check if it's a rate limiting error (should not retry immediately)
            if (e.toString().contains('429') || e.toString().contains('rate limit')) {
              print('🔴 Rate limiting detected - extending delay before retry');
              if (attempt < maxRetries) {
                final extendedDelay = baseDelaySeconds * math.pow(2, attempt) * 3; // 3x longer for rate limits
                print('⏳ Extended delay: ${extendedDelay.toInt()}s for rate limiting');
                await Future.delayed(Duration(seconds: extendedDelay.toInt()));
              }
              if (attempt == maxRetries) rethrow; // Give up after max retries
              continue; // Skip to next attempt
            }
          }
        }

        // Strategy 2: HTML parsing with intelligent user agent switching
        try {
          print('\n🔄 ATTEMPTING STRATEGY 2: HTML Parsing Fallback');
          print('-' * 40);
          
          // For retries, try different user agent types
          if (attempt > 1) {
            final preference = attempt == 2 ? 'desktop' : 'mobile';
            currentUserAgent = _selectOptimalUserAgent(preference: preference);
            print('   • Retry $attempt: Switching to $preference user agent');
          }
          
          final videoUrl = await resolveDirectVideoUrl(postUrl, customUserAgent: currentUserAgent);
          final shortcode = InstagramUtils.extractShortcodeFromUrl(postUrl);
          
          final finalPostData = InstagramPostData(
            videoUrl: videoUrl.toString(),
            isVideo: true,
            shortcode: shortcode,
          );

          _recordUserAgentResult(currentUserAgent, true);
          print('🟢 ✅ HTML PARSING STRATEGY SUCCESS!');
          print('📊 FINAL DATA:');
          print('   • Video URL: ${finalPostData.videoUrl}');
          print('   • Is Video: ${finalPostData.isVideo}');
          print('   • Shortcode: ${finalPostData.shortcode}');
          print('=' * 60);

          return finalPostData;
        } catch (e) {
          print('🔴 HTML Parsing Strategy FAILED: $e');
          
          // Check if this is a content quality issue
          if (e.toString().contains('incomplete page content') || 
              e.toString().contains('anti-bot protection')) {
            print('🔴 Content quality issue detected - likely Instagram blocking');
            
            if (attempt < maxRetries) {
              // For content quality issues, wait longer and try different approach
              final extendedDelay = baseDelaySeconds * math.pow(2, attempt) * 2;
              print('⏳ Extended delay for anti-bot protection: ${extendedDelay.toInt()}s');
              await Future.delayed(Duration(seconds: extendedDelay.toInt()));
              
              // Clear session for next attempt
              if (attempt == 2) {
                print('🗑️ Clearing session to try fresh authentication');
                _clearSession();
              }
              
              continue;
            }
          }
          
          // Check if we should retry
          if (attempt < maxRetries) {
            // Calculate exponential backoff delay
            final delaySeconds = (baseDelaySeconds * math.pow(2, attempt - 1)).toInt();
            print('🔄 RETRY LOGIC: Attempt $attempt failed, retrying in ${delaySeconds}s...');
            print('   • Error: ${e.toString().substring(0, math.min(100, e.toString().length))}...');
            
            // Add jitter to prevent thundering herd
            final jitter = _random.nextInt(2);
            await Future.delayed(Duration(seconds: delaySeconds + jitter));
            
            continue; // Retry
          } else {
            // Final attempt failed
            _recordUserAgentResult(currentUserAgent, false);
            
            // Provide comprehensive error information
            showInstagramTroubleshooting(
              errorType: 'All Strategies Failed After $maxRetries Attempts',
              specificError: e.toString(),
            );
            
            throw Exception(
              'Failed to download reel after $maxRetries attempts using both GraphQL and HTML strategies. '
              'Instagram may be actively blocking access or the content may be restricted. '
              'See the detailed troubleshooting guide in the debug output above.\n\n'
              'Final error: ${e.toString()}',
            );
          }
        }
      } catch (e) {
        // Handle unexpected errors
        if (attempt == maxRetries) {
          _recordUserAgentResult(currentUserAgent, false);
          rethrow;
        }
        
        print('🔴 Unexpected error on attempt $attempt: $e');
        final delaySeconds = (baseDelaySeconds * math.pow(2, attempt - 1)).toInt();
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    
    // This should never be reached, but just in case
    throw Exception('Max retries exceeded without successful extraction');
  }
  
  /// GraphQL API extraction method
  Future<InstagramPostData> _tryGraphQLExtraction(String postUrl, String userAgent) async {
    final shortcode = InstagramUtils.extractShortcodeFromUrl(postUrl);
    final graphqlData = InstagramUtils.encodeGraphqlRequestData(shortcode);
    
    print('📝 GraphQL REQUEST DETAILS:');
    print('   • Shortcode: $shortcode');
    print('   • User Agent: ${userAgent.substring(0, 50)}...');
    print('   • Endpoint: https://www.instagram.com/api/graphql/');
    
    final headers = {
      'User-Agent': userAgent,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Requested-With': 'XMLHttpRequest',
      'X-IG-App-ID': '936619743392459',
      'X-FB-LSD': 'AVqbxe3J_YA',
      'X-ASBD-ID': '129477',
      'Origin': 'https://www.instagram.com',
      'Referer': 'https://www.instagram.com/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
    };
    
    // Add session cookies if available
    if (_csrfToken != null) {
      headers['X-CSRFToken'] = _csrfToken!;
      final cookieParts = <String>[];
      if (_sessionId != null) cookieParts.add('sessionid=$_sessionId');
      if (_csrfToken != null) cookieParts.add('csrftoken=$_csrfToken');
      if (_mid != null) cookieParts.add('mid=$_mid');
      if (cookieParts.isNotEmpty) {
        headers['Cookie'] = cookieParts.join('; ');
      }
    }
    
    print('🔄 Sending GraphQL request...');
    
    final response = await http.post(
      Uri.parse('https://www.instagram.com/api/graphql/'),
      headers: headers,
      body: graphqlData,
    ).timeout(
      Duration(seconds: 30),
      onTimeout: () {
        throw Exception('GraphQL request timed out after 30 seconds');
      },
    );
    
    print('📊 GraphQL Response:');
    print('   • Status Code: ${response.statusCode}');
    print('   • Content Length: ${response.body.length}');
    print('   • Content-Type: ${response.headers['content-type'] ?? "unknown"}');
    
    if (response.statusCode != 200) {
      throw Exception('GraphQL API returned status ${response.statusCode}: ${response.reasonPhrase}');
    }
    
    // Check if response is HTML (indicates blocking)
    if (response.body.trim().startsWith('<')) {
      print('🔴 Instagram returned HTML instead of JSON - Anti-bot protection active!');
      print('🔴 Full HTML response (first 1000 chars): ${response.body.substring(0, math.min(1000, response.body.length))}');
      throw Exception('Instagram is blocking API access - returned HTML instead of JSON');
    }
    
    // Parse JSON response
    Map<String, dynamic> jsonData;
    try {
      jsonData = json.decode(response.body) as Map<String, dynamic>;
      print('🟢 Successfully parsed JSON response');
      print('🟢 JSON Keys: ${jsonData.keys.toList()}');
    } catch (e) {
      print('🔴 JSON Parse Error: $e');
      print('🔴 Raw response that failed to parse (first 1000 chars): ${response.body.substring(0, math.min(1000, response.body.length))}');
      throw Exception('Invalid JSON response from GraphQL API');
    }
    
    // Extract data from GraphQL response
    final data = jsonData['data'] as Map<String, dynamic>?;
    if (data == null) {
      print('🔴 GraphQL response missing "data" field');
      print('🔴 Available keys: ${jsonData.keys.toList()}');
      throw Exception('GraphQL response missing data field');
    }
    
    print('🟢 Data field exists: ${data.runtimeType}');
    print('🟢 Data keys: ${data.keys.toList()}');
    
    final mediaData = data['xdt_shortcode_media'] as Map<String, dynamic>?;
    if (mediaData == null) {
      print('🔴 No xdt_shortcode_media found in response');
      print('🔴 Available data keys: ${data.keys.toList()}');
      throw Exception('No media data found in GraphQL response');
    }
    
    print('🟢 Media data found: ${mediaData.keys.toList()}');
    
    return InstagramPostData.fromGraphQL(mediaData);
  }

  /// Resolves direct video URL from Instagram post/reel URL using HTML parsing
  Future<Uri> resolveDirectVideoUrl(String reelUrl, {String? customUserAgent}) async {
    print('\n' + '=' * 60);
    print('🚀 STARTING HTML REQUEST');
    print('=' * 60);

    final uri = Uri.parse(reelUrl.trim());
    final selectedUA = customUserAgent ?? _selectOptimalUserAgent();

    final headers = _getAuthenticatedHeaders(selectedUA);

    print('📝 REQUEST DETAILS:');
    print('   • URL: $reelUrl');
    print('   • Method: GET');
    print('   • Parsed URI: $uri');
    print('   • Selected User Agent: $selectedUA');
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

  /// Extract video URL from HTML using multiple strategies with content validation
  Future<Uri> _extractVideoFromHtml(String html, String reelUrl) async {
    // First, validate HTML content quality
    final contentQuality = _analyzeHtmlContent(html);
    print('\n📊 HTML CONTENT QUALITY ANALYSIS:');
    print('   • Content size: ${html.length} characters');
    print('   • Quality score: ${contentQuality['score']}/10');
    print('   • Has video indicators: ${contentQuality['hasVideoIndicators']}');
    print('   • Page completeness: ${contentQuality['pageCompleteness']}');
    
    // If content quality is too low, throw specific error
    if (contentQuality['score'] < 3) {
      throw Exception(
        'Instagram returned incomplete page content (score: ${contentQuality['score']}/10). '
        'This typically indicates anti-bot protection is active. Try again in a few minutes.'
      );
    }

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
    
    // Strategy 5: Enhanced pattern matching for newer Instagram formats
    print('\n' + '-' * 30);
    print('🔍 TRYING STRATEGY 5: Enhanced pattern matching');
    print('-' * 30);
    final enhancedUrl = _findEnhancedVideoUrl(html);
    if (enhancedUrl != null) {
      print('🟢 ✅ STRATEGY 5 SUCCESS!');
      return Uri.parse(_unescapeUrl(enhancedUrl));
    }

    print('\n🔴 ❌ ALL STRATEGIES FAILED');
    
    // Provide detailed failure analysis
    final failureAnalysis = _analyzeExtractionFailure(html);
    print('\n🔍 FAILURE ANALYSIS:');
    failureAnalysis.forEach((key, value) => print('   • $key: $value'));
    
    throw Exception(
      'Could not find a direct video URL. Failure analysis: ${failureAnalysis['summary']}',
    );
  }
  
  /// Analyze HTML content quality to detect Instagram blocking
  Map<String, dynamic> _analyzeHtmlContent(String html) {
    int score = 0;
    final analysis = <String, dynamic>{};
    
    // Check for basic HTML structure
    if (html.contains('<!DOCTYPE html>') || html.contains('<html')) score += 1;
    
    // Check for Instagram-specific elements
    if (html.contains('instagram.com')) score += 1;
    if (html.contains('og:site_name')) score += 1;
    if (html.contains('og:title')) score += 1;
    
    // Check for video-related content
    bool hasVideoIndicators = false;
    if (html.contains('og:video') || html.contains('video_url') || 
        html.contains('playback_url') || html.contains('.mp4')) {
      score += 2;
      hasVideoIndicators = true;
    }
    
    // Check for Instagram app data
    if (html.contains('window._sharedData') || html.contains('window.__additionalDataLoaded')) {
      score += 2;
    }
    
    // Check content size (smaller pages are often blocked/limited)
    if (html.length > 500000) score += 2;
    else if (html.length > 200000) score += 1;
    
    // Check for login requirements
    bool requiresLogin = html.contains('loginForm') || html.contains('Login • Instagram');
    if (requiresLogin) score -= 2;
    
    // Page completeness
    String pageCompleteness = 'Unknown';
    if (html.length < 100000) pageCompleteness = 'Minimal';
    else if (html.length < 300000) pageCompleteness = 'Partial';
    else if (html.length < 600000) pageCompleteness = 'Standard';
    else pageCompleteness = 'Full';
    
    analysis['score'] = math.max(0, score);
    analysis['hasVideoIndicators'] = hasVideoIndicators;
    analysis['requiresLogin'] = requiresLogin;
    analysis['pageCompleteness'] = pageCompleteness;
    analysis['contentSize'] = html.length;
    
    return analysis;
  }
  
  /// Enhanced video URL finding with additional patterns
  String? _findEnhancedVideoUrl(String html) {
    final patterns = [
      // Instagram CDN patterns
      RegExp(r'"([^"]*instagram[^"]*\.fna\.fbcdn\.net[^"]*\.mp4[^"]*?)"'),
      RegExp(r'"([^"]*scontent[^"]*instagram[^"]*\.mp4[^"]*?)"'),
      
      // Video manifest patterns
      RegExp(r'"video_url"\s*:\s*"([^"]+?)"'),
      RegExp(r'"playback_url"\s*:\s*"([^"]+?)"'),
      
      // Data attribute patterns
      RegExp(r'data-video-url="([^"]+?)"'),
      RegExp(r'data-src="([^"]+?\.mp4[^"]*?)"'),
      
      // Script tag patterns
      RegExp(r'src:\s*"([^"]+?\.mp4[^"]*?)"'),
      RegExp(r'url:\s*"([^"]+?\.mp4[^"]*?)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4') && url.startsWith('http')) {
          print('   • Found with enhanced pattern: ${pattern.pattern}');
          return url;
        }
      }
    }
    return null;
  }
  
  /// Analyze why extraction failed
  Map<String, String> _analyzeExtractionFailure(String html) {
    final analysis = <String, String>{};
    
    if (html.length < 100000) {
      analysis['Page Size'] = 'Too small (${html.length} chars) - likely blocked content';
    } else {
      analysis['Page Size'] = 'Normal (${html.length} chars)';
    }
    
    if (html.contains('Login • Instagram')) {
      analysis['Login Required'] = 'Yes - Instagram requires authentication';
    } else {
      analysis['Login Required'] = 'No';
    }
    
    if (!html.contains('og:video') && !html.contains('video_url')) {
      analysis['Video Metadata'] = 'Missing - no video metadata found';
    } else {
      analysis['Video Metadata'] = 'Present but inaccessible';
    }
    
    if (html.contains('private account') || html.contains('This account is private')) {
      analysis['Account Status'] = 'Private account';
    } else {
      analysis['Account Status'] = 'Public account';
    }
    
    // Determine most likely cause
    String summary;
    if (html.length < 200000) {
      summary = 'Instagram anti-bot protection active (lightweight page served)';
    } else if (html.contains('Login')) {
      summary = 'Login required for this content';
    } else {
      summary = 'Video metadata present but extraction patterns failed';
    }
    
    analysis['summary'] = summary;
    
    return analysis;
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
  
  /// Manually clear session data (useful for troubleshooting)
  static void clearSession() {
    print('🗑️ Manually clearing Instagram session data...');
    _clearSession();
    print('✅ Session data cleared. Next request will initialize a fresh session.');
  }
  
  /// Get current session status for debugging
  static Map<String, dynamic> getSessionStatus() {
    return {
      'hasSession': _sessionId != null,
      'hasCSRFToken': _csrfToken != null,
      'sessionExpiry': _sessionExpiry?.toIso8601String(),
      'isValid': _isSessionValid(),
      'quality': _assessSessionQuality(),
      'cookies': {
        'sessionid': _sessionId != null ? '${_sessionId!.substring(0, math.min(8, _sessionId!.length))}...' : null,
        'csrftoken': _csrfToken != null ? '${_csrfToken!.substring(0, math.min(8, _csrfToken!.length))}...' : null,
        'mid': _mid != null ? '${_mid!.substring(0, math.min(8, _mid!.length))}...' : null,
        'ig_did': _ig_did != null,
        'ig_nrcb': _ig_nrcb != null,
      }
    };
  }
  
  /// Legacy method for backward compatibility - downloads reel and returns video URL
  Future<String> downloadReel(
    String postUrl, {
    bool skipConnectivityCheck = false,
  }) async {
    try {
      final postData = await getPostData(postUrl, skipConnectivityCheck: skipConnectivityCheck);
      
      if (postData.videoUrl == null || postData.videoUrl!.isEmpty) {
        throw Exception('No video URL found in post data');
      }
      
      return postData.videoUrl!;
    } catch (e) {
      // Enhanced error handling for legacy method
      if (e.toString().contains('rate limiting') ||
          e.toString().contains('429')) {
        throw Exception(
          'Instagram is temporarily blocking requests due to rate limiting. '
          'Please wait 10-15 minutes before trying again.',
        );
      }
      
      if (e.toString().contains('Could not find a direct video URL')) {
        throw Exception(
          'Could not extract video URL from Instagram. '
          'This may be due to the reel being private, age-restricted, or '
          'Instagram has changed their page structure.',
        );
      }

      // Re-throw with enhanced context
      throw Exception(
        'Failed to download reel. '
        'Error: ${e.toString()}',
      );
    }
  }
  
  /// Test method to verify improvements
  static Future<void> testReliabilityImprovements(String testUrl) async {
    print('\n' + '=' * 70);
    print('🧪 TESTING RELIABILITY IMPROVEMENTS');
    print('=' * 70);
    
    // Test user agent selection
    print('\n1. 🎯 TESTING USER AGENT SELECTION:');
    for (int i = 0; i < 3; i++) {
      final ua = _selectOptimalUserAgent();
      print('   Selection $i: ${ua.substring(0, math.min(60, ua.length))}...');
    }
    
    // Test session management
    print('\n2. 🔐 TESTING SESSION MANAGEMENT:');
    final sessionStatus = getSessionStatus();
    print('   Session Valid: ${sessionStatus['isValid']}');
    print('   Session Quality: ${sessionStatus['quality']}');
    print('   Has CSRF Token: ${sessionStatus['hasCSRFToken']}');
    
    // Test enhanced extraction
    print('\n3. 🔍 TESTING ENHANCED EXTRACTION:');
    try {
      final service = InstagramService();
      print('   Testing with URL: $testUrl');
      final result = await service.getPostData(testUrl);
      print('   ✅ SUCCESS: Extracted video URL');
      print('   Video URL: ${result.videoUrl?.substring(0, math.min(100, result.videoUrl!.length))}...');
    } catch (e) {
      print('   ❌ FAILED: $e');
    }
    
    print('\n' + '=' * 70);
  }
}
