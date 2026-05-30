import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../utils/app_links.dart';
import 'invite_landing_page.dart';

class ScanInvitePage extends StatefulWidget {
  const ScanInvitePage({super.key});

  @override
  State<ScanInvitePage> createState() => _ScanInvitePageState();
}

class _ScanInvitePageState extends State<ScanInvitePage> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final bar = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final raw = bar?.rawValue;
    if (raw == null) return;

    String? tutorId = OnboardingLink.parseTutorId(raw);
    String? ts = OnboardingLink.parseTimestamp(raw);

    // Fallback: try parsing as a raw query string (e.g. older QR codes).
    if (tutorId == null) {
      try {
        final uri = Uri.parse('https://placeholder/?$raw');
        tutorId = uri.queryParameters['tutorId'];
        ts = uri.queryParameters['ts'];
      } catch (_) {}
    }

    if (tutorId == null) return;

    setState(() => _scanned = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InviteLandingPage(
          tutorId: tutorId,
          qrTimestampMs: ts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invite')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
