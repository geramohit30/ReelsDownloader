import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Network diagnostics utility to help troubleshoot connectivity issues
class NetworkDiagnostics {
  /// Comprehensive network connectivity test
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    print('\n' + '=' * 60);
    print('🔧 NETWORK DIAGNOSTICS - FULL TEST SUITE');
    print('=' * 60);
    
    final results = <String, dynamic>{};
    final startTime = DateTime.now();
    
    // Test 1: DNS Resolution
    print('\n🧪 TEST 1: DNS RESOLUTION');
    print('-' * 30);
    try {
      final dnsStart = DateTime.now();
      final googleResult = await InternetAddress.lookup('google.com').timeout(Duration(seconds: 10));
      final dnsEnd = DateTime.now();
      
      if (googleResult.isNotEmpty) {
        print('✅ DNS Resolution: SUCCESS');
        print('   • Resolved google.com to: ${googleResult.first.address}');
        print('   • DNS lookup time: ${dnsEnd.difference(dnsStart).inMilliseconds}ms');
        results['dns_google'] = {
          'success': true,
          'address': googleResult.first.address,
          'time_ms': dnsEnd.difference(dnsStart).inMilliseconds,
        };
      } else {
        print('❌ DNS Resolution: FAILED - Empty result');
        results['dns_google'] = {'success': false, 'error': 'Empty DNS result'};
      }
    } catch (e) {
      print('❌ DNS Resolution: FAILED');
      print('   • Error: $e');
      results['dns_google'] = {'success': false, 'error': e.toString()};
    }
    
    // Test 2: Instagram DNS Resolution
    print('\n🧪 TEST 2: INSTAGRAM DNS RESOLUTION');
    print('-' * 30);
    try {
      final dnsStart = DateTime.now();
      final igResult = await InternetAddress.lookup('instagram.com').timeout(Duration(seconds: 10));
      final dnsEnd = DateTime.now();
      
      if (igResult.isNotEmpty) {
        print('✅ Instagram DNS: SUCCESS');
        print('   • Resolved instagram.com to: ${igResult.first.address}');
        print('   • DNS lookup time: ${dnsEnd.difference(dnsStart).inMilliseconds}ms');
        results['dns_instagram'] = {
          'success': true,
          'address': igResult.first.address,
          'time_ms': dnsEnd.difference(dnsStart).inMilliseconds,
        };
      } else {
        print('❌ Instagram DNS: FAILED - Empty result');
        results['dns_instagram'] = {'success': false, 'error': 'Empty DNS result'};
      }
    } catch (e) {
      print('❌ Instagram DNS: FAILED');
      print('   • Error: $e');
      results['dns_instagram'] = {'success': false, 'error': e.toString()};
    }
    
