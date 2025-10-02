import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/download_provider.dart';
import '../services/instagram_utils.dart';
import '../models/instagram_types.dart';
import 'network_test_screen.dart';
import 'preview_screen.dart';
import 'downloads_screen.dart';
import '../main.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Conditional import for platform-specific file operations
import 'downloads_screen_io_stub.dart'
    if (dart.library.io) 'downloads_screen_io.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    if (v == null || v.trim().isEmpty) return 'Paste a reel URL';
    final s = v.trim();
    if (!InstagramUtils.isInstagramUrl(s)) {
      return 'Please enter a valid Instagram reel or story URL';
    }
    return null;
  }

  Future<void> _onDownload() async {
    final provider = context.read<DownloadProvider>();
    final input = _ctrl.text.trim();
    if (!_formKey.currentState!.validate()) return;

    try {
      // Use fetchReelForPreview which now includes automatic fallback
      // Instagram service first, Local API as backup if Instagram fails
      final postData = await provider.fetchReelForPreview(input);

      if (!mounted) return;

      // For web, display preview content and automatically start download
      // For mobile, navigate to preview screen as before
      if (kIsWeb) {
        // Preview will be displayed in the UI directly
        setState(() {
          // Just trigger a rebuild to show the preview
        });
        
        // Automatically start download after preview is fetched
        await provider.downloadReel(input);
        
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started! Check your browser\'s download folder or look for a download prompt.'),
            duration: Duration(seconds: 5),
          ),
        );
        
        // Clear the input after successful download start
        _ctrl.clear();
      } else {
        // Navigate to preview screen for mobile
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PreviewScreen(reelUrl: input, postData: postData),
          ),
        );

        // If download was successful, clear the input
        if (result == true) {
          _ctrl.clear();
        }
      }
    } catch (e) {
      if (!mounted) return;

      final isNetworkError =
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network error') ||
          e.toString().contains('Local API server');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: ${e.toString()}'),
              if (isNetworkError) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NetworkTestScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Run Network Diagnostics',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: isNetworkError ? 8 : 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final isBusy = provider.isDownloading || provider.isFetchingPreview;
    final progress = provider.activeProgress;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: kIsWeb
              ? _buildWebLayout(theme, provider, isBusy, progress)
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: AnimationLimiter(
                      child: ListView(
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 400),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            const SizedBox(height: 20),
                            _buildHeader(theme),
                            const SizedBox(height: 40),
                            _buildUrlInputCard(theme, isBusy),
                            const SizedBox(height: 24),
                            _buildDownloadButton(theme, isBusy, provider),
                            if (isBusy) ..._buildProgressIndicator(theme, progress, provider),
                            const SizedBox(height: 40),
                            _buildRecentDownloads(theme, provider),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.download_for_offline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instagram Reel Downloader',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kIsWeb
                          ? 'Download Instagram Reel, Photo, Carousel & Story effortlessly'
                          : 'Download Instagram Reel, Photo, Carousel & Story effortlessly',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInputCard(ThemeData theme, bool isBusy) {
    return Card(
      color: theme.cardColor,
      elevation: 0.5,
      shadowColor: theme.colorScheme.primary.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paste Insta Reel/Story URL',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              enabled: !isBusy,
              decoration: InputDecoration(
                hintText: 'https://www.instagram.com/reel/... or /stories/...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                prefixIcon: Icon(Icons.link, color: theme.colorScheme.primary),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.paste_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed:
                        isBusy
                            ? null
                            : () async {
                              HapticFeedback.lightImpact();
                              final data = await Clipboard.getData(
                                'text/plain',
                              );
                              if (data?.text != null) {
                                _ctrl.text = data!.text!.trim();
                              }
                            },
                  ),
                ),
              ),
              validator: _validateUrl,
              maxLines: 1,
              minLines: 1,

              onFieldSubmitted: (_) {
                if (!isBusy) {
                  HapticFeedback.mediumImpact();
                  _onDownload();
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Paste a public Instagram Reel or Story link to download',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
    ThemeData theme,
    bool isBusy,
    DownloadProvider provider,
  ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isBusy
                  ? [
                    theme.colorScheme.onSurface.withOpacity(0.4),
                    theme.colorScheme.onSurface.withOpacity(0.5),
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
          onTap:
              isBusy
                  ? null
                  : () {
                    HapticFeedback.mediumImpact();
                    _onDownload();
                  },
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
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  isBusy
                      ? (provider.isFetchingPreview
                          ? 'Fetching...'
                          : 'Processing...')
                      : 'Download Reel',
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

  List<Widget> _buildProgressIndicator(
    ThemeData theme,
    double? progress,
    DownloadProvider provider,
  ) {
    return [
      const SizedBox(height: 24),
      Card(
        color: theme.cardColor,
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    provider.isFetchingPreview
                        ? 'Fetching reel data...'
                        : progress == null
                        ? 'Preparing download...'
                        : 'Downloading ${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: provider.isFetchingPreview ? null : progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildRecentDownloads(ThemeData theme, DownloadProvider provider) {
    if (provider.items.isEmpty) {
      return Card(
        color: theme.cardColor,
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'No downloads yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Downloaded reels will appear here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.cardColor,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Recent Downloads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Switch to downloads tab instead of pushing new screen
                    final rootState =
                        context.findAncestorStateOfType<RootState>();
                    rootState?.switchToTab(
                      1,
                    ); // 1 is the index for downloads tab
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: provider.items.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final item = provider.items[index];
                  final hasThumb = fileExists(item.thumbnailPath);
                  return Container(
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloaded: ${item.id}')),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasThumb)
                                buildThumbnail(
                                  item.thumbnailPath,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.primary.withOpacity(
                                            0.8,
                                          ),
                                          theme.colorScheme.secondary
                                              .withOpacity(0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primary.withOpacity(
                                          0.8,
                                        ),
                                        theme.colorScheme.secondary.withOpacity(
                                          0.8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDownloadInfo(ThemeData theme) {
    return Card(
      elevation: 0.5,
      color: theme.colorScheme.primary.withOpacity(0.05),
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Web Download Info',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• Downloads are saved to your browser\'s default download folder\n'
              '• For best experience, allow browser downloads when prompted\n'
              '• Some browsers may ask for permission before downloading',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build web layout (constrained width, mobile-like)
  Widget _buildWebLayout(ThemeData theme, DownloadProvider provider,
      bool isBusy, double? progress) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(theme),
                  const SizedBox(height: 40),
                  _buildUrlInputCard(theme, isBusy),
                  const SizedBox(height: 24),
                  _buildDownloadButton(theme, isBusy, provider),
                  if (isBusy) ..._buildProgressIndicator(theme, progress, provider),
                  // Add preview content for web directly below download button
                  if (provider.previewData != null) ...[
                    const SizedBox(height: 24),
                    _buildWebPreview(provider.previewData!, theme, context),
                  ] else if (!isBusy && provider.previewData == null && _ctrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildNoPreviewMessage(theme),
                  ],
                  const SizedBox(height: 40),
                  _buildRecentDownloads(theme, provider),
                  const SizedBox(height: 24),
                  _buildWebDownloadInfo(theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build a message when no preview is available
  Widget _buildNoPreviewMessage(ThemeData theme) {
    final provider = context.watch<DownloadProvider>();
    
    String message = 'Enter an Instagram URL above and click Download to preview content';
    
    // Add more specific debugging information
    if (provider.previewData != null) {
      if (provider.previewData!.displayUrl == null && provider.previewData!.videoUrl != null) {
        message = 'Preview data received but no thumbnail available. Video will be playable after download.';
      } else if (provider.previewData!.displayUrl!.isEmpty) {
        message = 'Preview data received but thumbnail URL is empty';
      } else {
        message = 'Preview data available but not displayed';
      }
    }
    
    return Card(
      color: theme.cardColor,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build media preview based on content type (image/video)
  Widget _buildMediaPreview(InstagramPostData postData, ThemeData theme) {
    final mediaUrl = postData.displayUrl ?? postData.videoUrl;
    final isVideo = postData.isVideo;
    
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      // For web, we show a simpler preview without trying to play videos
      if (kIsWeb) {
        if (isVideo) {
          // For videos on web, show a video placeholder
          return _buildVideoPlaceholder(theme);
        } else {
          // For images on web, try to show the image
          return _buildImagePreview(mediaUrl, theme, isVideo);
        }
      }
      
      // For mobile, use the existing logic
      // Check if it's a video URL
      if (mediaUrl.contains('.mp4') || mediaUrl.contains('.mov') || mediaUrl.contains('video')) {
        // For videos, show a video player preview
        return _buildVideoPlayerPreview(mediaUrl, theme);
      } else {
        // For images, show image preview
        return _buildImagePreview(mediaUrl, theme, isVideo);
      }
    } else {
      // No URL available - show appropriate placeholder
      return isVideo ? _buildVideoPlaceholder(theme) : _buildImagePlaceholder(theme);
    }
  }
  
  /// Build image preview widget
  Widget _buildImagePreview(String imageUrl, ThemeData theme, bool isVideo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stack) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview failed to load',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (isVideo)
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
      ],
    );
  }
  
  /// Build video placeholder when no thumbnail is available
  Widget _buildVideoPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Video Preview',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Download to view video',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build image placeholder when no image is available
  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Image Preview',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Download to view image',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build video player preview widget
  Widget _buildVideoPlayerPreview(String videoUrl, ThemeData theme) {
    // For web, we'll show a message indicating that users can download to see the preview
    if (kIsWeb) {
      return Container(
        height: 300,
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
                'Video Preview Available',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Download the video to view and save it to your device',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Video URL ready for download',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // For mobile, we can try to initialize a video player
    // ... existing mobile implementation
    // (I'll keep this simple for now since the focus is on web)
    return Container(
      height: 300,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_fill,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'Video Preview',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to build the web preview
  Widget _buildWebPreview(InstagramPostData postData, ThemeData theme, BuildContext context) {
    return Card(
      color: theme.cardColor,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview media display
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMediaPreview(postData, theme),
              ),
            ),
            const SizedBox(height: 16),
            // Information text for web
            if (kIsWeb) ...[
              Text(
                postData.isVideo 
                  ? 'Your video is being downloaded to your device' 
                  : 'Your image is being downloaded to your device',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Add download location information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Download Information',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Your browser may ask where to save the file\n'
                      '• Check your Downloads folder if files don\'t appear immediately\n'
                      '• Some browsers preview media files instead of downloading them\n'
                      '• If download fails, try right-clicking and selecting "Save Link As..."',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Remove the Download to Device button since download happens automatically
          ],
        ),
      ),
    );
  }
}
