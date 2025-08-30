import 'package:instareeldownloader/services/instagram_service.dart';
import 'package:instareeldownloader/utils/network_diagnostics.dart';

/// Simple test to debug the "no internet connection" error
void main() async {
  print('🔧 DEBUGGING "No Internet Connection" ERROR');
  print('=' * 60);
  
  // Step 1: Run comprehensive network diagnostics
  print('STEP 1: Running network diagnostics...\n');
  final diagnostics = await NetworkDiagnostics.runFullDiagnostics();
  
  // Step 2: Test Instagram service with a sample URL
  print('\nSTEP 2: Testing Instagram service...\n');
  
  final service = InstagramService();
  final testUrl = 'https://www.instagram.com/reel/C123456789/';  // Sample URL format
  
  try {
    // First try with connectivity check
    print('📝 Attempt 1: With connectivity check');
    final result1 = await service.getPostData(testUrl);
    print('✅ SUCCESS: With connectivity check worked!');
    print('   Video URL: ${result1.videoUrl}');
  } catch (e) {
    print('❌ FAILED: With connectivity check');
    print('   Error: $e');
    
    // Try without connectivity check
    print('\n📝 Attempt 2: Skipping connectivity check');
    try {
      final result2 = await service.getPostData(testUrl, skipConnectivityCheck: true);
      print('✅ SUCCESS: Without connectivity check worked!');
      print('   Video URL: ${result2.videoUrl}');
      print('\n💡 SOLUTION: The connectivity check is the issue');
      print('   You can use skipConnectivityCheck: true as a workaround');
    } catch (e2) {
      print('❌ FAILED: Even without connectivity check');
      print('   Error: $e2');
      
      if (diagnostics['summary']['dns_success'] == true && 
          diagnostics['summary']['http_success'] == true) {
        print('\n🤔 ANALYSIS: Network tests pass but Instagram service fails');
        print('   This might be an Instagram-specific blocking issue');
      } else {
        print('\n🤔 ANALYSIS: Network connectivity issues detected');
        print('   Check the network diagnostics results above');
      }
    }
  }
  
  print('\n' + '=' * 60);
  print('🏁 TEST COMPLETE');
  print('=' * 60);
}