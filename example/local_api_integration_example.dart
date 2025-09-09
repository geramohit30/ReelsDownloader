import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:instareeldownloader/services/local_api_service.dart';
import 'package:instareeldownloader/models/instagram_reel_data.dart';

/// Complete example showing how your API response format integrates with the Flutter app
///
/// Your API Response Format:
/// {
///   "originalUrl": "https://www.instagram.com/reel/DKG8krgseWt/",
///   "downloadUrl": "https://media.igram.world/get?__sig=ghnD9-fzlabaek8mu19eCA&__expires=1757331133&uri=..."
/// }

class LocalApiIntegrationExample {
  /// Demonstrates the complete integration with your API response format
  static Future<void> demonstrateYourApiFormat() async {
    print('🎯 DEMONSTRATING YOUR API FORMAT INTEGRATION');
    print('=' * 60);

    const testUrl = 'https://www.instagram.com/reel/DKG8krgseWt/';

    // Step 1: Show what the Flutter app sends (matches your cURL exactly)
    print('\n📤 FLUTTER APP REQUEST (matches your cURL):');
    print('POST http://localhost:3000/api/insta/reels');
    print('Content-Type: application/json');
    print('Body: ${jsonEncode({"url": testUrl})}');

    // Step 2: Show your expected response format
    print('\n📥 YOUR API RESPONSE FORMAT:');
    final yourApiResponse = {
      "originalUrl": "https://www.instagram.com/reel/DKG8krgseWt/",
      "downloadUrl":
          "https://media.igram.world/get?__sig=ghnD9-fzlabaek8mu19eCA&__expires=1757331133&uri=https%3A%2F%2Fscontent-lga3-1.cdninstagram.com%2Fo1%2Fv%2Ft2%2Ff2%2Fm86%2FAQOZDE39GlJXwuxn06WFfh9oogXwMHWYWeVS4RY3wOl9rrMQJIta919ILLXfBL18kxV8H1M7THwJL7tOsOmAaFejLtzmtyv-9o920aw.mp4%3F_nc_cat%3D103%26_nc_sid%3D5e9851%26_nc_ht%3Dscontent-lga3-1.cdninstagram.com%26_nc_ohc%3DBYJ9Os2UUg0Q7kNvwEcuieU%26efg%3DeyJ2ZW5jb2RlX3RhZyI6Inhwdl9wcm9ncmVzc2l2ZS5JTlNUQUdSQU0uQ0xJUFMuQzMuNzIwLmRhc2hfYmFzZWxpbmVfMV92MSIsInhwdl9hc3NldF9pZCI6MTI0MzUzNjYwNDA2ODcyOSwidmlfdXNlY2FzZV9pZCI6MTAwOTksImR1cmF0aW9uX3MiOjMwLCJ1cmxnZW5fc291cmNlIjoid3d3In0%253D%26ccb%3D17-1%26vs%3De3093e27bcfc0489%26_nc_vs%3DHBksFQIYUmlnX3hwdl9yZWVsc19wZXJtYW5lbnRfc3JfcHJvZC80NDRCRTBDMDBGQkY0Nzc2QTY0MTYwRjZCOTk1OUNBRV92aWRlb19kYXNoaW5pdC5tcDQVAALIARIAFQIYOnBhc3N0aHJvdWdoX2V2ZXJzdG9yZS9HSTF0M3gyOFZ2d1lKR3dFQUFLM0JLUTdUN0pYYnFfRUFBQUYVAgLIARIAKAAYABsCiAd1c2Vfb2lsATEScHJvZ3Jlc3NpdmVfcmVjaXBlATEVAAAm8u3n2K2_tQQVAigCQzMsF0A-4UeuFHrhGBJkYXNoX2Jhc2VsaW5lXzFfdjERAHX-B2XmnQEA%26_nc_gid%3D1UARaj-n7QYuh7luniRzKA%26_nc_zt%3D28%26oh%3D00_AfYupm_thpPFQE5x1YGSK99JhsPTQxMBOUkgQnU4hQHq0g%26oe%3D68C084AC%26dl%3D1&filename=Let%20the%20magic%20of%20the%20season%20cast%20a%20spell%20%F0%9F%AA%84%E2%9C%A8%23reels%20%23instagramreels%20%23trendingreels%20%23reelitfeelit%20.mp4&ua=-&referer=https%3A%2F%2Fwww.instagram.com%2F",
    };

    print(jsonEncode(yourApiResponse));

    // Step 3: Show how Flutter app processes this
    print('\n🔄 HOW FLUTTER APP PROCESSES YOUR RESPONSE:');
    try {
      final reelData = InstagramReelData.fromJson(yourApiResponse, testUrl);
      print('✅ Successfully parsed your API response:');
      print('   • ID: ${reelData.id}');
      print('   • Media URL: ${reelData.mediaUrl.substring(0, 100)}...');
      print('   • Original URL: ${reelData.originalUrl}');
      print('   • Title: ${reelData.title}');
      print('   • Author: ${reelData.author}');
    } catch (e) {
      print('❌ Error processing response: $e');
    }

    // Step 4: Show supported variations
    print('\n🔧 SUPPORTED RESPONSE VARIATIONS:');
    print('Your API can use any of these field names:');
    print('');

    final variations = [
      {
        'name': 'Current Format (Preferred)',
        'example': {
          'originalUrl': '...',
          'downloadUrl': '...',
          'thumbnailUrl': '...', // optional
        },
      },
      {
        'name': 'Alternative Format 1',
        'example': {
          'originalUrl': '...',
          'media_url': '...',
          'thumbnail_url': '...',
        },
      },
      {
        'name': 'Alternative Format 2',
        'example': {
          'url': '...',
          'video_url': '...',
          'thumbnail': '...',
          'title': '...',
          'author': '...',
          'duration': 30,
        },
      },
    ];

    for (final variation in variations) {
      print('${variation['name']}:');
      print(jsonEncode(variation['example']));
      print('');
    }
  }

