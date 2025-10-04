import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/download_provider.dart';
import '../providers/navigation_provider.dart';
import 'player_screen.dart';
import 'image_viewer_screen.dart';

// Import for XFile
import 'package:cross_file/cross_file.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final items = provider.items;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.05),
                  theme.colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(theme, items.length, context),
                  Expanded(
                    child: items.isEmpty
                        ? _buildEmptyState(theme, context)
                        : _buildDownloadGrid(items, theme, context),
                  ),
                ],
              ),
            ),
          ),
          // Hamburger menu that scrolls with content
          if (kIsWeb)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: PopupMenuButton<int>(
                  icon: const Icon(Icons.menu, size: 30),
                  onSelected: (index) {
                    // Use the NavigationProvider to switch tabs
                    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                    navigationProvider.switchToTab(index);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: ListTile(
                        leading: Icon(Icons.home),
                        title: Text('Home'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: ListTile(
                        leading: Icon(Icons.video_library),
                        title: Text('Downloads'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 2,
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, int itemCount, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.download_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downloads',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'} saved',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (itemCount > 0)
            IconButton(
              onPressed: () => _showSortOptions(context),
              icon: Icon(Icons.sort_rounded, color: theme.colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              kIsWeb ? 'No downloads yet' : 'No downloads yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              kIsWeb 
                ? 'Downloaded Instagram content will be saved to your browser\'s download folder.\nGo to Home tab to start downloading!'
                : 'Downloaded Instagram content will appear here.\nGo to Home tab to start downloading!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Go to Home tab to download reels'),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Start Downloading',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadGrid(List items, ThemeData theme, BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 500),
            columnCount: _getCrossAxisCount(context),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildVideoCard(items[index], theme, context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(dynamic item, ThemeData theme, BuildContext context) {
    // For web, show that files are downloaded to browser's downloads folder
    final isImage = item.filePath.toLowerCase().endsWith('.jpg') || 
                   item.filePath.toLowerCase().endsWith('.jpeg');
    final contentType = isImage ? 'Story' : 'Reel';

    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.secondary.withOpacity(0.8),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (kIsWeb) {
                _showWebInfoDialog(context, item, theme, isImage);
              } else {
                _navigateToViewer(context, item, isImage);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Thumbnail or placeholder
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FutureBuilder(
                        future: _loadThumbnail(item, isImage),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return snapshot.data!;
                          } else if (snapshot.hasError) {
                            return _buildPlaceholderIcon(isImage, theme);
                          } else {
                            return _buildPlaceholderIcon(isImage, theme);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                // Content info
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isImage ? Colors.orange.withOpacity(0.9) : Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImage ? Icons.image_rounded : Icons.video_library_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          contentType,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action buttons
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildActionButton(
                    icon: kIsWeb ? Icons.download_rounded : Icons.share_rounded,
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      if (kIsWeb) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'File downloaded to your browser\'s download folder',
                            ),
                            action: SnackBarAction(
                              label: 'OK',
                              onPressed: () {},
                            ),
                          ),
                        );
                      } else {
                        await Share.shareXFiles([XFile(item.filePath)]);
                      }
                    },
                    theme: theme,
                  ),
                ),
                Positioned(
                  top: 60,
                  right: 12,
                  child: _buildActionButton(
                    icon: Icons.delete_rounded,
                    onPressed: () => _showDeleteDialog(context, item, theme),
                    theme: theme,
                  ),
                ),
                // Bottom info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kIsWeb ? 'Downloaded to browser' : (isImage ? 'Tap to view' : 'Tap to play'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
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

  void _navigateToViewer(BuildContext context, dynamic item, bool isImage) {
    if (isImage) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ImageViewerScreen(itemId: item.id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
        ),
      );
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PlayerScreen(itemId: item.id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  void _showWebInfoDialog(BuildContext context, dynamic item, ThemeData theme, bool isImage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              isImage ? Icons.image_rounded : Icons.video_library_rounded, 
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text('${isImage ? "Story" : "Reel"} Downloaded'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your ${isImage ? "story" : "reel"} has been downloaded to your browser\'s download folder.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your Downloads folder to access the file.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        iconSize: 36,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic item, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_rounded, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Delete Item'),
          ],
        ),
        content: Text(
          kIsWeb 
            ? 'Remove this item from the list? The file has already been downloaded to your device.'
            : 'Are you sure you want to delete this item? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<DownloadProvider>().deleteItem(item.id);
                HapticFeedback.lightImpact();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(kIsWeb ? 'Item removed from list' : 'Video deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    // Implement sort options
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sort options coming soon!'),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isImage, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.6),
            theme.colorScheme.secondary.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isImage ? Icons.image_rounded : Icons.movie_rounded,
          size: 48,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Future<Widget?> _loadThumbnail(dynamic item, bool isImage) async {
    try {
      // Check if thumbnail exists
      if (item.thumbnailPath != null && item.thumbnailPath.isNotEmpty) {
        final file = File(item.thumbnailPath);
        if (await file.exists()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderIcon(isImage, Theme.of(context));
            },
          );
        }
      }
      
      // If no thumbnail, try to use the main file for images
      if (isImage) {
        final file = File(item.filePath);
        if (await file.exists()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderIcon(isImage, Theme.of(context));
            },
          );
        }
      }
      
      // Return placeholder if no valid image
      return null;
    } catch (e) {
      print('Error loading thumbnail: $e');
      return null;
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }
}