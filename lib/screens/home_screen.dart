import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/download_provider.dart';
import '../services/instagram_utils.dart';
import 'network_test_screen.dart';
import 'preview_screen.dart';

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
    if (v == null || v
        .trim()
        .isEmpty) return 'Paste a reel URL';
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

      // Navigate to preview screen
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: AnimationLimiter(
                child: ListView(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 400),
                    childAnimationBuilder:
                        (widget) =>
                        SlideAnimation(
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
                      if (isBusy)
                        ..._buildProgressIndicator(theme, progress, provider),
                      const SizedBox(height: 40),
                      _buildRecentDownloads(theme, provider),
                      if (kIsWeb) ...[  
                        const SizedBox(height: 24),
                        _buildWebDownloadInfo(theme),
                      ],
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
                        ? 'Download Instagram Reels & Stories to your browser'
                        : 'Download Instagram Reels effortlessly',
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

  Widget _buildDownloadButton(ThemeData theme,
      bool isBusy,
      DownloadProvider provider,) {
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

  List<Widget> _buildProgressIndicator(ThemeData theme,
      double? progress,
      DownloadProvider provider,) {
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
                    // This would switch to downloads tab
                    // For now, just show a message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Go to Downloads tab to see all'),
                      ),
                    );
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
                itemCount: provider.items
                    .take(5)
                    .length,
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
                                          theme.colorScheme.primary.withOpacity(0.8),
                                          theme.colorScheme.secondary.withOpacity(0.8),
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
              '• Files will be automatically named with timestamps\n'
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
}
