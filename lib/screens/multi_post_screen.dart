import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instagram_multi_post_data.dart';
import '../models/instagram_types.dart';
import '../models/reel_item.dart';
import '../providers/download_provider.dart';
import '../screens/preview_screen.dart';
import '../services/download_service.dart';
import '../services/local_api_service.dart';
import '../services/instagram_utils.dart';

class MultiPostScreen extends StatefulWidget {
  const MultiPostScreen({
    super.key,
    required this.reelUrl,
  });

  final String reelUrl;

  @override
  State<MultiPostScreen> createState() => _MultiPostScreenState();
}

class _MultiPostScreenState extends State<MultiPostScreen> {
  InstagramMultiPostData? _multiPostData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDownloading = false;
  int? _downloadingIndex;
  double? _downloadProgress;
  final DownloadService _downloadService = DownloadService();

  @override
  void initState() {
    super.initState();
    print('🟢 MULTI POST: Initializing MultiPostScreen');
    _loadMultiPostData();
  }

  @override
  void dispose() {
    print('🔴 MULTI POST: Disposing MultiPostScreen');
    super.dispose();
  }

  Future<void> _loadMultiPostData() async {
    print('🔍 MULTI POST: Loading multi-post data for URL: ${widget.reelUrl}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await LocalApiService.fetchMultipleInstagramPosts(widget.reelUrl);
      print('✅ MULTI POST: Loaded ${data.allUrls.length} posts');
      
      // Check if we got any data
      if (data.allUrls.isNotEmpty) {
        if (mounted) {
          setState(() {
            _multiPostData = data;
            _isLoading = false;
          });
          print('🟢 MULTI POST: Data loaded successfully and UI updated');
        }
      } else {
        // If no data found, try alternative approaches or show error
        print('⚠️ MULTI POST: No posts found in response');
        if (mounted) {
          setState(() {
            _errorMessage = 'No posts found for this URL';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ MULTI POST: Error loading multi-post data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAllPosts() async {
    print('📥 MULTI POST: Starting download of all posts');
    if (_multiPostData == null) {
      print('❌ MULTI POST: No data available for download');
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<DownloadProvider>();
      print('🚀 MULTI POST: Downloading ${_multiPostData!.allUrls.length} posts');
      
      // Download all posts
      final items = await _downloadService.downloadAllInstagramPosts(
        reelUrl: widget.reelUrl,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onItemProgress: (current, total) {
          print('📥 MULTI POST: Downloading item $current of $total');
          setState(() {
            _downloadingIndex = current;
          });
        },
      );

      print('✅ MULTI POST: Downloaded ${items.length} items');
      
      // Add all items to the download list
      for (final item in items) {
        await provider.addItem(item);
      }

      if (mounted) {
        print('✅ MULTI POST: All posts downloaded successfully, showing snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All posts downloaded successfully')),
        );
        
        // Don't pop the screen - just reset the downloading state
        // Let the user decide when to go back
        setState(() {
          _isDownloading = false;
          _downloadingIndex = null;
          _downloadProgress = null;
        });
      }
    } catch (e) {
      print('❌ MULTI POST: Download failed with error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingIndex = null;
          _downloadProgress = null;
        });
        print('🔄 MULTI POST: Download state reset');
      }
    }
  }

  Future<void> _downloadSinglePost(int index) async {
    print('📥 MULTI POST: Starting download of single post at index $index');
    if (_multiPostData == null || index >= _multiPostData!.allUrls.length) {
      print('❌ MULTI POST: Invalid index or no data available for download');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadingIndex = index;
      _errorMessage = null;
    });

    try {
      final provider = context.read<DownloadProvider>();
      final post = _multiPostData!.allUrls[index];
      print('🚀 MULTI POST: Downloading post $index: ${post.mediaUrl}');
      
      // Create a temporary URL for this specific post
      final mediaUrl = post.mediaUrl;
      final isVideo = post.isVideo;
      final fileExtension = isVideo ? 'mp4' : 'jpg';
      
      // Generate filename
      final shortcode = InstagramUtils.extractShortcodeFromUrl(widget.reelUrl);
      final filename = '${isVideo ? "reel" : "story"}_${shortcode}_${index + 1}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Download using the download service
      final filePath = await _downloadService.downloadToGallery(
        mediaUrl: Uri.parse(mediaUrl),
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        suggestedName: filename,
      );

      // Create ReelItem
      final reelItem = ReelItem(
        id: '${shortcode}_${index + 1}',
        sourceUrl: widget.reelUrl,
        filePath: filePath,
        createdAt: DateTime.now(),
        thumbnailPath: isVideo ? post.url : filePath,
      );

      await provider.addItem(reelItem);

      if (mounted) {
        print('✅ MULTI POST: Post $index downloaded successfully, showing snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post ${index + 1} downloaded successfully')),
        );
        
        // Don't pop the screen - just reset the downloading state
        // Let the user decide when to go back
        setState(() {
          _isDownloading = false;
          _downloadingIndex = null;
          _downloadProgress = null;
        });
      }
    } catch (e) {
      print('❌ MULTI POST: Download of post $index failed with error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isDownloading = false;
          _downloadingIndex = null;
          _downloadProgress = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 MULTI POST: Building MultiPostScreen, isLoading: $_isLoading, hasError: ${_errorMessage != null}');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('🔙 MULTI POST: Back button pressed, popping screen');
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (_multiPostData != null && !_isDownloading)
            TextButton(
              onPressed: _downloadAllPosts,
              child: const Text('Download All'),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading posts',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadMultiPostData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _multiPostData == null
                    ? const Center(
                        child: Text('No posts available'),
                      )
                    : _buildContent(theme),
      ),
      bottomNavigationBar: _multiPostData != null && !_isLoading
          ? Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  print('🔙 MULTI POST: Done button pressed, popping screen');
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      children: [
        if (_isDownloading && _downloadingIndex != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Downloading post ${_downloadingIndex!} of ${_multiPostData!.allUrls.length}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_downloadProgress != null)
                      LinearProgressIndicator(
                        value: _downloadProgress,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _multiPostData!.allUrls.length,
            itemBuilder: (context, index) {
              final post = _multiPostData!.allUrls[index];
              final isDownloadingCurrent = _isDownloading && _downloadingIndex == index;
              
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Post image
                    Image.network(
                      post.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Video indicator
                    if (post.isVideo)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    
                    // Download button
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isDownloadingCurrent
                                ? Icons.downloading
                                : Icons.download,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: isDownloadingCurrent
                              ? null
                              : () => _downloadSinglePost(index),
                        ),
                      ),
                    ),
                    
                    // Overlay for downloading state
                    if (isDownloadingCurrent)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    
                    // Tap to preview - Place this last so it's on top
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isDownloadingCurrent
                              ? null
                              : () => _previewPost(index),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Preview a specific post
  Future<void> _previewPost(int index) async {
    if (_multiPostData == null || index >= _multiPostData!.allUrls.length) return;

    final post = _multiPostData!.allUrls[index];
    
    // Create InstagramPostData for preview
    final postData = InstagramPostData(
      id: 'post_$index',
      videoUrl: post.isVideo ? post.mediaUrl : null,
      displayUrl: post.url,
      isVideo: post.isVideo,
    );

    // Navigate to preview screen
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            reelUrl: widget.reelUrl,
            postData: postData,
          ),
        ),
      );
    }
  }
}