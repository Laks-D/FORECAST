import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_db.dart';
import '../../../join_request/join_request_service.dart';
import '../../../join_request/ui/join_request_waiting_page.dart';

class InviteLandingPage extends StatefulWidget {
  final String? tutorId;
  // orgId is retained as a parameter so existing call-sites still compile,
  // but it is intentionally ignored — all routing is done via tutorId.
  final String? orgId;
  final String? qrTimestampMs;

  const InviteLandingPage({
    super.key,
    this.tutorId,
    this.orgId,
    this.qrTimestampMs,
  });

  @override
  State<InviteLandingPage> createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends State<InviteLandingPage> {
  String _requestName = 'Client';
  String _requestPhone = '';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final nameFromAuth = (user?.displayName ?? '').trim();
      final emailFromAuth = (user?.email ?? '').trim();
      final userDoc = user == null
          ? null
          : await firestoreDb.collection('users').doc(user.uid).get();

      final phoneFromUserDoc =
          ((userDoc?.data()?['phone'] as String?) ?? '').trim();

      setState(() {
        _requestName = nameFromAuth.isNotEmpty
            ? nameFromAuth
            : (emailFromAuth.isNotEmpty
                ? emailFromAuth.split('@').first
                : 'Client');
        _requestPhone = phoneFromUserDoc;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    // tutorId must be present for the button to be enabled.
    final hasTutor = widget.tutorId != null && widget.tutorId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite from: ${widget.tutorId ?? 'unknown'}'),
            const SizedBox(height: 20),
            Text('Signed-in as $_requestName'),
            const SizedBox(height: 8),
            const Text(
              'Request access to this class. Your tutor will accept or reject your request.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasTutor && !_sending ? _sendJoinRequest : null,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Request to Join'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendJoinRequest() async {
    final tutorId = widget.tutorId;
    final user = FirebaseAuth.instance.currentUser;
    if (tutorId == null || tutorId.isEmpty || user == null) return;

    if (!JoinRequestService.isQrValid(widget.qrTimestampMs)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This invite QR has expired. Please scan a new one.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final docId = await JoinRequestService.sendRequest(
        tutorId: tutorId,
        clientFirebaseUid: user.uid,
        clientName: _requestName,
        clientPhone: _requestPhone,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => JoinRequestWaitingPage(
            docId: docId,
            adminName: tutorId, // shown on waiting screen
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
