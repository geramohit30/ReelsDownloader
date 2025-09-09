import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reel_item.dart';
import '../providers/download_provider.dart';

/// An image viewer screen for displaying downloaded Instagram Stories
/// with zoom, sharing functionality, and custom controls.
class ImageViewerScreen extends StatefulWidget {
  final String itemId;

  const ImageViewerScreen({super.key, required this.itemId});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with TickerProviderStateMixin {
  ReelItem? _item;
  bool _isControlsVisible = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  TransformationController _transformationController = TransformationController();

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
    _fadeController.forward();
    _hideControlsAfterDelay();
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

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Image Viewer with zoom
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.file(
                        File(_item!.filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildErrorWidget(theme);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Top Controls
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildTopControls(theme),
            ),
            // Bottom Controls
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildBottomControls(theme),
            ),
          ],
        ),
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
          Icon(Icons.broken_image_outlined, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'The image file might be corrupted',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.6),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            _buildControlButton(
              icon: Icons.arrow_back_ios_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              theme: theme,
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Instagram Story',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _buildControlButton(
              icon: Icons.share_rounded,
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Share.shareXFiles([XFile(_item!.filePath)]);
              },
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.zoom_in_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                final Matrix4 matrix = Matrix4.copy(_transformationController.value);
                matrix.scale(1.2);
                _transformationController.value = matrix;
              },
              theme: theme,
              label: 'Zoom In',
            ),
            _buildControlButton(
              icon: Icons.zoom_out_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                final Matrix4 matrix = Matrix4.copy(_transformationController.value);
                matrix.scale(0.8);
                _transformationController.value = matrix;
              },
              theme: theme,
              label: 'Zoom Out',
            ),
            _buildControlButton(
              icon: Icons.center_focus_strong_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                _resetZoom();
              },
              theme: theme,
              label: 'Reset',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
    String? label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}