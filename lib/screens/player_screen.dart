import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_item.dart';
import '../providers/download_provider.dart';
import '../widgets/video_controller_factory.dart';

/// A video player screen for displaying downloaded Instagram Reels
/// with custom controls, progress overlay, and sharing functionality.
class PlayerScreen extends StatefulWidget {
  final String itemId;

  const PlayerScreen({super.key, required this.itemId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  ReelItem? _item;
  bool _isControlsVisible = true;
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    final provider = context.read<DownloadProvider>();
    _item = provider.items.firstWhere((e) => e.id == widget.itemId);
    _initializeVideo();
    _hideControlsAfterDelay();
  }

  void _initializeVideo() async {
    _controller = createVideoController(_item!.filePath);
    await _controller!.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _fadeController.forward();
      _controller!.play();
    }
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isControlsVisible) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    if (_isControlsVisible) {
      _hideControlsAfterDelay();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady = _controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Player
            Center(
              child:
                  _isLoading
                      ? _buildLoadingWidget(theme)
                      : isReady
                      ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: GestureDetector(
                          onTap: _toggleControls,
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              children: [
                                ClipRect(child: VideoPlayer(_controller!)),
                                // Progress bar overlaid on video
                                _buildVideoOverlayProgressBar(theme),
                              ],
                            ),
                          ),
                        ),
                      )
                      : _buildErrorWidget(theme),
            ),
            // Top Controls
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildTopControls(theme),
            ),
            // Center Control Buttons
            if (isReady)
              AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildCenterControls(theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load video',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'The video file might be corrupted',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => _shareVideo(),
                icon: const Icon(Icons.share_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => _showVideoInfo(),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomProgressBar(ThemeData theme) {
    final isReady = _controller?.value.isInitialized ?? false;
    if (!isReady) return const SizedBox();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_controller!.value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
                Text(
                  _formatDuration(_controller!.value.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: theme.colorScheme.primary,
                  bufferedColor: Colors.white.withOpacity(0.4),
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTimeDisplay(ThemeData theme) {
    final isReady = _controller?.value.isInitialized ?? false;
    if (!isReady) return const SizedBox();

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_controller!.value.position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
            Text(
              _formatDuration(_controller!.value.duration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(ThemeData theme) {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.replay_10_rounded,
                onPressed: () => _seekRelative(-10),
                isLarge: true,
              ),
              _buildControlButton(
                icon:
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                onPressed: _togglePlayPause,
                isLarge: true,
                isMainButton: true,
              ),
              _buildControlButton(
                icon: Icons.forward_10_rounded,
                onPressed: () => _seekRelative(10),
                isLarge: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // CONTROL BUTTON BUILDER
  // ============================================================================

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isLarge = false,
    bool isMainButton = false,
  }) {
    final size = isMainButton ? 80.0 : (isLarge ? 60.0 : 48.0);
    final iconSize = isMainButton ? 40.0 : (isLarge ? 28.0 : 24.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isMainButton ? 0.7 : 0.5),
        shape: BoxShape.circle,
        border:
            isMainButton
                ? Border.all(color: Colors.white.withOpacity(0.3), width: 2)
                : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: iconSize),
        iconSize: size,
      ),
    );
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
    _hideControlsAfterDelay();
  }

  void _seekRelative(int seconds) {
    HapticFeedback.lightImpact();
    final currentPosition = _controller!.value.position;
    final newPosition = currentPosition + Duration(seconds: seconds);
    final duration = _controller!.value.duration;

    if (newPosition < Duration.zero) {
      _controller!.seekTo(Duration.zero);
    } else if (newPosition > duration) {
      _controller!.seekTo(duration);
    } else {
      _controller!.seekTo(newPosition);
    }
    _hideControlsAfterDelay();
  }

  void _shareVideo() async {
    HapticFeedback.lightImpact();
    await Share.shareXFiles([XFile(_item!.filePath)]);
  }

  // ============================================================================
  // VIDEO INFO DIALOG
  // ============================================================================

  void _showVideoInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Video Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    'Duration',
                    _formatDuration(_controller!.value.duration),
                  ),
                  _buildInfoRow(
                    'Resolution',
                    '${_controller!.value.size.width.toInt()}x${_controller!.value.size.height.toInt()}',
                  ),
                  _buildInfoRow('Downloaded', _formatDate(_item!.createdAt)),
                  _buildInfoRow('File Size', _getFileSize()),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getFileSize() {
    try {
      final file = File(_item!.filePath);
      final sizeInBytes = file.lengthSync();
      if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // ============================================================================
  // VIDEO OVERLAY PROGRESS BAR
  // ============================================================================

  Widget _buildVideoOverlayProgressBar(ThemeData theme) {
    final isReady = _controller?.value.isInitialized ?? false;
    if (!isReady) return const SizedBox();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_controller!.value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(_controller!.value.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress Bar
            Container(
              height: 3,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: theme.colorScheme.primary,
                  bufferedColor: Colors.white.withOpacity(0.4),
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
