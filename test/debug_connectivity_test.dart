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
    print('📝 Attempt 1: Using optimized method');
    final result1 = await service.getPostDataOptimized(testUrl);
    print('✅ SUCCESS: Optimized method worked!');
    print('   Video URL: ${result1.videoUrl}');
  } catch (e) {
    print('❌ FAILED: Optimized method');
    print('   Error: $e');
    
    // Try direct method
    print('\n📝 Attempt 2: Direct method test');
    try {
      final result2 = await service.getPostDataOptimized(testUrl);
      print('✅ SUCCESS: Direct method worked!');
      print('   Video URL: ${result2.videoUrl}');
      print('\n💡 SOLUTION: The optimized method works');
    } catch (e2) {
      print('❌ FAILED: All methods failed');
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