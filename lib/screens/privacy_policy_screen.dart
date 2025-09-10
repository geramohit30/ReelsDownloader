import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme, context),
              Expanded(child: _buildContent(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Us',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Instagram Reel Download',
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

  Widget _buildContent(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 8,
        shadowColor: theme.colorScheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLastUpdated(theme),
              const SizedBox(height: 24),
              _buildSection(
                theme,
                'About Us',
                Icons.home_rounded,
                [
                  'Welcome to Instagram Reel Download — your simple, fast, and secure way to save Instagram reels directly to your device.',
                  'Our platform, https://instagramreeldownload.com, is designed to make downloading your favorite reels effortless, without compromising on quality.',
                  'We believe your favorite content should always be at your fingertips. Whether you want to keep reels offline, share them with friends, or use them for inspiration, our tool makes the process seamless and reliable.',
                  'Download it. Save it. Keep it.',
                ],
              ),
              _buildSection(theme, 'Our Mission', Icons.flag_rounded, [
                'Our mission is to provide a hassle-free, user-friendly, and secure reel downloading experience.',
                'By combining clean design with efficient technology, we help you save reels in just a few clicks — quickly, safely, and without unnecessary ads or distractions.',
              ]),
              _buildSection(theme, 'What Sets Us Apart', Icons.star_rounded, [
                'Instant Downloads – Save Instagram reels within seconds',
                'High-Quality Saves – Keep the original clarity of videos',
                'No Login Required – Simply paste the reel link and download',
                'Free & Easy – A smooth, minimal, and distraction-free interface',
              ]),
              _buildSection(theme, 'Contact Us', Icons.contact_mail_rounded, [
                'For inquiries, suggestions, or collaborations, feel free to reach out at : '
                '📧 instagramreeldownloadapp@gmail.com',
              ]),
              _buildSection(theme, 'Privacy Policy', Icons.privacy_tip_rounded, [
                'Who We Are : '
                'Our website address is: https://instagramreeldownload.com',
                'Instagram Reel Download is dedicated to providing a secure and convenient way to save Instagram reels. This Privacy Policy outlines how we collect, use, and protect your personal information while you use our website.',
                'Information Collection and Use : '
                'We do not require login or collect personal information for reel downloads. If you voluntarily provide details (e.g., via email contact), it may only be used for support or communication purposes. We do not sell or share your information with third parties, except where required by law.',
              ]),
              _buildSection(theme, 'Cookies', Icons.cookie, [
                'Our site may use cookies and similar technologies to:',
                'Enhance browsing experience',
                'Understand usage patterns',
                'Improve website functionality',
                'You can disable cookies through your browser settings if preferred.'
              ]),
            _buildSection(theme, 'Security', Icons.security, [
                'We value your trust and follow standard practices to protect your data. However, please note that no digital storage or transmission method is 100% secure.',
                'Changes to This Policy : '
                'This Privacy Policy is effective as of September 09, 2025 and may be updated periodically. Continued use of our site means you accept the revised policy.',
              ]),
              // _buildSection(
              //   theme,
              //   'Terms and Conditions',
              //   Icons.gavel_rounded,
              //   ['Effective Date: September 09, 2025'],
              // ),
              const SizedBox(height: 16),
              _buildDisclaimer(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastUpdated(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Last updated: September 09, 2025',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<String> content,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.5,
                      ),
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

  Widget _buildDisclaimer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Disclaimer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Instagram Reel Download provides a simple tool for downloading Instagram reels using publicly available content.\n\n• We are not affiliated, endorsed, or partnered with Instagram.\n• Users are responsible for ensuring compliance with Instagram\'s policies and respecting the intellectual property rights of content creators.\n• We do not host or store Instagram content — all downloads are processed directly by the user through provided links.\n• Use of our platform is at your own risk.\n\nContact: For questions related to this Disclaimer, please contact us at: 📧 instagramreeldownloadapp@gmail.com',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
