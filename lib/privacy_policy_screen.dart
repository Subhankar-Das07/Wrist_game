import 'package:flutter/material.dart';

/// Privacy Policy & Terms of Use screen
///
/// Required for Google Play Store compliance when using camera permission.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Privacy Policy & Terms', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Privacy Policy'),
            _Body('Last Updated: August 2026'),
            SizedBox(height: 16),
            _SubHeader('1. Overview'),
            _Body(
              'Jesture ("we", "the app") is a hand-tracking motion game that uses your device\'s front camera to detect fist movements in real time. '
              'We are deeply committed to your privacy.',
            ),
            _SubHeader('2. Camera Usage'),
            _Body(
              '• The front camera is used EXCLUSIVELY for real-time hand and fist landmark detection.\n'
              '• All camera processing happens completely on your device — no frames, images, or video are ever recorded, saved, uploaded, or transmitted to any server.\n'
              '• We have no access to your camera feed at any time.',
            ),
            _SubHeader('3. Data We Collect'),
            _Body(
              '• Game scores (stored locally on your device only using SharedPreferences).\n'
              '• We do NOT collect names, emails, phone numbers, location data, or any personal information.\n'
              '• We do NOT use analytics or third-party tracking SDKs.',
            ),
            _SubHeader('4. Payment Data'),
            _Body(
              'If you choose to unlock premium content, payment is processed securely by Razorpay. '
              'We do not store any payment card details. Razorpay\'s privacy policy applies to all payment transactions.',
            ),
            _SubHeader('5. Third-Party Libraries'),
            _Body(
              '• MediaPipe (by Google) — on-device AI hand landmark detection. No data leaves the device.\n'
              '• Razorpay — payment processing (only used for premium unlock purchases).\n'
              '• Flutter & Flame — app framework and game engine.',
            ),
            _SubHeader('6. Children\'s Privacy'),
            _Body(
              'Jesture does not knowingly collect personal information from children under 13. '
              'The app is suitable for all ages as it does not contain mature content.',
            ),
            _SubHeader('7. Contact Us'),
            _Body(
              'If you have any questions about this Privacy Policy, please contact us at:\n'
              'support@jesturegame.com',
            ),
            Divider(color: Colors.white24, height: 48),
            _SectionHeader('Terms of Use'),
            _SubHeader('1. Acceptance'),
            _Body('By downloading and using Jesture, you agree to these terms. If you do not agree, please do not use the app.'),
            _SubHeader('2. License'),
            _Body('Jesture grants you a personal, non-transferable, non-exclusive license to use the app for personal entertainment purposes.'),
            _SubHeader('3. Prohibited Use'),
            _Body(
              '• Do not reverse engineer or modify the app.\n'
              '• Do not use the app for commercial purposes without written permission.\n'
              '• Do not attempt to bypass any premium content restrictions.',
            ),
            _SubHeader('4. Disclaimer'),
            _Body(
              'Jesture is provided "as is" without warranties. '
              'We are not responsible for any injury resulting from physical gameplay. '
              'Play in a clear, open space and take breaks regularly.',
            ),
            _SubHeader('5. Changes'),
            _Body('We may update these terms. Continued use of the app constitutes acceptance of the updated terms.'),
            SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 Jesture. All rights reserved.',
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: const TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.7),
  );
}
