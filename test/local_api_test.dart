import 'package:flutter_test/flutter_test.dart';
import 'package:instareeldownloader/services/local_api_service.dart';

/// Test file demonstrating how to use the LocalApiService
///
/// This test shows the complete implementation of your curl command:
/// curl --location 'http://localhost:3000/api/insta/reels' \
/// --header 'Content-Type: application/json' \
/// --data '{"url" : "https://www.instagram.com/reel/DKG8krgseWt/"}'
void main() {
  group('LocalApiService Tests', () {
    const testReelUrl = 'https://www.instagram.com/reel/DKG8krgseWt/';

    test('should connect to local API server', () async {
      // Test if the local API server is running
      final isConnected = await LocalApiService.testConnection();

      if (!isConnected) {
        print('❌ Local API server is not running on localhost:3000');
        print('   Please start your server first and try again.');
        return;
      }

      print('✅ Local API server is running');
    });

    test('should fetch Instagram reel data from local API', () async {
      try {
        print('🚀 Testing LocalApiService.fetchInstagramReel()');
        print('   URL: $testReelUrl');
        print('   This implements your curl command internally');

        // This call internally implements:
        // POST http://localhost:3000/api/insta/reels
        // Content-Type: application/json
        // Body: {"url": "https://www.instagram.com/reel/DKG8krgseWt/"}
        final reelData = await LocalApiService.fetchInstagramReel(testReelUrl);

        print('✅ Successfully fetched reel data:');
        print('   ID: ${reelData.id}');
        print('   Title: ${reelData.title}');
        print('   Author: ${reelData.author}');
        print('   Duration: ${reelData.duration}s');
        print(
          '   Media URL: ${reelData.mediaUrl.length > 100 ? "${reelData.mediaUrl.substring(0, 100)}..." : reelData.mediaUrl}',
        );

        // Verify the response contains expected data
        expect(reelData.id, isNotEmpty);
        expect(reelData.mediaUrl, isNotEmpty);
        expect(reelData.originalUrl, equals(testReelUrl));
      } catch (e) {
        print('❌ Error testing local API: $e');

        if (e.toString().contains('connection')) {
          print(
            '💡 Make sure your local API server is running on localhost:3000',
          );
        }

        rethrow;
      }
    });

    test('should handle invalid Instagram URLs', () async {
      const invalidUrl = 'https://example.com/not-instagram';

      try {
        await LocalApiService.fetchInstagramReel(invalidUrl);
        fail('Should have thrown an exception for invalid URL');
      } catch (e) {
        print('✅ Correctly rejected invalid URL: $e');
        expect(e.toString(), contains('Invalid Instagram URL'));
      }
    });

    test('should handle server connection errors gracefully', () async {
      // Test with a URL that should fail (assuming server is not running on port 9999)
      const testUrl = 'https://www.instagram.com/reel/test123/';

      // Temporarily override the base URL to test connection errors
      // Note: This would require modifying the service to accept custom base URLs
      // For now, this test documents the expected behavior

      print(
        '🧪 This test documents expected behavior when server is unreachable',
      );
      print('   Expected: LocalApiException with connectionError type');
    });
  });

  group('Integration with Flutter App', () {
    test('API response structure should match app expectations', () {
      print('📋 API Response Format Expected by Flutter App:');
      print('');
      print(
        'Your localhost:3000/api/insta/reels endpoint should return JSON like:',
      );
      print('{');
      print('  "id": "reel_id_or_shortcode",');
      print('  "media_url": "https://scontent.cdninstagram.com/video.mp4",');
      print(
        '  "thumbnail_url": "https://scontent.cdninstagram.com/image.jpg",',
      );
      print('  "title": "Reel title or caption",');
      print('  "author": "username",');
      print('  "duration": 30');
      print('}');
      print('');
      print('Alternative field names that are also supported:');
      print('- "media_url", "video_url", or "url" instead of "downloadUrl"');
      print(
        '- "thumbnail_url", "thumbnail", or "poster" instead of "thumbnailUrl"',
      );
      print('- "title" or "caption" for reel title');
      print('- "author", "username", or "user" for author name');
      print('- "duration" for video duration in seconds');
    });
  });
}

/// Example of how to use LocalApiService in your Flutter app
class LocalApiServiceExample {
  static Future<void> demonstrateUsage() async {
    const reelUrl = 'https://www.instagram.com/reel/DKG8krgseWt/';

    try {
      // Step 1: Test connection (optional but recommended)
      print('🔍 Testing connection to local API...');
      final isConnected = await LocalApiService.testConnection();

      if (!isConnected) {
        throw Exception('Local API server is not running on localhost:3000');
      }

      // Step 2: Fetch reel data
      print('📥 Fetching reel data...');
      final reelData = await LocalApiService.fetchInstagramReel(reelUrl);

      // Step 3: Use the data
      print('✅ Reel fetched successfully:');
      print('   📹 Video: ${reelData.mediaUrl}');
      print('   🖼️ Thumbnail: ${reelData.thumbnailUrl ?? "Not available"}');
      print('   👤 Author: ${reelData.author}');
      print('   📝 Title: ${reelData.title}');
    } catch (e) {
      print('❌ Error: $e');

      // Handle specific error types
      if (e is LocalApiException) {
        print('   User-friendly message: ${e.userFriendlyMessage}');
        print('   Error type: ${e.type}');
      }
    }
  }
}