  /// Example widget showing how to use LocalApiService in a Flutter UI
  static Widget buildExampleWidget() {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Local API Integration')),
        body: LocalApiExampleScreen(),
      ),
    );
  }
}

class LocalApiExampleScreen extends StatefulWidget {
  @override
  _LocalApiExampleScreenState createState() => _LocalApiExampleScreenState();
}

class _LocalApiExampleScreenState extends State<LocalApiExampleScreen> {
  final _urlController = TextEditingController();
  InstagramReelData? _reelData;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchReel() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _reelData = null;
    });

    try {
      // Test connection first
      final isConnected = await LocalApiService.testConnection();
      if (!isConnected) {
        throw Exception('Local API server is not running on localhost:3000');
      }

      // Fetch reel data using your API format
      final data = await LocalApiService.fetchInstagramReel(url);

      setState(() {
        _reelData = data;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully fetched reel data!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Test Your Local API Integration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),

          // URL Input
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Instagram Reel/Story URL',
              hintText: 'https://www.instagram.com/reel/DKG8krgseWt/',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),

          // Fetch Button
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchReel,
            child:
                _isLoading
                    ? CircularProgressIndicator()
                    : Text('Fetch from Local API'),
          ),
          SizedBox(height: 24),

          // Results
          if (_error != null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(_error!, style: TextStyle(color: Colors.red)),
                ],
              ),
            ),

          if (_reelData != null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Success!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('ID: ${_reelData!.id}'),
                  Text('Title: ${_reelData!.title}'),
                  Text('Author: ${_reelData!.author}'),
                  Text('Duration: ${_reelData!.duration}s'),
                  SizedBox(height: 8),
                  Text(
                    'Media URL:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _reelData!.mediaUrl.length > 100
                        ? '${_reelData!.mediaUrl.substring(0, 100)}...'
                        : _reelData!.mediaUrl,
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  if (_reelData!.thumbnailUrl != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'Thumbnail URL:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _reelData!.thumbnailUrl!.length > 100
                          ? '${_reelData!.thumbnailUrl!.substring(0, 100)}...'
                          : _reelData!.thumbnailUrl!,
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),

          Spacer(),

          // Instructions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('1. Start your server on localhost:3000'),
                Text('2. Paste an Instagram reel or story URL'),
                Text('3. Tap "Fetch from Local API"'),
                Text('4. Your API should return the downloadUrl format'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Test cases for your API format
class ApiFormatTests {
  static void runTests() {
    print('🧪 RUNNING API FORMAT TESTS');
    print('=' * 40);

    // Test 1: Your exact API response format
    testYourApiFormat();

    // Test 2: Alternative formats
    testAlternativeFormats();

    // Test 3: Stories support
    testStoriesSupport();
  }

  static void testYourApiFormat() {
    print('\n✅ Test 1: Your API Response Format');

    final response = {
      "originalUrl": "https://www.instagram.com/reel/DKG8krgseWt/",
      "downloadUrl":
          "https://media.igram.world/get?__sig=test&uri=https://scontent.cdninstagram.com/video.mp4",
    };

    try {
      final data = InstagramReelData.fromJson(
        response,
        "https://www.instagram.com/reel/DKG8krgseWt/",
      );
      print('   ✅ Successfully parsed');
      print('   • Media URL: ${data.mediaUrl.substring(0, 50)}...');
      print('   • Original URL: ${data.originalUrl}');
    } catch (e) {
      print('   ❌ Failed: $e');
    }
  }

  static void testAlternativeFormats() {
    print('\n✅ Test 2: Alternative Formats');

    final formats = [
      {
        'name': 'media_url format',
        'data': {'media_url': 'https://test.com/video.mp4'},
      },
      {
        'name': 'video_url format',
        'data': {'video_url': 'https://test.com/video.mp4'},
      },
      {
        'name': 'url format',
        'data': {'url': 'https://test.com/video.mp4'},
      },
    ];

    for (final format in formats) {
      try {
        final data = InstagramReelData.fromJson(
          format['data'] as Map<String, dynamic>,
          "https://www.instagram.com/reel/test/",
        );
        print('   ✅ ${format['name']}: ${data.mediaUrl}');
      } catch (e) {
        print('   ❌ ${format['name']}: Failed');
      }
    }
  }

  static void testStoriesSupport() {
    print('\n✅ Test 3: Stories Support');

    const storyUrl = 'https://www.instagram.com/stories/username/123456789/';

    // Test URL validation
    try {
      final response = {'downloadUrl': 'https://test.com/story.mp4'};
      final data = InstagramReelData.fromJson(response, storyUrl);
      print('   ✅ Stories URL parsing works');
      print('   • Story URL: ${data.originalUrl}');
    } catch (e) {
      print('   ❌ Stories parsing failed: $e');
    }
  }
}
