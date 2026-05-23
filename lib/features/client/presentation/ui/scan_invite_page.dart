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
    // Accept both full onboarding URLs and compact query-string payloads (tutorId=...&ts=...)
    String? tutorId = OnboardingLink.parseTutorId(raw);
    String? orgId = OnboardingLink.parseOrgId(raw);
    String? ts = OnboardingLink.parseTimestamp(raw);

    // If parsing as a URL failed, try parsing as a raw query string
    if (tutorId == null && orgId == null) {
      try {
        // Normalize by prefixing a dummy scheme + host so Dart can parse the query.
        final uri = Uri.parse('https://placeholder/?' + raw);
        tutorId = uri.queryParameters['tutorId'];
        orgId = uri.queryParameters['orgId'];
        ts = uri.queryParameters['ts'];
      } catch (_) {
        // ignore
      }
    }

    if (tutorId == null && orgId == null) return;

    setState(() => _scanned = true);
    // Always route to invite landing. It will create a join request instead of
    // forcing registration/onboarding.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InviteLandingPage(
          tutorId: tutorId,
          orgId: orgId,
          qrTimestampMs: ts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invite')),
      body: MobileScanner(
        onDetect: _onDetect,
      ),
    );
  }
}
