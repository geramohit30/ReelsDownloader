import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/instagram_types.dart';
import '../models/instagram_multi_post_data.dart';
import '../providers/download_provider.dart';
import '../services/local_api_service.dart';
import 'multi_post_screen.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.reelUrl,
    required this.postData,
  });

  final String reelUrl;
  final InstagramPostData postData;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _startedDownload = false;
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _initTried = false;
  bool _isWeb = false;

  @override
  void initState() {
    super.initState();
    // Check if we're running on web
    _isWeb = identical(0, 0.0); // This is a hack to detect web platform
    // Add a small delay to ensure proper initialization on web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeInitVideo();
    });
  }

  void _maybeInitVideo() async {
    if (_initTried) return;
    _initTried = true;
    final videoUrl = widget.postData.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    setState(() {
      _isInitializing = true;
    });
    
    // Add a small delay to ensure UI updates properly
    await Future.delayed(Duration(milliseconds: 50));

    try {
      // For web, we can only play network URLs, not local files
      if (_isWeb &&
          !(videoUrl.startsWith('http://') ||
              videoUrl.startsWith('https://'))) {
        // Skip video initialization for local files on web
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        return;
      }

      final c = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
      // Add timeout to prevent hanging
      await c.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          c.dispose();
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      c.setLooping(true);
      if (mounted) {
        setState(() {
          _controller = c;
          _isInitializing = false;
        });
      }
    } on TimeoutException catch (e) {
      print('Video initialization timeout: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview loading timed out. You can still download the content.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview loading failed. You can still download the content.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-initialize video if needed when widget is rebuilt
    if (!_initTried && mounted) {
      _maybeInitVideo();
    }
  }

  Future<void> _startDownload(BuildContext context) async {
    print('📥 PREVIEW: Starting download process');
    
    // For preview screen, we already have the post data, so we don't need to check for multiple posts again
    // unless the user specifically requests it
    
    // Regular single post download using the existing post data
    print('📥 PREVIEW: Starting single post download using existing data');
    final provider = context.read<DownloadProvider>();
    try {
      setState(() {
        _startedDownload = true;
      });
      
      // Add a small delay to ensure UI updates properly
      await Future.delayed(Duration(milliseconds: 100));
      
      await provider.downloadReel(widget.reelUrl);
      if (!mounted) return;
      print('✅ PREVIEW: Single post download completed, showing snackbar and popping');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download completed')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = provider.errorMessage ?? e.toString();
      print('❌ PREVIEW: Single post download failed: $message');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _startedDownload = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DownloadProvider>();
    
    // In preview screen, we should not show loading based on provider's global state
    // since the data is already fetched. Only show loading when we're actually downloading.
    final isBusy = _startedDownload || provider.isDownloading;
    final progress = provider.activeProgress;

    // Add a small delay to ensure UI updates properly on first load
    if (_isInitializing && !isBusy) {
      // This ensures the progress indicator shows up properly
      Future.microtask(() => setState(() {}));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        // Don't automatically pop when back button is pressed
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 400, // Fixed height instead of Expanded
                child: _buildMediaPreview(theme),
              ),
              const SizedBox(height: 16),
              // _buildMeta(theme),
              // const SizedBox(height: 24),
              _buildActionButtons(theme, isBusy, progress, provider),
              if (isBusy) ...[
                const SizedBox(height: 16),
                _buildProgress(theme, progress, provider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    bool isBusy,
    double? progress,
    DownloadProvider provider,
  ) {
    return Column(
      children: [
        // Check for multiple posts button (manual check)
        TextButton(
          onPressed: isBusy ? null : () => _checkForMultiplePosts(context),
          child: const Text('Check for multiple posts'),
        ),
        const SizedBox(height: 8),
        // Download button (downloads current post)
        _buildDownloadButton(theme, isBusy, progress, provider),
      ],
    );
  }

  Future<void> _checkForMultiplePosts(BuildContext context) async {
    print('🔍 PREVIEW: Manually checking for multiple posts (user initiated)');
    try {
      final multiPostData = await LocalApiService.fetchMultipleInstagramPosts(widget.reelUrl);
      if (multiPostData.allUrls.length > 1) {
        print('🟢 PREVIEW: Multiple posts found (${multiPostData.allUrls.length}), navigating to MultiPostScreen');
        // Navigate to multi-post screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiPostScreen(reelUrl: widget.reelUrl),
          ),
        );
        print('🔙 PREVIEW: Returned from MultiPostScreen with result: $result');

        // Show a message when returning from MultiPostScreen
        if (result == true) {
          print('✅ PREVIEW: Posts downloaded successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Posts downloaded successfully')),
            );
          }
        }
      } else {
        print('🟡 PREVIEW: Only single post found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only one post found')),
          );
        }
      }
    } catch (e) {
      print('❌ PREVIEW: Error checking for multiple posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking for multiple posts: $e')),
        );
      }
    }
  }

  Widget _buildMediaPreview(ThemeData theme) {
    final hasController =
        _controller != null && _controller!.value.isInitialized;
    final displayUrl = widget.postData.displayUrl;
    final hasVideoUrl = widget.postData.videoUrl?.isNotEmpty ?? false;
    final isVideo = widget.postData.isVideo;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 60),
      decoration: BoxDecoration(
        // color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: AspectRatio(
          aspectRatio: hasController ? _controller!.value.aspectRatio : 9 / 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasController)
                  GestureDetector(
                    onTap: () {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                      setState(() {});
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(_controller!),
                        if (!_controller!.value.isPlaying)
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else if (hasVideoUrl && !_isWeb)
                  // Clean placeholder when a video URL exists; avoid showing the image first
                  Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Preparing preview...',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (displayUrl != null && displayUrl.isNotEmpty)
                  Image.network(
                    displayUrl,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      );
                    },
                  )
                else if (isVideo)
                  // Show video placeholder when no thumbnail is available
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Video Preview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Download to view and save video',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Show image placeholder when no thumbnail is available
                  Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Image Preview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Download to view and save image',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_isInitializing)
                  Container(
                    color: Colors.black.withOpacity(0.05),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),

                if (!hasController && hasVideoUrl && !_isWeb)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tap to play',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(ThemeData theme) {
    final username = widget.postData.username ?? 'Instagram User';
    final caption = widget.postData.caption;

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'I',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.postData.shortcode != null)
                        Text(
                          'Shortcode: ${widget.postData.shortcode}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (caption != null && caption.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                caption,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
    ThemeData theme,
    bool isBusy,
    double? progress,
    DownloadProvider provider,
  ) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isBusy
                  ? [
                    theme.colorScheme.onSurface.withOpacity(0.35),
                    theme.colorScheme.onSurface.withOpacity(0.45),
                  ]
                  : [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isBusy ? Colors.grey : theme.colorScheme.primary)
                .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : () => _startDownload(context),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(Icons.download_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  isBusy
                      ? (_startedDownload 
                          ? (progress == null
                              ? 'Preparing...'
                              : 'Downloading ${(progress * 100).toStringAsFixed(0)}%')
                          : 'Starting...')
                      : 'Download Current Post',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(
    ThemeData theme,
    double? progress,
    DownloadProvider provider,
  ) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_download_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  provider.isFetchingPreview
                      ? 'Fetching reel data...'
                      : progress == null
                      ? 'Preparing download...'
                      : 'Downloading ${(progress * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: provider.isFetchingPreview ? null : progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
