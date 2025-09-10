import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
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
              _buildHeader(theme),
              Expanded(
                child: AnimationLimiter(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 400),
                      childAnimationBuilder:
                          (widget) => SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        // _buildGeneralSection(theme, context),
                        // const SizedBox(height: 20),
                        _buildDownloadSection(theme, context),
                        const SizedBox(height: 20),
                        _buildAppearanceSection(theme, context),
                        const SizedBox(height: 20),
                        _buildAboutSection(theme, context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
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
              Icons.settings_rounded,
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
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Customize your experience',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(ThemeData theme, BuildContext context) {
    return _buildSection(
      title: 'General',
      icon: Icons.tune_rounded,
      theme: theme,
      children: [
        _buildSettingsTile(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Download completion alerts',
          trailing: Switch(
            value: true,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              _showFeatureComingSoon(context);
            },
          ),
          onTap: null,
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.auto_delete_rounded,
          title: 'Auto Delete',
          subtitle: 'Remove downloads after 30 days',
          trailing: Switch(
            value: false,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              _showFeatureComingSoon(context);
            },
          ),
          onTap: null,
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.language_rounded,
          title: 'Language',
          subtitle: 'English (US)',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () => _showFeatureComingSoon(context),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildDownloadSection(ThemeData theme, BuildContext context) {
    return _buildSection(
      title: 'Downloads',
      icon: Icons.download_rounded,
      theme: theme,
      children: [
        _buildSettingsTile(
          icon: Icons.folder_rounded,
          title: 'Download Location',
          subtitle: 'App Documents',
          trailing: SizedBox.shrink(),
          onTap: null,
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.high_quality_rounded,
          title: 'Video Quality',
          subtitle: 'Best Available',
          trailing: SizedBox.shrink(),
          onTap: null,
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.wifi_rounded,
          title: 'Download over WiFi only',
          subtitle: 'Save mobile data',
          trailing: SizedBox.shrink(),
          onTap: null,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeData theme, BuildContext context) {
    return _buildSection(
      title: 'Appearance',
      icon: Icons.palette_rounded,
      theme: theme,
      children: [
        _buildSettingsTile(
          icon: Icons.dark_mode_rounded,
          title: 'Theme',
          subtitle: 'System Default',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () => _showThemeSelector(context),
          theme: theme,
        ),
        // _buildSettingsTile(
        //   icon: Icons.grid_view_rounded,
        //   title: 'Grid Layout',
        //   subtitle: '2 columns',
        //   trailing: Icon(
        //     Icons.chevron_right_rounded,
        //     color: theme.colorScheme.onSurface.withOpacity(0.6),
        //   ),
        //   onTap: () => _showFeatureComingSoon(context),
        //   theme: theme,
        // ),
      ],
    );
  }

  Widget _buildAboutSection(ThemeData theme, BuildContext context) {
    return _buildSection(
      title: 'About',
      icon: Icons.info_rounded,
      theme: theme,
      children: [
        _buildSettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'App Info',
          subtitle: 'Version 1.0.0',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () => _showAppInfo(context),
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          subtitle: 'How we protect your data',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyScreen(),
              ),
            );
          },
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.support_rounded,
          title: 'Support',
          subtitle: 'Get help and send feedback',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () => _showSupport(context),
          theme: theme,
        ),
        _buildSettingsTile(
          icon: Icons.star_rounded,
          title: 'Rate App',
          subtitle: 'Show some love ❤️',
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onTap: () => _showFeatureComingSoon(context),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeatureComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This feature is coming soon! 🚀'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Theme',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildThemeOption(
              context,
              'System Default',
              Icons.brightness_auto,
              true,
            ),
            _buildThemeOption(context, 'Light', Icons.light_mode, false),
            _buildThemeOption(context, 'Dark', Icons.dark_mode, false),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
      BuildContext context,
      String title,
      IconData icon,
      bool isSelected,
      ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing:
      isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(context);
        _showFeatureComingSoon(context);
      },
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.download_for_offline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Insta Reel\nDownloader',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Built with Flutter'),
            SizedBox(height: 16),
            Text(
              'This app allows you to download Instagram Reels for offline viewing. Please respect content creators and use downloaded content responsibly.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSupport(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Support & Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help or have suggestions?'),
            SizedBox(height: 16),
            Text('• Report bugs'),
            Text('• Request features'),
            Text('• General support'),
            SizedBox(height: 16),
            Text(
              'Contact us through the app store or our website.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail(context);
            },
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'instagramreeldownloadapp@gmail.com',
      queryParameters: {
        'subject': 'Instagram Reel Downloader - Support Request',
        'body':
        'Hello,\n\nI have a question/suggestion regarding the Instagram Reel Downloader app:\n\n',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw Exception('Could not launch email client');
      }
    } catch (e) {
      // If email client can't be opened, show an error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open email client. Please email us at: instagramreeldownloadapp@gmail.com',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