    // Test 3: HTTP Connectivity to Google
    print('\n🧪 TEST 3: HTTP CONNECTIVITY (Google)');
    print('-' * 30);
    try {
      final httpStart = DateTime.now();
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; InstagramReelDownloader/1.0)',
        },
      ).timeout(Duration(seconds: 15));
      final httpEnd = DateTime.now();
      
      print('✅ Google HTTP: SUCCESS');
      print('   • Status: ${response.statusCode}');
      print('   • Response time: ${httpEnd.difference(httpStart).inMilliseconds}ms');
      print('   • Content length: ${response.bodyBytes.length} bytes');
      results['http_google'] = {
        'success': true,
        'status_code': response.statusCode,
        'time_ms': httpEnd.difference(httpStart).inMilliseconds,
        'content_length': response.bodyBytes.length,
      };
    } catch (e) {
      print('❌ Google HTTP: FAILED');
      print('   • Error: $e');
      results['http_google'] = {'success': false, 'error': e.toString()};
    }
    
    // Test 4: HTTP Connectivity to Instagram
    print('\n🧪 TEST 4: HTTP CONNECTIVITY (Instagram)');
    print('-' * 30);
    try {
      final httpStart = DateTime.now();
      final response = await http.get(
        Uri.parse('https://www.instagram.com'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(Duration(seconds: 30));
      final httpEnd = DateTime.now();
      
      print('✅ Instagram HTTP: SUCCESS');
      print('   • Status: ${response.statusCode}');
      print('   • Response time: ${httpEnd.difference(httpStart).inMilliseconds}ms');
      print('   • Content length: ${response.bodyBytes.length} bytes');
      print('   • Content type: ${response.headers['content-type'] ?? 'unknown'}');
      results['http_instagram'] = {
        'success': true,
        'status_code': response.statusCode,
        'time_ms': httpEnd.difference(httpStart).inMilliseconds,
        'content_length': response.bodyBytes.length,
        'content_type': response.headers['content-type'],
      };
    } catch (e) {
      print('❌ Instagram HTTP: FAILED');
      print('   • Error: $e');
      print('   • Error type: ${e.runtimeType}');
      
      // Analyze common error types
      if (e is SocketException) {
        print('   • This is a network connectivity issue');
        print('   • Possible causes: No internet, firewall, proxy blocking');
      } else if (e is TimeoutException) {
        print('   • This is a timeout issue');
        print('   • Possible causes: Slow internet, network congestion, server issues');
      } else if (e.toString().contains('Certificate')) {
        print('   • This is an SSL/TLS certificate issue');
        print('   • Possible causes: System time wrong, proxy interference');
      }
      
      results['http_instagram'] = {
        'success': false,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
    
    // Test 5: Platform Info
    print('\n🧪 TEST 5: PLATFORM INFORMATION');
    print('-' * 30);
    print('✅ Platform Details:');
    print('   • Operating System: ${Platform.operatingSystem}');
    print('   • OS Version: ${Platform.operatingSystemVersion}');
    print('   • Dart Version: ${Platform.version}');
    print('   • Number of processors: ${Platform.numberOfProcessors}');
    
    results['platform'] = {
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'processors': Platform.numberOfProcessors,
    };
    
    final endTime = DateTime.now();
    final totalTime = endTime.difference(startTime).inMilliseconds;
    
    print('\n' + '=' * 60);
    print('📊 DIAGNOSTICS SUMMARY');
    print('=' * 60);
    print('🕒 Total test time: ${totalTime}ms');
    
    final dnsSuccess = results['dns_google']?['success'] == true && results['dns_instagram']?['success'] == true;
    final httpSuccess = results['http_google']?['success'] == true && results['http_instagram']?['success'] == true;
    
    if (dnsSuccess && httpSuccess) {
      print('🟢 OVERALL STATUS: ALL TESTS PASSED ✅');
      print('   • Your internet connection appears to be working correctly');
      print('   • The "no internet connection" error might be application-specific');
    } else if (dnsSuccess && !httpSuccess) {
      print('🟡 OVERALL STATUS: DNS WORKS, HTTP ISSUES ⚠️');
      print('   • DNS resolution is working');
      print('   • HTTP requests are failing - check firewall/proxy settings');
    } else if (!dnsSuccess) {
      print('🔴 OVERALL STATUS: DNS FAILURE ❌');
      print('   • Cannot resolve domain names');
      print('   • Check your internet connection and DNS settings');
    } else {
      print('🟡 OVERALL STATUS: MIXED RESULTS ⚠️');
      print('   • Some tests passed, others failed');
      print('   • Check individual test results above for details');
    }
    
    print('\n💡 RECOMMENDATIONS:');
    if (!dnsSuccess) {
      print('   • Check your internet connection');
      print('   • Try switching between WiFi and mobile data');
      print('   • Check DNS settings (try 8.8.8.8 or 1.1.1.1)');
    }
    if (!httpSuccess && dnsSuccess) {
      print('   • Check firewall settings');
      print('   • Disable VPN temporarily');
      print('   • Check proxy configuration');
      print('   • Try a different network');
    }
    
    results['summary'] = {
      'total_time_ms': totalTime,
      'dns_success': dnsSuccess,
      'http_success': httpSuccess,
      'overall_success': dnsSuccess && httpSuccess,
    };
    
    print('=' * 60);
    
    return results;
  }
  
  /// Quick connectivity test (used by InstagramService)
  static Future<bool> quickConnectivityTest() async {
    try {
      // Try DNS first
      final result = await InternetAddress.lookup('google.com').timeout(Duration(seconds: 5));
      if (result.isEmpty) return false;
      
      // Try HTTP request
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': 'InstagramReelDownloader/1.0'},
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}