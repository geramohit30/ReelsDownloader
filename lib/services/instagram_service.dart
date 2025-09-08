import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/instagram_types.dart';
import 'instagram_utils.dart';

class InstagramService {
  static final math.Random _random = math.Random();
  
  // Professional user-agent rotation
  static final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];
  
  Future<InstagramPostData> getPostDataOptimized(String postUrl) async {
    print('\n🚀 DOWNLOADING REEL: $postUrl');
    
    try {
      final videoUrl = await _resolveDirectVideoUrl(postUrl);
      final shortcode = InstagramUtils.extractShortcodeFromUrl(postUrl);

      return InstagramPostData(
        videoUrl: videoUrl.toString(),
        isVideo: true,
        shortcode: shortcode,
      );
    } catch (e) {
      throw Exception('Failed to download reel: ${e.toString()}');
    }
  }

  Future<InstagramPostData> getStoryData(String storyUrl) async {
    print('\n🔄 SIMPLE STORY DOWNLOAD: $storyUrl');
    print('📱 Just like opening a page and pasting URL');
    
    try {
      return await _simpleStoryDownload(storyUrl);
    } catch (e) {
      print('❌ Simple story download failed: $e');
      throw Exception('Failed to download story: ${e.toString()}');
    }
  }
  
  Future<InstagramPostData> _simpleStoryDownload(String storyUrl) async {
    // Just try the working services one by one
    final services = [
      'https://www.storysaver.net/download-instagram-videos/',
      'https://igram.world/story-saver',
      'https://snapinsta.app/instagram-story-downloader',
    ];
    
    for (final serviceUrl in services) {
      try {
        print('🎯 Trying: $serviceUrl');
        
        // Use the detailed method for each service
        final result = await _tryServiceDownload(serviceUrl, storyUrl);
        if (result != null) {
          print('✅ Found download link!');
          return result;
        }
      } catch (e) {
        print('⚠️ $serviceUrl failed: $e');
        continue;
      }
    }
    
    throw Exception('All services failed');
  }
  
  String? _findDownloadLink(String html) {
    // Look for obvious download links
    final patterns = [
      RegExp(r'(https://[^"\s]*(?:instagram|fbcdn)[^"\s]*\.(?:mp4|jpg)[^"\s]*)'),
      RegExp(r'href=["\x27](https://[^"\x27]*\.(?:mp4|jpg))["\x27]'),
      RegExp(r'"download_url"\s*:\s*"(https://[^"]*\.(?:mp4|jpg))"'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1)!;
        if (url.length > 50 && !url.contains('favicon')) {
          return url;
        }
      }
    }
    return null;
  }
  
  /// Simple and direct story download - just like a human would do it
  Future<InstagramPostData> _downloadStoryAdvancedBackground(String storyUrl) async {
    print('🚀 Simple story download approach...');
    
    // Just try the services that work, in order
    final services = [
      'https://www.storysaver.net/download-instagram-videos/',
      'https://igram.world/story-saver',
      'https://snapinsta.app/instagram-story-downloader',
    ];
    
    for (final serviceUrl in services) {
      try {
        print('🎯 Trying service: $serviceUrl');
        final result = await _tryServiceDownload(serviceUrl, storyUrl);
        if (result != null) {
          print('✅ Success with $serviceUrl');
          return result;
        }
      } catch (e) {
        print('⚠️ Failed $serviceUrl: $e');
        continue;
      }
    }
    
    throw Exception('All simple story services failed');
  }
  
  /// Simple story download - load page, submit form, get download link
  Future<InstagramPostData?> _tryServiceDownload(String serviceUrl, String storyUrl) async {
    print('📱 Simple download from: $serviceUrl');
    
    // Step 1: Load the page
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    
    final pageResponse = await http.get(Uri.parse(serviceUrl), headers: headers)
        .timeout(Duration(seconds: 20));
    
    if (pageResponse.statusCode != 200) {
      throw Exception('Failed to load page: ${pageResponse.statusCode}');
    }
    
    final pageHtml = _safeDecodeResponse(pageResponse);
    print('✅ Page loaded (${pageHtml.length} chars)');
    
    // Step 2: Submit the form (POST to same page or action URL)
    final formData = {'url': storyUrl, 'instagram_url': storyUrl};
    
    try {
      // Try POST to same page first
      final postResponse = await http.post(
        Uri.parse(serviceUrl),
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': serviceUrl,
        },
        body: formData.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&'),
      ).timeout(Duration(seconds: 25));
      
      if (postResponse.statusCode == 200) {
        final responseHtml = _safeDecodeResponse(postResponse);
        print('✅ Form submitted (${responseHtml.length} chars)');
        
        // Step 3: Extract download link from response
        final mediaUrl = _extractSimpleMediaUrl(responseHtml);
        if (mediaUrl != null) {
          return InstagramPostData(
            videoUrl: mediaUrl,
            displayUrl: null,
            isVideo: mediaUrl.contains('.mp4'),
          );
        }
      }
    } catch (e) {
      print('⚠️ POST failed: $e');
    }
    
    // Step 4: Try GET with parameters as fallback
    try {
      final getUrl = '$serviceUrl?url=${Uri.encodeComponent(storyUrl)}';
      final getResponse = await http.get(Uri.parse(getUrl), headers: headers)
          .timeout(Duration(seconds: 20));
      
      if (getResponse.statusCode == 200) {
        final responseHtml = _safeDecodeResponse(getResponse);
        print('✅ GET request done (${responseHtml.length} chars)');
        
        final mediaUrl = _extractSimpleMediaUrl(responseHtml);
        if (mediaUrl != null) {
          return InstagramPostData(
            videoUrl: mediaUrl,
            displayUrl: null,
            isVideo: mediaUrl.contains('.mp4'),
          );
        }
      }
    } catch (e) {
      print('⚠️ GET failed: $e');
    }
    
    return null;
  }
  
  /// Simple media URL extraction - look for obvious download links
  String? _extractSimpleMediaUrl(String html) {
    // Look for direct Instagram CDN URLs first
    final patterns = [
      // Instagram CDN URLs
      RegExp(r'(https://[^"\s]*(?:instagram|fbcdn|cdninstagram)[^"\s]*\.(?:mp4|jpg|jpeg|png)[^"\s]*)'),
      // Download URLs in href attributes  
      RegExp(r'href=["\x27](https://[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27]*)["\x27]'),
      // URLs in JavaScript variables
      RegExp(r'(?:downloadUrl|mediaUrl|videoUrl)\s*[:=]\s*["\x27](https://[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27]*)["\x27]'),
      // JSON download_url fields
      RegExp(r'"download_url"\s*:\s*"(https://[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*)"'),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final url = match.group(1)!;
        
        // Simple validation - exclude obvious non-media URLs
        if (url.length > 50 && 
            !url.toLowerCase().contains('favicon') && 
            !url.toLowerCase().contains('icon') &&
            !url.toLowerCase().contains('logo')) {
          print('✅ Found media URL: ${url.substring(0, math.min(80, url.length))}...');
          return url;
        }
      }
    }
    
    print('⚠️ No media URL found in HTML');
    return null;
  }
  
  /// Process individual service with advanced automation
  Future<InstagramPostData?> _processServiceAdvanced(Map<String, dynamic> service, String storyUrl) async {
    final serviceName = service['name'] as String;
    final baseUrl = service['baseUrl'] as String;
    final endpoint = service['endpoint'] as String;
    final method = service['method'] as String;
    final fullUrl = '$baseUrl$endpoint';
    
    switch (method) {
      case 'advanced_form':
        return await _advancedFormSubmission(fullUrl, storyUrl, serviceName);
      case 'form_submit':
        return await _intelligentFormSubmission(fullUrl, storyUrl, serviceName);
      case 'advanced_automation':
        return await _advancedBrowserAutomation(fullUrl, storyUrl, serviceName);
      case 'api_simulation':
        return await _apiSimulationApproach(fullUrl, storyUrl, serviceName);
      default:
        return await _genericBackgroundApproach(fullUrl, storyUrl, serviceName);
    }
  }
  
  /// Advanced form submission with sophisticated session handling
  Future<InstagramPostData?> _advancedFormSubmission(String url, String storyUrl, String serviceName) async {
    print('📝 $serviceName: Advanced form submission');
    
    try {
      // Step 1: Initial page load with realistic browser simulation
      final sessionHeaders = _createAdvancedBrowserHeaders(url);
      
      final pageResponse = await http.get(
        Uri.parse(url),
        headers: sessionHeaders,
      ).timeout(Duration(seconds: 25));
      
      if (pageResponse.statusCode != 200) {
        throw Exception('Failed to load $serviceName page: ${pageResponse.statusCode}');
      }
      
      final pageHtml = _safeDecodeResponse(pageResponse);
      print('✅ $serviceName page loaded (${pageHtml.length} chars)');
      
      // Step 2: Advanced form analysis and token extraction
      final formContext = _analyzeFormAdvanced(pageHtml);
      
      // Step 3: Simulate realistic user interaction timing
      await Future.delayed(Duration(milliseconds: 1500 + _random.nextInt(2000)));
      
      // Step 4: Multiple submission strategies
      final submissionStrategies = [
        () => _tryAjaxSubmission(url, storyUrl, formContext, sessionHeaders),
        () => _tryPostSubmission(url, storyUrl, formContext, sessionHeaders),
        () => _tryGetSubmission(url, storyUrl, formContext, sessionHeaders),
        () => _tryApiEndpointSubmission(url, storyUrl, formContext, sessionHeaders),
      ];
      
      for (final strategy in submissionStrategies) {
        try {
          final result = await strategy();
          if (result != null) return result;
        } catch (e) {
          print('⚠️ Strategy failed: $e');
          continue;
        }
      }
      
    } catch (e) {
      print('❌ $serviceName advanced form submission failed: $e');
    }
    
    return null;
  }
  
  /// Intelligent form submission with behavior mimicking
  Future<InstagramPostData?> _intelligentFormSubmission(String url, String storyUrl, String serviceName) async {
    print('🤖 $serviceName: Intelligent form submission');
    
    try {
      final headers = _createIntelligentHeaders(url);
      
      // Load page and extract form information
      final pageResponse = await http.get(Uri.parse(url), headers: headers);
      if (pageResponse.statusCode != 200) return null;
      
      final pageHtml = _safeDecodeResponse(pageResponse);
      final formData = _extractFormDataIntelligent(pageHtml);
      
      // Add the Instagram URL
      formData['url'] = storyUrl;
      formData['instagram_url'] = storyUrl;
      formData['link'] = storyUrl;
      
      // Simulate realistic form filling delay
      await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));
      
      // Try different submission approaches
      final endpoints = _discoverSubmissionEndpoints(url, pageHtml);
      
      for (final endpoint in endpoints) {
        try {
          final result = await _submitFormIntelligently(endpoint, formData, headers);
          if (result != null) return result;
        } catch (e) {
          continue;
        }
      }
      
    } catch (e) {
      print('❌ $serviceName intelligent submission failed: $e');
    }
    
    return null;
  }
  
  Future<InstagramPostData> _downloadStoryDirect(String storyUrl) async {
    print('📝 Trying direct API approach...');
    
    // Try multiple API endpoints with different approaches
    final apiEndpoints = [
      {
        'url': 'https://api.savetoinsta.com/api/story',
        'method': 'POST',
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        'body': {'url': storyUrl}
      },
      {
        'url': 'https://savetoinsta.com/api/story',
        'method': 'POST',
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        'body': {'url': storyUrl}
      },
      {
        'url': 'https://api-wh.igram.world/api/v1/instagram/story',
        'method': 'POST',
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Origin': 'https://igram.world',
          'Referer': 'https://igram.world/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        'body': {'url': storyUrl}
      }
    ];
    
    for (final endpoint in apiEndpoints) {
      try {
        print('📝 Trying API: ${endpoint['url']}');
        
        final response = await http.post(
          Uri.parse(endpoint['url'] as String),
          headers: endpoint['headers'] as Map<String, String>,
          body: json.encode(endpoint['body']),
        ).timeout(Duration(seconds: 30));
        
        print('📊 API Response Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          return _parseStoryApiResponse(response.body, storyUrl);
        } else {
          print('❌ API failed with status: ${response.statusCode}');
        }
        
      } catch (e) {
        print('❌ API ${endpoint['url']} failed: $e');
        continue;
      }
    }
    
    throw Exception('All direct API endpoints failed');
  }
  
  Future<InstagramPostData> _downloadStoryWebScraping(String storyUrl) async {
    print('📝 Professional multi-service approach...');

    // Professional multi-service architecture with fallback
    final services = [
      {
        'name': 'igram.world',
        'pageUrl': 'https://igram.world/story-saver',
        'priority': 1,
        'type': 'form_automation'
      },
      {
        'name': 'snapinsta.app',
        'pageUrl': 'https://snapinsta.app/instagram-story-downloader',
        'priority': 2,
        'type': 'generic_service'
      },
      {
        'name': 'savestory.online',
        'pageUrl': 'https://savestory.online',
        'priority': 3,
        'type': 'generic_service'
      },
      {
        'name': 'storysaver.app',
        'pageUrl': 'https://storysaver.app',
        'priority': 4,
        'type': 'generic_service'
      }
    ];
    
    // Try services in priority order with professional headers
    for (final service in services) {
      try {
        print('🎯 Trying ${service['name']} (Priority: ${service['priority']})');
        
        final headers = _createAdvancedBrowserHeaders(service['pageUrl'] as String);
        
        if (service['type'] == 'form_automation') {
          final result = await _tryIgramWorldApproach(service, '', storyUrl);
          if (result != null) return result;
        } else {
          final result = await _genericBackgroundApproach('${service['baseUrl']}${service['endpoint']}', storyUrl, service['name'] as String);
          if (result != null) return result;
        }
        
        // Professional delay between services
        await Future.delayed(Duration(milliseconds: 800));
        
      } catch (e) {
        print('❌ Service ${service['name']} failed: $e');
        continue;
      }
    }
    
    throw Exception('All professional story download services failed');
  }
  
  /// Advanced browser automation with session persistence
  Future<InstagramPostData?> _advancedBrowserAutomation(String url, String storyUrl, String serviceName) async {
    print('🌐 $serviceName: Advanced browser automation');
    
    try {
      // Create persistent session with cookies
      final sessionHeaders = _createPersistentSessionHeaders(url);
      
      // Multi-step automation process
      final automationSteps = [
        () => _loadPageWithSession(url, sessionHeaders),
        (pageHtml) => _extractAndProcessFormElements(pageHtml, storyUrl),
        (formData) => _simulateUserInteraction(url, formData, sessionHeaders),
        (responseData) => _extractMediaUrlsAdvanced(responseData),
      ];
      
      dynamic stepResult;
      for (final step in automationSteps) {
        stepResult = await step(stepResult);
        if (stepResult == null) break;
      }
      
      if (stepResult is InstagramPostData) {
        return stepResult;
      }
      
    } catch (e) {
      print('❌ $serviceName automation failed: $e');
    }
    
    return null;
  }
  
  /// API simulation approach
  Future<InstagramPostData?> _apiSimulationApproach(String url, String storyUrl, String serviceName) async {
    print('🚀 $serviceName: API simulation approach');
    
    try {
      final baseUrl = Uri.parse(url).origin;
      
      // Try common API endpoints
      final apiEndpoints = [
        '$baseUrl/api/download',
        '$baseUrl/api/instagram/story',
        '$baseUrl/api/v1/story',
        '$baseUrl/download',
        '$baseUrl/process',
      ];
      
      for (final endpoint in apiEndpoints) {
        try {
          final result = await _tryApiEndpoint(endpoint, storyUrl);
          if (result != null) return result;
        } catch (e) {
          continue;
        }
      }
      
    } catch (e) {
      print('❌ $serviceName API simulation failed: $e');
    }
    
    return null;
  }
  
  /// Generic background approach for fallback
  Future<InstagramPostData?> _genericBackgroundApproach(String url, String storyUrl, String serviceName) async {
    print('🚀 $serviceName: Generic background approach');
    
    try {
      final headers = _createAdvancedBrowserHeaders(url);
      
      // Simple form submission
      final formData = {'url': storyUrl, 'instagram_url': storyUrl};
      final body = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      ).timeout(Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final responseHtml = _safeDecodeResponse(response);
        return _extractMediaFromResponse(responseHtml, storyUrl);
      }
      
    } catch (e) {
      print('❌ $serviceName generic approach failed: $e');
    }
    
    return null;
  }
  
  // Supporting helper methods
  
  Map<String, String> _createAdvancedBrowserHeaders(String refererUrl) {
    final userAgent = _userAgents[_random.nextInt(_userAgents.length)];
    
    return {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'en-US,en;q=0.9,es;q=0.8,fr;q=0.7,de;q=0.6',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'Cache-Control': 'max-age=0',
      'Referer': refererUrl,
      'sec-ch-ua': '"Chromium";v="120", "Google Chrome";v="120", "Not A(Brand";v="8"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"macOS"',
    };
  }
  
  Map<String, String> _createIntelligentHeaders(String refererUrl) {
    return {
      'User-Agent': _userAgents[_random.nextInt(_userAgents.length)],
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'en-US,en;q=0.9',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Origin': Uri.parse(refererUrl).origin,
      'Referer': refererUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
    };
  }
  
  Map<String, String> _createPersistentSessionHeaders(String refererUrl) {
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
    
    return {
      'User-Agent': _userAgents[_random.nextInt(_userAgents.length)],
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': refererUrl,
      'Connection': 'keep-alive',
      'Cookie': 'session_id=$sessionId; _ga=GA1.1.${_random.nextInt(999999999)}.${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    };
  }
  
  String _safeDecodeResponse(http.Response response) {
    try {
      return response.body;
    } catch (e) {
      return String.fromCharCodes(response.bodyBytes);
    }
  }
  
  Map<String, String> _analyzeFormAdvanced(String html) {
    final formData = <String, String>{};
    
    // Extract CSRF tokens with multiple patterns
    final csrfPatterns = [
      RegExp(r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'<input[^>]*name=["\x27]_token["\x27][^>]*value=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'window\._token\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'csrf_token["\x27]?\s*[:=]\s*["\x27]([^"\x27]+)["\x27]'),
    ];
    
    for (final pattern in csrfPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        formData['_token'] = match.group(1)!;
        formData['csrf_token'] = match.group(1)!;
        break;
      }
    }
    
    // Extract all hidden fields
    final hiddenPattern = RegExp(r'<input[^>]*type=["\x27]hidden["\x27][^>]*name=["\x27]([^"\x27]+)["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]');
    final hiddenMatches = hiddenPattern.allMatches(html);
    for (final match in hiddenMatches) {
      formData[match.group(1)!] = match.group(2) ?? '';
    }
    
    return formData;
  }
  
  Map<String, String> _extractFormDataIntelligent(String html) {
    final formData = _analyzeFormAdvanced(html);
    
    // Look for additional JavaScript-defined variables
    final jsVarPatterns = [
      RegExp(r'window\.formData\s*=\s*\{([^}]+)\}'),
      RegExp(r'var\s+formConfig\s*=\s*\{([^}]+)\}'),
    ];
    
    for (final pattern in jsVarPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        // Simple key-value extraction from JS object
        final jsContent = match.group(1)!;
        final kvPattern = RegExp(r'["\x27]([^"\x27]+)["\x27]\s*:\s*["\x27]([^"\x27]+)["\x27]');
        final kvMatches = kvPattern.allMatches(jsContent);
        for (final kvMatch in kvMatches) {
          formData[kvMatch.group(1)!] = kvMatch.group(2)!;
        }
      }
    }
    
    return formData;
  }
  
  List<String> _discoverSubmissionEndpoints(String baseUrl, String html) {
    final endpoints = <String>{};
    
    // Extract form action URLs
    final formActionPattern = RegExp(r'<form[^>]*action=["\x27]([^"\x27]+)["\x27]');
    final actionMatches = formActionPattern.allMatches(html);
    for (final match in actionMatches) {
      var action = match.group(1)!;
      if (action.startsWith('/')) {
        action = '${Uri.parse(baseUrl).origin}$action';
      }
      endpoints.add(action);
    }
    
    // Extract AJAX endpoints from JavaScript
    final ajaxPatterns = [
      RegExp(r'url\s*:\s*["\x27]([^"\x27]+/(?:process|download|submit|api)[^"\x27]*)["\x27]'),
      RegExp(r'\$\.post\(["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'fetch\(["\x27]([^"\x27]+)["\x27]'),
    ];
    
    for (final pattern in ajaxPatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        var endpoint = match.group(1)!;
        if (endpoint.startsWith('/')) {
          endpoint = '${Uri.parse(baseUrl).origin}$endpoint';
        }
        endpoints.add(endpoint);
      }
    }
    
    // Add common fallback endpoints
    final baseUri = Uri.parse(baseUrl);
    endpoints.addAll([
      '${baseUri.origin}/download',
      '${baseUri.origin}/process',
      '${baseUri.origin}/api/download',
      baseUrl, // POST to same page
    ]);
    
    return endpoints.toList();
  }
  
  Future<InstagramPostData?> _submitFormIntelligently(String endpoint, Map<String, String> formData, Map<String, String> headers) async {
    try {
      final formBody = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formBody,
      ).timeout(Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        final responseData = _safeDecodeResponse(response);
        return _extractMediaFromResponse(responseData, formData['url'] ?? '');
      }
      
    } catch (e) {
      // Silent fail for this endpoint
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryAjaxSubmission(String baseUrl, String storyUrl, Map<String, String> formData, Map<String, String> sessionHeaders) async {
    final ajaxHeaders = {
      ...sessionHeaders,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
    };
    
    final ajaxData = {
      ...formData,
      'url': storyUrl,
      'instagram_url': storyUrl,
      'action': 'download',
    };
    
    final endpoints = [
      '${Uri.parse(baseUrl).origin}/ajax/download',
      '${Uri.parse(baseUrl).origin}/api/download',
      '$baseUrl/download',
    ];
    
    for (final endpoint in endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: ajaxHeaders,
          body: ajaxData.entries
              .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
              .join('&'),
        ).timeout(Duration(seconds: 20));
        
        if (response.statusCode == 200) {
          final responseData = _safeDecodeResponse(response);
          
          // Try parsing as JSON first
          try {
            final jsonData = json.decode(responseData);
            if (jsonData is Map) {
              final mediaUrl = jsonData['download_url'] ?? 
                             jsonData['video_url'] ?? 
                             jsonData['media_url'] ?? 
                             jsonData['url'];
              
              if (mediaUrl != null && _isValidMediaUrl(mediaUrl.toString())) {
                return InstagramPostData(
                  videoUrl: mediaUrl.toString(),
                  displayUrl: jsonData['thumbnail'] ?? jsonData['thumb'],
                  isVideo: !mediaUrl.toString().contains('.jpg') && !mediaUrl.toString().contains('.png'),
                );
              }
            }
          } catch (e) {
            // Not JSON, try HTML parsing
            final result = _extractMediaFromResponse(responseData, storyUrl);
            if (result != null) return result;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryPostSubmission(String baseUrl, String storyUrl, Map<String, String> formData, Map<String, String> sessionHeaders) async {
    try {
      final postData = {
        ...formData,
        'url': storyUrl,
        'instagram_url': storyUrl,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          ...sessionHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: postData.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&'),
      ).timeout(Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        final responseData = _safeDecodeResponse(response);
        return _extractMediaFromResponse(responseData, storyUrl);
      }
      
    } catch (e) {
      // Silent fail
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryGetSubmission(String baseUrl, String storyUrl, Map<String, String> formData, Map<String, String> sessionHeaders) async {
    try {
      final queryParams = {
        ...formData,
        'url': storyUrl,
        'instagram_url': storyUrl,
      };
      
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final getUrl = '$baseUrl?$queryString';
      
      final response = await http.get(
        Uri.parse(getUrl),
        headers: sessionHeaders,
      ).timeout(Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        final responseData = _safeDecodeResponse(response);
        return _extractMediaFromResponse(responseData, storyUrl);
      }
      
    } catch (e) {
      // Silent fail
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryApiEndpointSubmission(String baseUrl, String storyUrl, Map<String, String> formData, Map<String, String> sessionHeaders) async {
    final apiEndpoints = [
      '${Uri.parse(baseUrl).origin}/api/v1/instagram/story',
      '${Uri.parse(baseUrl).origin}/api/instagram/download',
      '${Uri.parse(baseUrl).origin}/api/download',
    ];
    
    for (final endpoint in apiEndpoints) {
      try {
        final result = await _tryApiEndpoint(endpoint, storyUrl);
        if (result != null) return result;
      } catch (e) {
        continue;
      }
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryApiEndpoint(String endpoint, String storyUrl) async {
    try {
      final apiHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': _userAgents[_random.nextInt(_userAgents.length)],
      };
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: apiHeaders,
        body: json.encode({'url': storyUrl}),
      ).timeout(Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is Map) {
          final mediaUrl = jsonData['download_url'] ?? 
                         jsonData['video_url'] ?? 
                         jsonData['media_url'] ?? 
                         jsonData['url'];
          
          if (mediaUrl != null && _isValidMediaUrl(mediaUrl.toString())) {
            return InstagramPostData(
              videoUrl: mediaUrl.toString(),
              displayUrl: jsonData['thumbnail'] ?? jsonData['thumb'],
              isVideo: !mediaUrl.toString().contains('.jpg') && !mediaUrl.toString().contains('.png'),
            );
          }
        }
      }
      
    } catch (e) {
      // Silent fail
    }
    
    return null;
  }
  Future<InstagramPostData?> _tryIgramWorldApproach(Map<String, dynamic> service, String pageHtml, String storyUrl) async {
    final serviceName = service['name'] as String;
    final pageUrl = service['pageUrl'] as String;
    final baseUrl = Uri.parse(pageUrl).origin;
    
    print('🔧 Analyzing igram.world approach...');
    
    // Strategy 1: Simple GET approach (most reliable)
    print('📋 Strategy 1: Simple GET requests');
    try {
      final result = await _trySimpleGetApproach(baseUrl, storyUrl);
      if (result != null) return result;
    } catch (e) {
      print('ℹ️ Simple GET approach failed: $e');
    }
    
    // Strategy 2: Browser simulation with form interaction
    print('📋 Strategy 2: Browser simulation with form interaction');
    try {
      final result = await _simulateBrowserInteraction(baseUrl, storyUrl);
      if (result != null) return result;
    } catch (e) {
      print('ℹ️ Browser simulation failed: $e');
    }
    
    // Strategy 3: Hidden API endpoints discovery
    print('📋 Strategy 3: Hidden API endpoints');
    try {
      final result = await _tryHiddenApiEndpoints(baseUrl, storyUrl);
      if (result != null) return result;
    } catch (e) {
      print('ℹ️ Hidden API endpoints failed: $e');
    }
    
    // Strategy 4: Dynamic form submission simulation
    print('📋 Strategy 4: Dynamic form submission');
    try {
      final result = await _simulateFormSubmission(baseUrl, pageHtml, storyUrl);
      if (result != null) return result;
    } catch (e) {
      print('ℹ️ Dynamic form submission failed: $e');
    }
    
    print('❌ All igram.world strategies failed');
    return null;
  }
  
  Future<InstagramPostData?> _trySimpleGetApproach(String baseUrl, String storyUrl) async {
    print('🌍 Trying simple GET approach...');
    
    // First, let's load the page to understand the form structure
    print('📋 Step 1: Loading igram.world story-saver page to analyze form...');
    
    final pageHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };
    
    try {
      final pageResponse = await http.get(
        Uri.parse('$baseUrl/story-saver'),
        headers: pageHeaders,
      ).timeout(Duration(seconds: 30));
      
      if (pageResponse.statusCode == 200) {
        String pageHtml;
        try {
          pageHtml = pageResponse.body;
        } catch (e) {
          pageHtml = String.fromCharCodes(pageResponse.bodyBytes);
        }
        
        print('✅ Page loaded (${pageHtml.length} chars)');
        
        // Step 2: Analyze the form and simulate user interaction
        final formResult = await _simulateIgramFormSubmission(baseUrl, pageHtml, storyUrl);
        if (formResult != null) return formResult;
      }
    } catch (e) {
      print('⚠️ Failed to load page: $e');
    }
    
    // Fallback to direct endpoint attempts
    print('📋 Step 2: Trying direct endpoints as fallback...');
    
    final getEndpoints = [
      '$baseUrl/story-saver?url=${Uri.encodeComponent(storyUrl)}',
      '$baseUrl/download?url=${Uri.encodeComponent(storyUrl)}',
      '$baseUrl/api/download?url=${Uri.encodeComponent(storyUrl)}',
      '$baseUrl/process?url=${Uri.encodeComponent(storyUrl)}',
      '$baseUrl/api/story?url=${Uri.encodeComponent(storyUrl)}',
    ];
    
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/html, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': '$baseUrl/story-saver',
      'DNT': '1',
      'Connection': 'keep-alive',
    };
    
    for (final endpoint in getEndpoints) {
      try {
        print('📋 Trying GET: $endpoint');
        
        final response = await http.get(
          Uri.parse(endpoint),
          headers: headers,
        ).timeout(Duration(seconds: 30));
        
        print('📊 Response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          String responseBody;
          try {
            responseBody = response.body;
          } catch (e) {
            responseBody = String.fromCharCodes(response.bodyBytes);
          }
          
          print('📊 Response length: ${responseBody.length} chars');
          
          if (responseBody.length < 100) {
            print('⚠️ Response too small, skipping');
            continue;
          }
          
          // Try parsing the response
          try {
            final jsonData = json.decode(responseBody);
            if (jsonData is Map) {
              final mediaUrl = jsonData['download_url'] ?? 
                             jsonData['video_url'] ?? 
                             jsonData['media_url'] ?? 
                             jsonData['url'];
              
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                print('✅ Found media URL in JSON: ${mediaUrl.toString().substring(0, math.min(100, mediaUrl.toString().length))}...');
                
                return InstagramPostData(
                  videoUrl: mediaUrl.toString(),
                  displayUrl: jsonData['thumbnail'] ?? jsonData['thumb'],
                  isVideo: !mediaUrl.toString().contains('.jpg') && !mediaUrl.toString().contains('.png'),
                );
              }
            }
          } catch (e) {
            // Try HTML parsing
            try {
              final result = _parseJavaScriptResponse(responseBody);
              if (result != null) return result;
              
              final result2 = _parseStoryFromHtml(responseBody, storyUrl);
              if (result2 != null) return result2;
              
            } catch (e2) {
              print('⚠️ Failed to parse response: $e2');
            }
          }
        }
        
        await Future.delayed(Duration(milliseconds: 800));
        
      } catch (e) {
        print('⚠️ GET request failed: $e');
        continue;
      }
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _simulateIgramFormSubmission(String baseUrl, String pageHtml, String storyUrl) async {
    print('🤖 Simulating igram.world form submission like a real browser...');
    
    // Step 1: Extract form data (CSRF tokens, hidden fields, etc.)
    final formData = _extractIgramFormData(pageHtml);
    print('📋 Extracted ${formData.length} form fields');
    
    // Step 2: Add the story URL (simulating user pasting the link)
    formData['url'] = storyUrl;
    
    // Step 3: Simulate the "Download" button click
    // First, wait a realistic time (simulating user interaction)
    await Future.delayed(Duration(milliseconds: 2000));
    
    // Find the actual form action URL
    final formAction = _extractFormAction(pageHtml) ?? '/story-saver';
    final submitUrl = formAction.startsWith('http') ? formAction : '$baseUrl$formAction';
    
    print('📋 Submitting form to: $submitUrl');
    
    // Headers that mimic a real browser form submission
    final submitHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Origin': baseUrl,
      'Referer': '$baseUrl/story-saver',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-User': '?1',
    };
    
    try {
      // Try POST first (most likely for form submission)
      final formBody = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      print('📋 Sending POST request with form data: ${formData.keys.join(', ')}');
      
      final response = await http.post(
        Uri.parse(submitUrl),
        headers: submitHeaders,
        body: formBody,
      ).timeout(Duration(seconds: 30));
      
      print('📊 Form submission status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        String responseBody;
        try {
          responseBody = response.body;
        } catch (e) {
          responseBody = String.fromCharCodes(response.bodyBytes);
        }
        
        print('📊 Response length: ${responseBody.length} chars');
        
        // The response should contain the download link or redirect to it
        final result = await _parseIgramResponse(responseBody, baseUrl);
        if (result != null) return result;
        
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect (common after form submission)
        final location = response.headers['location'];
        if (location != null) {
          print('🔄 Following form submission redirect: $location');
          
          final redirectUrl = location.startsWith('http') ? location : '$baseUrl$location';
          
          final redirectResponse = await http.get(
            Uri.parse(redirectUrl),
            headers: {
              'User-Agent': submitHeaders['User-Agent']!,
              'Accept': submitHeaders['Accept']!,
              'Referer': '$baseUrl/story-saver',
            },
          );
          
          if (redirectResponse.statusCode == 200) {
            String redirectBody;
            try {
              redirectBody = redirectResponse.body;
            } catch (e) {
              redirectBody = String.fromCharCodes(redirectResponse.bodyBytes);
            }
            
            final result = await _parseIgramResponse(redirectBody, baseUrl);
            if (result != null) return result;
          }
        }
      } else if (response.statusCode == 405) {
        // POST not allowed, try GET with parameters
        print('📋 POST not allowed, trying GET with parameters...');
        
        final getUrl = '$submitUrl?${formData.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
        
        final getResponse = await http.get(
          Uri.parse(getUrl),
          headers: {
            'User-Agent': submitHeaders['User-Agent']!,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Referer': '$baseUrl/story-saver',
          },
        );
        
        if (getResponse.statusCode == 200) {
          String getBody;
          try {
            getBody = getResponse.body;
          } catch (e) {
            getBody = String.fromCharCodes(getResponse.bodyBytes);
          }
          
          final result = await _parseIgramResponse(getBody, baseUrl);
          if (result != null) return result;
        }
      }
      
    } catch (e) {
      print('⚠️ Form submission failed: $e');
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _simulateBrowserInteraction(String baseUrl, String storyUrl) async {
    print('🌍 Simulating browser interaction with igram.world...');
    
    // Step 1: Load the main page to get session cookies and form data
    final pageUrl = '$baseUrl/story-saver';
    
    // Use realistic browser headers WITHOUT Accept-Encoding to avoid GZIP issues
    final browserHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'en-US,en;q=0.9',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Cache-Control': 'max-age=0',
    };
    
    print('📋 Loading igram.world story-saver page...');
    
    try {
      final pageResponse = await http.get(Uri.parse(pageUrl), headers: browserHeaders)
          .timeout(Duration(seconds: 30));
      
      if (pageResponse.statusCode != 200) {
        throw Exception('Failed to load igram.world page: ${pageResponse.statusCode}');
      }
      
      // Handle potential GZIP response
      String responseBody;
      try {
        responseBody = pageResponse.body;
        if (responseBody.isEmpty) {
          throw FormatException('Empty response body');
        }
      } catch (e) {
        print('⚠️ Response decoding issue: $e');
        // Try to get raw response if standard decoding fails
        responseBody = String.fromCharCodes(pageResponse.bodyBytes);
      }
      
      print('✅ Page loaded (${responseBody.length} chars)');
      
      // Step 2: Extract form details and CSRF tokens
      final formData = _extractIgramFormData(responseBody);
      
      // Step 3: Simulate JavaScript form population
      formData['url'] = storyUrl; // Fill the URL input
      
      // Step 4: Wait a bit to simulate human interaction
      await Future.delayed(Duration(milliseconds: 1500));
      
      // Step 5: Submit form with AJAX headers (like JavaScript would)
      final ajaxHeaders = {
        'User-Agent': browserHeaders['User-Agent']!,
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'en-US,en;q=0.9',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': baseUrl,
        'Referer': pageUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      };
      
      // Try multiple potential endpoints that JavaScript might use
      final endpoints = [
        '/ajax/story',
        '/api/story',
        '/process',
        '/submit',
        '/download',
        '/story-saver', // POST to same page
      ];
      
      for (final endpoint in endpoints) {
        final submitUrl = '$baseUrl$endpoint';
        print('📋 Trying AJAX submission to: $submitUrl');
        
        try {
          final formBody = formData.entries
              .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
              .join('&');
          
          final submitResponse = await http.post(
            Uri.parse(submitUrl),
            headers: ajaxHeaders,
            body: formBody,
          ).timeout(Duration(seconds: 30));
          
          print('📊 Response status: ${submitResponse.statusCode}');
          
          if (submitResponse.statusCode == 200) {
            // Handle potential GZIP response
            String submitResponseBody;
            try {
              submitResponseBody = submitResponse.body;
            } catch (e) {
              submitResponseBody = String.fromCharCodes(submitResponse.bodyBytes);
            }
            
            // Try to parse as JSON first (AJAX response)
            try {
              final jsonData = json.decode(submitResponseBody);
              if (jsonData is Map) {
                // Look for media URL in JSON response
                final mediaUrl = jsonData['download_url'] ?? 
                               jsonData['video_url'] ?? 
                               jsonData['media_url'] ?? 
                               jsonData['url'];
                
                if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                  print('✅ Found media URL in JSON: ${mediaUrl.toString().substring(0, math.min(100, mediaUrl.toString().length))}...');
                  
                  return InstagramPostData(
                    videoUrl: mediaUrl.toString(),
                    displayUrl: jsonData['thumbnail'] ?? jsonData['thumb'],
                    isVideo: !mediaUrl.toString().contains('.jpg') && !mediaUrl.toString().contains('.png'),
                  );
                }
              }
            } catch (e) {
              // Not JSON, try parsing as HTML
              print('📋 Response is HTML, parsing...');
              
              // Look for JavaScript variables or new content in the HTML
              final result = _parseJavaScriptResponse(submitResponseBody);
              if (result != null) return result;
            }
          } else if (submitResponse.statusCode == 302) {
            // Handle redirect
            final location = submitResponse.headers['location'];
            if (location != null) {
              print('🔄 Following redirect: $location');
              final redirectResponse = await http.get(
                Uri.parse(location.startsWith('http') ? location : '$baseUrl$location'),
                headers: browserHeaders,
              );
              
              if (redirectResponse.statusCode == 200) {
                String redirectBody;
                try {
                  redirectBody = redirectResponse.body;
                } catch (e) {
                  redirectBody = String.fromCharCodes(redirectResponse.bodyBytes);
                }
                final result = _parseJavaScriptResponse(redirectBody);
                if (result != null) return result;
              }
            }
          }
          
          // Small delay between requests
          await Future.delayed(Duration(milliseconds: 500));
          
        } catch (e) {
          print('⚠️ Request to $submitUrl failed: $e');
          continue;
        }
      }
      
    } catch (e) {
      print('⚠️ Browser simulation failed: $e');
      throw e;
    }
    
    return null;
  }
  
  Map<String, String> _extractIgramFormData(String html) {
    final formData = <String, String>{};
    
    // Extract CSRF token
    final csrfPatterns = [
      RegExp(r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'<input[^>]*name=["\x27]_token["\x27][^>]*value=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'window\._token\s*=\s*["\x27]([^"\x27]+)["\x27]'),
    ];
    
    for (final pattern in csrfPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        formData['_token'] = match.group(1)!;
        print('🔐 Found CSRF token');
        break;
      }
    }
    
    // Extract all hidden input fields
    final hiddenPattern = RegExp(r'<input[^>]*type=["\x27]hidden["\x27][^>]*name=["\x27]([^"\x27]+)["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]');
    final hiddenMatches = hiddenPattern.allMatches(html);
    for (final match in hiddenMatches) {
      final name = match.group(1)!;
      final value = match.group(2) ?? '';
      formData[name] = value;
      print('📋 Found hidden field: $name = $value');
    }
    
    // Look for form method and action
    final methodPattern = RegExp(r'<form[^>]*method=["\x27]([^"\x27]+)["\x27]');
    final methodMatch = methodPattern.firstMatch(html);
    if (methodMatch != null) {
      formData['_method'] = methodMatch.group(1)!;
      print('📋 Found form method: ${methodMatch.group(1)}');
    }
    
    return formData;
  }
  
  String? _extractFormAction(String html) {
    final actionPattern = RegExp(r'<form[^>]*action=["\x27]([^"\x27]+)["\x27]');
    final actionMatch = actionPattern.firstMatch(html);
    if (actionMatch != null) {
      final action = actionMatch.group(1)!;
      print('📋 Found form action: $action');
      return action;
    }
    return null;
  }
  
  Future<InstagramPostData?> _parseIgramResponse(String html, String baseUrl) async {
    print('🔍 Parsing igram.world response...');
    
    // Strategy 1: Look for direct download links
    final downloadLinkPatterns = [
      RegExp(r'href=["\x27]([^"\x27]*(?:instagram|fbcdn|cdninstagram)[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27]*)["\x27][^>]*(?:download|target)'),
      RegExp(r'<a[^>]*download[^>]*href=["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*)["\x27]'),
      RegExp(r'data-download-url=["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*)["\x27]'),
    ];
    
    for (final pattern in downloadLinkPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        var url = match.group(1)!;
        if (!url.contains('favicon') && !url.contains('icon') && url.length > 30) {
          
          // Make URL absolute if needed
          if (url.startsWith('/')) {
            url = '$baseUrl$url';
          }
          
          print('✅ Found download link: ${url.substring(0, math.min(100, url.length))}...');
          
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Strategy 2: Look for JavaScript variables with media URLs
    final jsMediaPatterns = [
      RegExp(r'var\s+mediaUrl\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'window\.mediaUrl\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'downloadUrl\s*[:"]\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'"url"\s*:\s*"([^"]+\.(?:mp4|jpg|jpeg|png)[^"]*)")'),
      RegExp(r'"download_url"\s*:\s*"([^"]+\.(?:mp4|jpg|jpeg|png)[^"]*)")'),
    ];
    
    for (final pattern in jsMediaPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        var url = match.group(1)!;
        if (!url.contains('favicon') && !url.contains('icon') && url.length > 30) {
          
          if (url.startsWith('/')) {
            url = '$baseUrl$url';
          }
          
          print('✅ Found JS media URL: ${url.substring(0, math.min(100, url.length))}...');
          
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Strategy 3: Look for JSON data embedded in scripts
    final scriptPattern = RegExp(r'<script[^>]*>([\s\S]*?)</script>');
    final scriptMatches = scriptPattern.allMatches(html);
    
    for (final scriptMatch in scriptMatches) {
      final scriptContent = scriptMatch.group(1) ?? '';
      
      // Try to find JSON objects with media URLs
      try {
        final jsonPattern = RegExp(r'\{[^}]*(?:download_url|video_url|media_url|url)[^}]*\}');
        final jsonMatches = jsonPattern.allMatches(scriptContent);
        
        for (final jsonMatch in jsonMatches) {
          try {
            final jsonStr = jsonMatch.group(0)!;
            final jsonData = json.decode(jsonStr);
            
            if (jsonData is Map) {
              final mediaUrl = jsonData['download_url'] ?? 
                             jsonData['video_url'] ?? 
                             jsonData['media_url'] ?? 
                             jsonData['url'];
              
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                var url = mediaUrl.toString();
                if (!url.contains('favicon') && !url.contains('icon') && url.length > 30) {
                  
                  if (url.startsWith('/')) {
                    url = '$baseUrl$url';
                  }
                  
                  print('✅ Found JSON media URL: ${url.substring(0, math.min(100, url.length))}...');
                  
                  return InstagramPostData(
                    videoUrl: url,
                    displayUrl: jsonData['thumbnail'] ?? jsonData['thumb'],
                    isVideo: url.contains('.mp4'),
                  );
                }
              }
            }
          } catch (e) {
            // Continue to next match
          }
        }
      } catch (e) {
        // Continue to next script
      }
    }
    
    // Strategy 4: Look for any Instagram CDN URLs in the HTML
    final cdnPatterns = [
      RegExp(r'"(https://[^"]*instagram[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      RegExp(r'"(https://[^"]*fbcdn[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      RegExp(r'"(https://[^"]*cdninstagram[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
    ];
    
    for (final pattern in cdnPatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        var url = match.group(1)!;
        if (!url.contains('favicon') && !url.contains('icon') && url.length > 50) {
          print('✅ Found CDN URL: ${url.substring(0, math.min(100, url.length))}...');
          
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Strategy 5: Debug - show what we found
    print('🔍 DEBUG: Response contains ${html.length} characters');
    
    // Look for any media files mentioned
    final allMediaPattern = RegExp(r'(?:mp4|jpg|jpeg|png)');
    final mediaMatches = allMediaPattern.allMatches(html);
    print('🔍 Found ${mediaMatches.length} media file references');
    
    // Show a sample of the response for debugging
    final sample = html.substring(0, math.min(800, html.length));
    print('📄 Response sample: $sample');
    
    return null;
  }
  
  InstagramPostData? _parseJavaScriptResponse(String html) {
    print('📋 Parsing JavaScript response...');
    
    // Look for JavaScript variables containing media URLs
    final jsPatterns = [
      RegExp(r'var\s+downloadUrl\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'window\.downloadUrl\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'data-download-url=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'download_url["\x27]?\s*:\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'"video_url"\s*:\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"image_url"\s*:\s*"([^"]+\.(?:jpg|jpeg|png)[^"]*)"'),
      RegExp(r'href=["\x27]([^"\x27]*(?:instagram|fbcdn)[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27"]*)["\x27]'),
    ];
    
    for (final pattern in jsPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1)!;
        if (!url.contains('favicon') && !url.contains('icon') && url.length > 30) {
          print('✅ Found media URL in JavaScript: ${url.substring(0, math.min(100, url.length))}...');
          
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Look for dynamically loaded content containers
    final containerPattern = RegExp(r'<div[^>]*class=["\x27][^"\x27]*download[^"\x27]*["\x27][^>]*>([^<]+)</div>');
    final containerMatch = containerPattern.firstMatch(html);
    if (containerMatch != null) {
      print('📋 Found download container: ${containerMatch.group(1)}');
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _tryHiddenApiEndpoints(String baseUrl, String storyUrl) async {
    // Common hidden API patterns found in real websites
    final hiddenApis = [
      '$baseUrl/api/instagram/story',
      '$baseUrl/api/story/download',
      '$baseUrl/api/v1/story/process',
      '$baseUrl/story/api',
      '$baseUrl/ajax/story',
      '$baseUrl/api/download',
      '$baseUrl/api/process',
    ];
    
    for (final apiUrl in hiddenApis) {
      try {
        print('📝 Trying hidden API: $apiUrl');
        
        // Try GET first (safer)
        final getResponse = await http.get(
          Uri.parse('$apiUrl?url=${Uri.encodeComponent(storyUrl)}'),
          headers: {
            'Accept': 'application/json',
            'Referer': '$baseUrl/story-saver',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ).timeout(Duration(seconds: 15));
        
        if (getResponse.statusCode == 200) {
          try {
            return _parseStoryWebResponse(getResponse.body, storyUrl);
          } catch (e) {
            print('⚠️ Failed to parse hidden API response: $e');
          }
        }
      } catch (e) {
        // Silently continue to next API
        continue;
      }
    }
    
    return null;
  }
  
  Future<InstagramPostData?> _simulateFormSubmission(String baseUrl, String pageHtml, String storyUrl) async {
    // Extract potential form submission endpoints from the HTML
    final formPatterns = [
      RegExp(r'<form[^>]*action=["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'action\s*:\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'url\s*:\s*["\x27]([^"\x27]+/(?:process|submit|download)[^"\x27]*)["\x27]'),
    ];
    
    final endpoints = <String>{};
    for (final pattern in formPatterns) {
      final matches = pattern.allMatches(pageHtml);
      for (final match in matches) {
        var endpoint = match.group(1)!;
        if (endpoint.startsWith('/')) {
          endpoint = '$baseUrl$endpoint';
        }
        endpoints.add(endpoint);
      }
    }
    
    if (endpoints.isEmpty) {
      endpoints.add('$baseUrl/story-saver'); // Default fallback
    }
    
    for (final endpoint in endpoints) {
      try {
        print('📋 Trying form submission to: $endpoint');
        
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': baseUrl,
            'Referer': '$baseUrl/story-saver',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          body: 'url=${Uri.encodeComponent(storyUrl)}',
        ).timeout(Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          // Handle potential GZIP response
          String responseBody;
          try {
            responseBody = response.body;
          } catch (e) {
            responseBody = String.fromCharCodes(response.bodyBytes);
          }
          
          try {
            return _parseStoryWebResponse(responseBody, storyUrl);
          } catch (e) {
            try {
              return _parseJavaScriptResponse(responseBody);
            } catch (e2) {
              print('⚠️ Failed to parse form response: $e2');
            }
          }
        }
        
      } catch (e) {
        print('⚠️ Form submission to $endpoint failed: $e');
        continue;
      }
    }
    
    return null;
  }
  
  /// Submit the story form with proper form data
  Future<InstagramPostData?> _submitStoryForm(Map<String, dynamic> service, String pageHtml, String storyUrl, Map<String, String> formData) async {
    final serviceName = service['name'] as String;
    final pageUrl = service['pageUrl'] as String;
    final baseUrl = Uri.parse(pageUrl).origin;
    
    // Build comprehensive list of potential submit URLs based on extracted data and common patterns
    final submitUrls = <String>[];
    
    // Add extracted URLs first (highest priority)
    if (formData.containsKey('action_url')) {
      var actionUrl = formData['action_url']!;
      if (actionUrl.startsWith('/')) {
        actionUrl = '$baseUrl$actionUrl';
      }
      submitUrls.add(actionUrl);
    }
    
    if (formData.containsKey('js_endpoint')) {
      var jsEndpoint = formData['js_endpoint']!;
      if (jsEndpoint.startsWith('/')) {
        jsEndpoint = '$baseUrl$jsEndpoint';
      }
      submitUrls.add(jsEndpoint);
    }
    
    if (formData.containsKey('potential_endpoint')) {
      var endpoint = formData['potential_endpoint']!;
      if (endpoint.startsWith('/')) {
        endpoint = '$baseUrl$endpoint';
      }
      submitUrls.add(endpoint);
    }
    
    // Add common patterns for igram.world specifically
    if (serviceName == 'igram.world') {
      submitUrls.addAll([
        '$baseUrl/story-saver', // Try POST to the same page
        '$baseUrl/process', // Common processing endpoint
        '$baseUrl/api/v1/story', // API endpoint
        '$baseUrl/download', // Generic download endpoint
      ]);
    }
    
    // Add generic fallback URLs
    submitUrls.addAll([
      '$baseUrl/download',
      '$baseUrl/api/download',
      '$baseUrl/story-download',
      '$baseUrl/api/story',
      '$pageUrl', // Try POST to the same page
    ]);
    
    // Remove duplicates while preserving order
    final uniqueSubmitUrls = <String>[];
    for (final url in submitUrls) {
      if (!uniqueSubmitUrls.contains(url)) {
        uniqueSubmitUrls.add(url);
      }
    }
    
    for (final submitUrl in uniqueSubmitUrls) {
      try {
        print('📝 Trying submit URL: $submitUrl');
        
        // Prepare form data with intelligent field naming
        final formPayload = <String, String>{};
        
        // Use the extracted input field name if available, otherwise try common names
        final urlFieldName = formData['input_name'] ?? 'url';
        formPayload[urlFieldName] = storyUrl;
        
        // Add common alternative field names
        formPayload['url'] = storyUrl;
        formPayload['link'] = storyUrl;
        formPayload['instagram_url'] = storyUrl;
        formPayload['story_url'] = storyUrl;
        formPayload['instagram_link'] = storyUrl;
        
        // Add all extracted form data (CSRF tokens, hidden fields, etc.)
        for (final entry in formData.entries) {
          if (!['action_url', 'js_endpoint', 'potential_endpoint', 'input_name'].contains(entry.key)) {
            formPayload[entry.key] = entry.value;
          }
        }
        
        print('📝 Form payload: ${formPayload.keys.join(', ')} (${formPayload.length} fields)');
        
        // Try different request formats with enhanced headers
        final requestFormats = [
          {
            'headers': {
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'en-US,en;q=0.9',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Origin': baseUrl,
              'Referer': pageUrl,
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'X-Requested-With': 'XMLHttpRequest',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
            'body': formPayload.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
            'description': 'AJAX form submission'
          },
          {
            'headers': {
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Origin': baseUrl,
              'Referer': pageUrl,
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Cache-Control': 'no-cache',
              'Upgrade-Insecure-Requests': '1',
            },
            'body': formPayload.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
            'description': 'Standard form submission'
          },
          {
            'headers': {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Origin': baseUrl,
              'Referer': pageUrl,
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            'body': json.encode(formPayload),
            'description': 'JSON API call'
          },
        ];
        
        for (final format in requestFormats) {
          try {
            print('📝 Trying ${format['description']} for $submitUrl');
            
            final submitResponse = await http.post(
              Uri.parse(submitUrl),
              headers: format['headers'] as Map<String, String>,
              body: format['body'] as String,
            ).timeout(Duration(seconds: 30));
            
            print('📊 Submit response status: ${submitResponse.statusCode}');
            
            print('📊 Response length: ${submitResponse.body.length} chars');
            print('📊 Response headers: ${submitResponse.headers}');
            
            if (submitResponse.statusCode == 200) {
              try {
                return _parseStoryWebResponse(submitResponse.body, storyUrl);
              } catch (e) {
                print('⚠️ Failed to parse JSON response: $e');
                // Try parsing as HTML
                try {
                  return _parseStoryFromHtml(submitResponse.body, storyUrl);
                } catch (e2) {
                  print('⚠️ Failed to parse HTML response: $e2');
                  // Log first 500 chars of response for debugging
                  final sample = submitResponse.body.substring(0, math.min(500, submitResponse.body.length));
                  print('📄 Response sample: $sample');
                }
              }
            } else if (submitResponse.statusCode == 302 || submitResponse.statusCode == 301) {
              // Handle redirects
              final location = submitResponse.headers['location'];
              if (location != null) {
                print('🔄 Following redirect to: $location');
                try {
                  final redirectUrl = location.startsWith('http') ? location : '$baseUrl$location';
                  final redirectResponse = await http.get(
                    Uri.parse(redirectUrl),
                    headers: {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      'Referer': pageUrl,
                      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    },
                  ).timeout(Duration(seconds: 30));
                  
                  if (redirectResponse.statusCode == 200) {
                    try {
                      return _parseStoryWebResponse(redirectResponse.body, storyUrl);
                    } catch (e) {
                      return _parseStoryFromHtml(redirectResponse.body, storyUrl);
                    }
                  }
                } catch (e) {
                  print('⚠️ Redirect follow failed: $e');
                }
              }
            } else {
              print('❌ Submit failed with status: ${submitResponse.statusCode}');
              if (submitResponse.body.isNotEmpty) {
                final sample = submitResponse.body.substring(0, math.min(200, submitResponse.body.length));
                print('📄 Error response: $sample');
              }
            }
            
          } catch (e) {
            print('⚠️ Request format ${format['description']} failed: $e');
            // Add a small delay between attempts to avoid rate limiting
            await Future.delayed(Duration(milliseconds: 500));
            continue;
          }
        }
        
        // Add delay between different URLs to avoid rate limiting
        await Future.delayed(Duration(milliseconds: 1000));
        
      } catch (e) {
        print('❌ Submit URL $submitUrl failed: $e');
        continue;
      }
    }
    
    print('❌ All submit attempts failed for $serviceName');
    
    return null;
  }
  
  InstagramPostData _parseStoryApiResponse(String responseBody, String originalUrl) {
    print('🔍 Parsing story API response...');
    
    try {
      final responseData = json.decode(responseBody);
      print('✅ Response is valid JSON');
      
      String? mediaUrl;
      String? thumbnailUrl;
      bool isVideo = true;
      
      if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is Map) {
            mediaUrl = data['download_url'] ?? data['url'] ?? data['video_url'] ?? data['image_url'];
            thumbnailUrl = data['thumbnail'] ?? data['thumb'];
            
            final mediaType = data['type'] ?? data['media_type'] ?? '';
            isVideo = !mediaType.contains('image') && !mediaType.contains('photo');
          } else if (data is List && data.isNotEmpty) {
            final firstItem = data[0];
            mediaUrl = firstItem['download_url'] ?? firstItem['url'] ?? firstItem['video_url'] ?? firstItem['image_url'];
            thumbnailUrl = firstItem['thumbnail'] ?? firstItem['thumb'];
            
            final mediaType = firstItem['type'] ?? firstItem['media_type'] ?? '';
            isVideo = !mediaType.contains('image') && !mediaType.contains('photo');
          }
        } else if (responseData.containsKey('download_url')) {
          mediaUrl = responseData['download_url'];
        } else if (responseData.containsKey('url')) {
          mediaUrl = responseData['url'];
        } else if (responseData.containsKey('video_url')) {
          mediaUrl = responseData['video_url'];
        } else if (responseData.containsKey('image_url')) {
          mediaUrl = responseData['image_url'];
          isVideo = false;
        }
      }
      
      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw Exception('No media URL found in API response');
      }
      
      print('✅ Media URL extracted: ${mediaUrl.substring(0, math.min(100, mediaUrl.length))}...');
      print('📺 Media type: ${isVideo ? "Video" : "Image"}');
      
      return InstagramPostData(
        videoUrl: mediaUrl,
        displayUrl: thumbnailUrl,
        isVideo: isVideo,
      );
      
    } catch (e) {
      throw Exception('Failed to parse API response: $e');
    }
  }

  InstagramPostData _parseStoryWebResponse(String responseBody, String originalUrl) {
    print('🔍 Parsing story response...');
    
    try {
      final responseData = json.decode(responseBody);
      print('✅ Response is valid JSON');
      
      String? mediaUrl;
      String? thumbnailUrl;
      bool isVideo = true;
      
      if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is Map) {
            mediaUrl = data['download_url'] ?? data['url'] ?? data['video_url'] ?? data['image_url'];
            thumbnailUrl = data['thumbnail'] ?? data['thumb'];
            
            final mediaType = data['type'] ?? data['media_type'] ?? '';
            if (mediaType.contains('image') || mediaType.contains('photo')) {
              isVideo = false;
            }
          } else if (data is List && data.isNotEmpty) {
            final firstItem = data[0];
            mediaUrl = firstItem['download_url'] ?? firstItem['url'] ?? firstItem['video_url'] ?? firstItem['image_url'];
            thumbnailUrl = firstItem['thumbnail'] ?? firstItem['thumb'];
            
            final mediaType = firstItem['type'] ?? firstItem['media_type'] ?? '';
            if (mediaType.contains('image') || mediaType.contains('photo')) {
              isVideo = false;
            }
          }
        } else if (responseData.containsKey('download_url')) {
          mediaUrl = responseData['download_url'];
        } else if (responseData.containsKey('url')) {
          mediaUrl = responseData['url'];
        }
      }
      
      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw Exception('No media URL found in web scraping response');
      }
      
      if (mediaUrl.startsWith('/')) {
        mediaUrl = 'https://igram.world$mediaUrl';
      } else if (!mediaUrl.startsWith('http')) {
        mediaUrl = 'https://igram.world/$mediaUrl';
      }
      
      print('✅ Media URL extracted: ${mediaUrl.substring(0, math.min(100, mediaUrl.length))}...');
      print('📺 Media type: ${isVideo ? "Video" : "Image"}');
      
      return InstagramPostData(
        videoUrl: mediaUrl,
        displayUrl: thumbnailUrl,
        isVideo: isVideo,
      );
      
    } catch (e) {
      return _parseStoryFromHtml(responseBody, originalUrl);
    }
  }
  
  InstagramPostData _parseStoryFromHtml(String html, String originalUrl) {
    print('🔍 Parsing story from HTML response...');
    print('🔍 HTML length: ${html.length} characters');
    
    String? mediaUrl;
    bool isVideo = true;
    
    // Strategy 1: Look for Instagram CDN URLs (most reliable)
    final instagramCdnPatterns = [
      RegExp(r'"(https://[^"]*instagram[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      RegExp(r'"(https://[^"]*fbcdn[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      RegExp(r'"(https://[^"]*cdninstagram[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
    ];
    
    for (final pattern in instagramCdnPatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && !url.contains('favicon') && !url.contains('icon') && !url.contains('logo')) {
          mediaUrl = url;
          isVideo = url.contains('mp4');
          print('✅ Found Instagram CDN URL: ${url.substring(0, math.min(100, url.length))}...');
          break;
        }
      }
      if (mediaUrl != null) break;
    }
    
    // Strategy 2: Look for download links or direct media links
    if (mediaUrl == null) {
      final downloadPatterns = [
        RegExp(r'href="([^"]*download[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
        RegExp(r'href="([^"]*media[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
        RegExp(r'data-url="([^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
        RegExp(r'data-src="([^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      ];
      
      for (final pattern in downloadPatterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          final url = match.group(1);
          if (url != null && !url.contains('favicon') && !url.contains('icon')) {
            mediaUrl = url;
            isVideo = url.contains('mp4');
            print('✅ Found download link: ${url.substring(0, math.min(100, url.length))}...');
            break;
          }
        }
      }
    }
    
    // Strategy 3: Look for any media URL but exclude common false positives
    if (mediaUrl == null) {
      final genericPatterns = [
        RegExp(r'src="([^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
        RegExp(r'href="([^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      ];
      
      for (final pattern in genericPatterns) {
        final matches = pattern.allMatches(html);
        for (final match in matches) {
          final url = match.group(1);
          if (url != null && 
              !url.contains('favicon') && 
              !url.contains('icon') && 
              !url.contains('logo') &&
              !url.contains('sprite') &&
              !url.contains('avatar') &&
              url.length > 50) { // Likely a real media URL if it's long enough
            mediaUrl = url;
            isVideo = url.contains('mp4');
            print('✅ Found generic media URL: ${url.substring(0, math.min(100, url.length))}...');
            break;
          }
        }
        if (mediaUrl != null) break;
      }
    }
    
    // Strategy 4: Debug - show what URLs we found
    if (mediaUrl == null) {
      print('🔍 DEBUG: No media URL found. Looking for any URLs...');
      final allUrlPattern = RegExp(r'(?:src|href|data-url|data-src)="([^"]+)"');
      final allMatches = allUrlPattern.allMatches(html);
      var count = 0;
      for (final match in allMatches.take(10)) {
        final url = match.group(1);
        print('🔍 Found URL ${++count}: $url');
      }
      
      // Also look for any mp4 or image URLs
      final mediaPattern = RegExp(r'"([^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"');
      final mediaMatches = mediaPattern.allMatches(html);
      count = 0;
      print('🔍 All media URLs found:');
      for (final match in mediaMatches.take(5)) {
        final url = match.group(1);
        print('🔍 Media URL ${++count}: $url');
      }
    }
    
    if (mediaUrl == null || mediaUrl.isEmpty) {
      print('❌ No valid media URL found in HTML response');
      throw Exception('No valid media URL found in HTML response');
    }
    
    // Convert relative URLs to absolute
    if (mediaUrl.startsWith('/')) {
      mediaUrl = 'https://igram.world$mediaUrl';
    } else if (!mediaUrl.startsWith('http')) {
      mediaUrl = 'https://igram.world/$mediaUrl';
    }
    
    print('✅ Final media URL: ${mediaUrl.substring(0, math.min(100, mediaUrl.length))}...');
    print('📺 Media type: ${isVideo ? "Video" : "Image"}');
    
    return InstagramPostData(
      videoUrl: mediaUrl,
      displayUrl: null,
      isVideo: isVideo,
    );
  }

  Future<Uri> _resolveDirectVideoUrl(String reelUrl) async {
    print('🔄 Fetching reel page...');
    
    final userAgents = [
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Instagram 76.0.0.15.395 Android (24/7.0; 640dpi; 1440x2560; samsung; SM-G930F; herolte; samsungexynos8890; en_US)',
    ];
    
    for (int i = 0; i < userAgents.length; i++) {
      final userAgent = userAgents[i];
      print('🔄 Trying user agent ${i + 1}/${userAgents.length}: ${userAgent.substring(0, 50)}...');
      
      final headers = {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      try {
        final response = await http.get(
          Uri.parse(reelUrl),
          headers: headers,
        ).timeout(Duration(seconds: 30));

        if (response.statusCode != 200) {
          print('❌ Failed to load reel page (HTTP ${response.statusCode}) with user agent ${i + 1}');
          continue;
        }

        final html = response.body;
        print('✅ Page loaded successfully (${html.length} characters) with user agent ${i + 1}');

        try {
          return await _extractVideoFromHtml(html);
        } catch (e) {
          print('❌ Video extraction failed with user agent ${i + 1}: $e');
          if (i < userAgents.length - 1) {
            print('🔄 Trying next user agent...');
            continue;
          } else {
            rethrow;
          }
        }
      } catch (e) {
        print('❌ Request failed with user agent ${i + 1}: $e');
        if (i < userAgents.length - 1) {
          continue;
        }
        throw Exception('Failed to fetch reel page: ${e.toString()}');
      }
    }
    
    throw Exception('All user agents failed to extract video URL');
  }

  Future<Uri> _extractVideoFromHtml(String html) async {
    print('🔍 Extracting video URL from HTML...');
    
    // Strategy 1: Open Graph meta tag
    print('Strategy 1: Trying og:video meta tag');
    final ogVideo = _matchMeta(html, 'og:video');
    if (ogVideo != null && ogVideo.contains('.mp4')) {
      print('✅ Found video via og:video meta tag: ${ogVideo.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(ogVideo));
    } else if (ogVideo != null) {
      print('🔍 og:video found but no .mp4: $ogVideo');
    } else {
      print('🔍 No og:video meta tag found');
    }

    // Strategy 1.5: Try other meta tag variations
    print('Strategy 1.5: Trying other video meta tags');
    final videoTags = ['og:video:url', 'og:video:secure_url', 'twitter:player:stream', 'twitter:player'];
    for (final tag in videoTags) {
      final videoMeta = _matchMeta(html, tag);
      if (videoMeta != null && videoMeta.contains('.mp4')) {
        print('✅ Found video via $tag meta tag: ${videoMeta.substring(0, 100)}...');
        return Uri.parse(_unescapeUrl(videoMeta));
      } else if (videoMeta != null) {
        print('🔍 $tag found but no .mp4: $videoMeta');
      }
    }

    // Strategy 2: Secure URL variant
    print('Strategy 2: Trying og:video:secure_url meta tag');
    final ogVideoSecure = _matchMeta(html, 'og:video:secure_url');
    if (ogVideoSecure != null && ogVideoSecure.contains('.mp4')) {
      print('✅ Found video via og:video:secure_url meta tag: ${ogVideoSecure.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(ogVideoSecure));
    } else if (ogVideoSecure != null) {
      print('🔍 og:video:secure_url found but no .mp4: $ogVideoSecure');
    } else {
      print('🔍 No og:video:secure_url meta tag found');
    }

    // Strategy 3: JSON video_url extraction
    print('Strategy 3: Trying JSON video_url extraction');
    final jsonUrl = _matchJsonVideoUrl(html);
    if (jsonUrl != null) {
      print('✅ Found video via JSON extraction: ${jsonUrl.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(jsonUrl));
    } else {
      print('🔍 No JSON video_url found');
    }
    
    // Strategy 4: Enhanced JSON patterns
    print('Strategy 4: Trying enhanced JSON patterns');
    final enhancedJsonUrl = _findEnhancedJsonUrl(html);
    if (enhancedJsonUrl != null) {
      print('✅ Found video via enhanced JSON: ${enhancedJsonUrl.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(enhancedJsonUrl));
    } else {
      print('🔍 No enhanced JSON patterns found');
    }
    
    // Strategy 5: Script tag patterns
    print('Strategy 5: Trying script tag patterns');
    final scriptUrl = _findVideoInScripts(html);
    if (scriptUrl != null) {
      print('✅ Found video in script tags: ${scriptUrl.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(scriptUrl));
    } else {
      print('🔍 No video found in script tags');
    }
    
    // Strategy 6: Look for any video-like URLs as last resort
    print('Strategy 6: Looking for any video URLs as last resort');
    final anyVideoUrl = _findAnyVideoUrl(html);
    if (anyVideoUrl != null) {
      print('✅ Found video URL as last resort: ${anyVideoUrl.substring(0, 100)}...');
      return Uri.parse(_unescapeUrl(anyVideoUrl));
    }

    print('❌ All strategies failed to extract video URL');
    
    // Debug: Let's see what meta tags are actually present
    print('🔍 DEBUG: Analyzing available meta tags...');
    final metaTags = RegExp(r'<meta[^>]+>', caseSensitive: false).allMatches(html);
    var metaCount = 0;
    for (final metaMatch in metaTags.take(10)) {
      print('🔍 Meta tag ${++metaCount}: ${metaMatch.group(0)}');
    }
    
    // Debug: Let's look for any video-related content
    print('🔍 DEBUG: Looking for any video-related patterns...');
    final videoKeywords = ['video', 'mp4', 'stream', 'media'];
    for (final keyword in videoKeywords) {
      final keywordMatches = RegExp(keyword, caseSensitive: false).allMatches(html);
      if (keywordMatches.isNotEmpty) {
        print('🔍 Found ${keywordMatches.length} instances of "$keyword"');
        final firstMatch = keywordMatches.first;
        final start = math.max(0, firstMatch.start - 50);
        final end = math.min(html.length, firstMatch.end + 50);
        final context = html.substring(start, end);
        print('🔍 Context: $context');
      }
    }
    
    print('📄 HTML sample (first 500 chars): ${html.substring(0, math.min(500, html.length))}...');
    throw Exception('Could not find video URL in Instagram page');
  }

  String? _matchMeta(String html, String property) {
    final patterns = [
      RegExp('<meta[^>]+property="$property"[^>]+content="([^"]+)"', caseSensitive: false),
      RegExp('<meta[^>]+content="([^"]+)"[^>]+property="$property"', caseSensitive: false),
      RegExp("<meta[^>]+property='$property'[^>]+content='([^']+)'", caseSensitive: false),
      RegExp("<meta[^>]+content='([^']+)'[^>]+property='$property'", caseSensitive: false),
      RegExp('<meta[^>]+property=$property[^>]+content=([^\\s>]+)', caseSensitive: false),
      RegExp('<meta[^>]+content=([^\\s>]+)[^>]+property=$property', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        var content = match.group(1);
        if (content != null && content.isNotEmpty) {
          print('🔍 Found meta $property: ${content.substring(0, math.min(100, content.length))}...');
          content = content
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'")
              .replaceAll('&#x27;', "'");
          return content;
        }
      }
    }
    return null;
  }

  String? _matchJsonVideoUrl(String html) {
    final patterns = [
      RegExp(r'"video_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"playback_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"src":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'video_url":[^"]*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'playback_url":[^"]*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"(https://[^"]*\.mp4[^"]*)"'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          print('🔍 Found JSON video URL: ${url.substring(0, math.min(100, url.length))}...');
          if (url.contains('instagram') || url.contains('fbcdn') || url.contains('cdninstagram')) {
            return url;
          }
        }
      }
    }
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          print('🔍 Found any JSON video URL: ${url.substring(0, math.min(100, url.length))}...');
          return url;
        }
      }
    }
    
    return null;
  }

  String? _findEnhancedJsonUrl(String html) {
    final patterns = [
      RegExp(r'"video_versions":\s*\[\s*{[^}]*"url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"playback_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"video_dash_manifest"[^"]*"url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"dash_manifest"[^"]*"video_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'video_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'window\._sharedData[^}]*"video_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"video":[^}]*"url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"media":[^}]*"video_url":\s*"([^"]+\.mp4[^"]*)"'),
      RegExp(r'"(https://[^"]*instagram[^"]*\.mp4[^"]*)"'),
      RegExp(r'"(https://[^"]*fbcdn[^"]*\.mp4[^"]*)"'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          print('🔍 Found enhanced JSON URL: ${url.substring(0, math.min(100, url.length))}...');
          if (url.contains('instagram') || url.contains('fbcdn') || url.contains('cdninstagram')) {
            return url;
          }
        }
      }
    }
    return null;
  }

  String? _findVideoInScripts(String html) {
    final scriptPattern = RegExp(r'<script[^>]*>([\s\S]*?)</script>', multiLine: true);
    final scriptMatches = scriptPattern.allMatches(html);
    
    for (final scriptMatch in scriptMatches) {
      final scriptContent = scriptMatch.group(1) ?? '';
      
      final videoPatterns = [
        RegExp(r'"(https://[^"]*\.instagram\.com[^"]*\.mp4[^"]*)"'),
        RegExp(r'"(https://[^"]*fbcdn\.net[^"]*\.mp4[^"]*)"'),
        RegExp(r'"(https://[^"]*cdninstagram\.com[^"]*\.mp4[^"]*)"'),
      ];
      
      for (final pattern in videoPatterns) {
        final match = pattern.firstMatch(scriptContent);
        if (match != null && match.group(1) != null) {
          final url = match.group(1)!;
          if (url.contains('.mp4') && (url.contains('instagram') || url.contains('fbcdn'))) {
            return url;
          }
        }
      }
    }
    return null;
  }

  String? _findAnyVideoUrl(String html) {
    final videoPatterns = [
      RegExp(r'(https://[^\s\"<>]*\.mp4[^\s\"<>]*)'),
      RegExp(r'(https://[^\s\"<>]*instagram[^\s\"<>]*\.mp4[^\s\"<>]*)'),
      RegExp(r'(https://[^\s\"<>]*fbcdn[^\s\"<>]*\.mp4[^\s\"<>]*)'),
      RegExp(r'(https://[^\s\"<>]*cdninstagram[^\s\"<>]*\.mp4[^\s\"<>]*)'),
    ];

    for (final pattern in videoPatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final url = match.group(1);
        if (url != null && url.contains('.mp4')) {
          if (url.contains('instagram') || url.contains('fbcdn') || url.contains('cdninstagram')) {
            return url;
          }
        }
      }
    }
    
    for (final pattern in videoPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  String _unescapeUrl(String url) {
    return url
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\\', '')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u003D', '=')
        .replaceAll(r'\u0025', '%');
  }
  
  // Advanced background automation helper methods
  
  InstagramPostData? _extractMediaFromResponse(String responseData, String originalUrl) {
    // Try multiple extraction strategies
    
    // Strategy 1: Look for Instagram CDN URLs
    final cdnPatterns = [
      RegExp(r'"(https://[^"]*(?:instagram|fbcdn|cdninstagram)[^"]*\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
      RegExp(r'src=["\x27](https://[^"\x27]*(?:instagram|fbcdn)[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
      RegExp(r'href=["\x27](https://[^"\x27]*(?:instagram|fbcdn)[^"\x27]*\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
    ];
    
    for (final pattern in cdnPatterns) {
      final matches = pattern.allMatches(responseData);
      for (final match in matches) {
        final url = match.group(1)!;
        if (_isValidMediaUrl(url)) {
          print('✅ Found Instagram CDN URL: ${url.substring(0, math.min(80, url.length))}...');
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Strategy 2: Look for download links
    final downloadPatterns = [
      RegExp(r'download[^>]*href=["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
      RegExp(r'data-download-url=["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
      RegExp(r'"download_url"\s*:\s*"([^"]+\.(?:mp4|jpg|jpeg|png)[^"]*?)"'),
    ];
    
    for (final pattern in downloadPatterns) {
      final match = pattern.firstMatch(responseData);
      if (match != null) {
        final url = match.group(1)!;
        if (_isValidMediaUrl(url)) {
          print('✅ Found download URL: ${url.substring(0, math.min(80, url.length))}...');
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    // Strategy 3: Look for JavaScript variables
    final jsPatterns = [
      RegExp(r'var\s+(?:mediaUrl|downloadUrl|videoUrl)\s*=\s*["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
      RegExp(r'window\.(?:mediaUrl|downloadUrl)\s*=\s*["\x27]([^"\x27]+\.(?:mp4|jpg|jpeg|png)[^"\x27]*?)["\x27]'),
    ];
    
    for (final pattern in jsPatterns) {
      final match = pattern.firstMatch(responseData);
      if (match != null) {
        final url = match.group(1)!;
        if (_isValidMediaUrl(url)) {
          print('✅ Found JS media URL: ${url.substring(0, math.min(80, url.length))}...');
          return InstagramPostData(
            videoUrl: url,
            displayUrl: null,
            isVideo: url.contains('.mp4'),
          );
        }
      }
    }
    
    print('⚠️ No valid media URL found in response (${responseData.length} chars)');
    return null;
  }
  
  bool _isValidMediaUrl(String url) {
    // Comprehensive validation for media URLs
    if (url.isEmpty || url.length < 20) return false;
    
    // Must be HTTPS
    if (!url.startsWith('https://')) return false;
    
    // Must contain media file extension
    if (!RegExp(r'\.(mp4|jpg|jpeg|png)(\?|$|#)').hasMatch(url)) return false;
    
    // Must not be favicon, icon, logo, etc.
    final excludePatterns = [
      'favicon', 'icon', 'logo', 'sprite', 'avatar', 'profile',
      'thumb_', 'placeholder', 'loading', 'error', 'default'
    ];
    
    for (final pattern in excludePatterns) {
      if (url.toLowerCase().contains(pattern)) return false;
    }
    
    // Prefer Instagram CDN URLs
    final preferredDomains = ['instagram.com', 'fbcdn.net', 'cdninstagram.com'];
    for (final domain in preferredDomains) {
      if (url.contains(domain)) return true;
    }
    
    // Allow other domains if URL is long enough (likely actual content)
    return url.length > 60;
  }
  
  // Missing automation helper methods
  
  Future<String?> _loadPageWithSession(String url, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return _safeDecodeResponse(response);
      }
    } catch (e) {
      print('⚠️ Failed to load page with session: $e');
    }
    return null;
  }
  
  Map<String, String>? _extractAndProcessFormElements(String? pageHtml, String storyUrl) {
    if (pageHtml == null) return null;
    
    try {
      final formData = _analyzeFormAdvanced(pageHtml);
      formData['url'] = storyUrl;
      formData['instagram_url'] = storyUrl;
      formData['link'] = storyUrl;
      return formData;
    } catch (e) {
      print('⚠️ Failed to extract form elements: $e');
      return null;
    }
  }
  
  Future<String?> _simulateUserInteraction(String url, Map<String, String>? formData, Map<String, String> headers) async {
    if (formData == null) return null;
    
    try {
      // Simulate typing delay
      await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));
      
      final formBody = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formBody,
      ).timeout(Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        return _safeDecodeResponse(response);
      }
    } catch (e) {
      print('⚠️ Failed to simulate user interaction: $e');
    }
    
    return null;
  }
  
  InstagramPostData? _extractMediaUrlsAdvanced(String? responseData) {
    if (responseData == null) return null;
    
    try {
      return _extractMediaFromResponse(responseData, '');
    } catch (e) {
      print('⚠️ Failed to extract media URLs: $e');
      return null;
    }
  }
}