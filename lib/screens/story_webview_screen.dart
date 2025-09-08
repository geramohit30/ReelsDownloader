import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StoryWebViewScreen extends StatefulWidget {
  final String? initialUrl;
  
  const StoryWebViewScreen({
    super.key,
    this.initialUrl,
  });

  @override
  State<StoryWebViewScreen> createState() => _StoryWebViewScreenState();
}

class _StoryWebViewScreenState extends State<StoryWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  String currentUrl = '';

  // Professional Instagram story downloader websites
  final List<Map<String, String>> storyDownloaders = [
    {
      'name': 'StorySaver.net',
      'url': 'https://www.storysaver.net/download-instagram-videos/',
      'description': 'Professional Instagram story downloader with high success rate'
    },
    {
      'name': 'SaveInsta',
      'url': 'https://saveinsta.app/instagram-story-downloader',
      'description': 'Fast and reliable story downloading'
    },
    {
      'name': 'iGram.world',
      'url': 'https://igram.world/story-saver',
      'description': 'Popular story saver with multiple format support'
    },
    {
      'name': 'SnapInsta',
      'url': 'https://snapinsta.app/instagram-story-downloader',
      'description': 'Easy-to-use Instagram story downloader'
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Start with the most reliable story downloader
    final initialDownloader = storyDownloaders.first;
    currentUrl = initialDownloader['url']!;
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            
            // Auto-fill the Instagram story URL if provided
            if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
              _autoFillStoryUrl();
            }
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load page: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(currentUrl));
  }

  void _autoFillStoryUrl() {
    if (widget.initialUrl == null) return;
    
    // JavaScript to automatically fill the URL input field
    final script = '''
      setTimeout(function() {
        // Common input selectors for Instagram story URL
        const selectors = [
          'input[placeholder*="nstagram"]',
          'input[placeholder*="tory"]',
          'input[placeholder*="URL"]',
          'input[placeholder*="url"]',
          'input[type="url"]',
          'input[name*="url"]',
          'input[id*="url"]',
          'textarea[placeholder*="nstagram"]',
          '.url-input input',
          '#url',
          'input[class*="url"]'
        ];
        
        for (let selector of selectors) {
          const input = document.querySelector(selector);
          if (input) {
            input.value = "${widget.initialUrl}";
            input.focus();
            
            // Trigger common events
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            input.dispatchEvent(new Event('paste', { bubbles: true }));
            
            console.log('Auto-filled URL in:', selector);
            break;
          }
        }
      }, 2000);
    ''';
    
    controller.runJavaScript(script);
  }

  void _switchDownloader(Map<String, String> downloader) {
    setState(() {
      isLoading = true;
      currentUrl = downloader['url']!;
    });
    
    controller.loadRequest(Uri.parse(downloader['url']!));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${downloader['name']}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _refreshPage() {
    controller.reload();
  }

  void _showDownloaderSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Story Downloader',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...storyDownloaders.map((downloader) {
                final isCurrentSite = currentUrl == downloader['url'];
                
                return Card(
                  elevation: isCurrentSite ? 4 : 1,
                  color: isCurrentSite ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                  child: ListTile(
                    leading: Icon(
                      Icons.language,
                      color: isCurrentSite ? Theme.of(context).primaryColor : null,
                    ),
                    title: Text(
                      downloader['name']!,
                      style: TextStyle(
                        fontWeight: isCurrentSite ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(downloader['description']!),
                    trailing: isCurrentSite 
                      ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                      : Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      if (!isCurrentSite) {
                        _switchDownloader(downloader);
                      }
                    },
                  ),
                );
              }).toList(),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instagram Story Downloader',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              storyDownloaders.firstWhere((d) => d['url'] == currentUrl)['name']!,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshPage,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.language),
            onPressed: _showDownloaderSelector,
            tooltip: 'Switch Downloader',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading Story Downloader...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (widget.initialUrl != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Will auto-fill your story URL',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          border: Border(
            top: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paste your Instagram story URL in the input field above',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.initialUrl != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 16, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Story URL: ${widget.initialUrl!.length > 50 ? widget.initialUrl!.substring(0, 50) + "..." : widget.initialUrl!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}