import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../utils/app_links.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../widgets/simple_qr_painter.dart';

class InviteQrPage extends StatefulWidget {
  const InviteQrPage({super.key, this.orgId});

  final String? orgId;

  @override
  State<InviteQrPage> createState() => _InviteQrPageState();
}

class _InviteQrPageState extends State<InviteQrPage> {
  late String _payload;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    // Use onboarding link with tutorId and timestamp so the QR is unique.
    // Encode the full onboarding link into the QR so camera apps open the
    // fallback web page if hosted (web/join/index.html).
    final link = OnboardingLink.generateLinkWithTutor(widget.orgId, uid, ts);
    setState(() => _payload = link);
  }

  void _share() {
    // When sharing, include the full onboarding link so recipients opening the link
    // in a browser still get redirected (if you host a landing page).
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    final link = OnboardingLink.generateLinkWithTutor(widget.orgId, uid, ts);
    Share.share('Join my class!\n\n$link', subject: 'Class Invitation');
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite — QR'),
        backgroundColor: chrome.frameColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: SimpleQr(data: _payload, size: 236),
              ),
              const SizedBox(height: 18),
              Text(
                'Scannable invite — regenerates each time',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _regenerate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _payload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Link'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
