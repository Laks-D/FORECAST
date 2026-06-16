import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../utils/app_links.dart';
import 'invite_landing_page.dart';

/// Student-side: scan a tutor's invite QR (camera) OR paste the invite
/// link / code manually. The manual path means the join flow works even where
/// the camera is unavailable (web without a webcam, emulators, desktop).
class ScanInvitePage extends StatefulWidget {
  const ScanInvitePage({super.key});

  @override
  State<ScanInvitePage> createState() => _ScanInvitePageState();
}

class _ScanInvitePageState extends State<ScanInvitePage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Resolve a raw payload (QR or pasted text) to the invite and navigate.
  /// Returns false if nothing usable was found.
  bool _resolveAndGo(String? raw) {
    if (_handled || raw == null) return false;
    final (tutorId, ts) = OnboardingLink.parse(raw);
    if (tutorId == null || tutorId.isEmpty) return false;

    _handled = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InviteLandingPage(tutorId: tutorId, qrTimestampMs: ts),
      ),
    );
    return true;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      if (_resolveAndGo(b.rawValue)) return;
    }
  }

  Future<void> _openManualEntry() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter invite link or code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the invite link your tutor shared (or the code from their QR screen).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'https://…/join?tutorId=…&ts=…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (!mounted || value == null) return;
    final ok = _resolveAndGo(value);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read that invite. Check the link and try again.'),
        ),
      );
    }
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    return _FallbackPanel(
      icon: Icons.no_photography_outlined,
      title: 'Camera unavailable',
      message:
          'We could not start the camera (${error.errorCode.name}). You can still '
          'join by entering the invite link your tutor shared.',
      onManual: _openManualEntry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Invite'),
        actions: [
          IconButton(
            tooltip: 'Enter code manually',
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _openManualEntry,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: _cameraError,
              placeholderBuilder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Point the camera at your tutor’s QR code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openManualEntry,
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      label: const Text('Enter invite link / code instead'),
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
}

class _FallbackPanel extends StatelessWidget {
  const _FallbackPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.onManual,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onManual,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Enter invite link / code'),
            ),
          ],
        ),
      ),
    );
  }
}
