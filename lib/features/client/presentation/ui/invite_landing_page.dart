import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_db.dart';
import '../../../join_request/join_request_service.dart';
import '../../../join_request/ui/join_request_waiting_page.dart';

/// Shown when a student opens an invite link or scans a QR.
/// Sends a join request to the tutor identified by [tutorId].
class InviteLandingPage extends StatefulWidget {
  final String? tutorId;
  final String? qrTimestampMs;

  const InviteLandingPage({
    super.key,
    this.tutorId,
    this.qrTimestampMs,
  });

  @override
  State<InviteLandingPage> createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends State<InviteLandingPage> {
  String _requestName = 'Client';
  String _requestPhone = '';
  String _requestEmail = '';
  bool _loading = true;
  bool _sending = false;
  bool _alreadyLinked = false;
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

      bool alreadyLinked = false;
      if (user != null && widget.tutorId != null && widget.tutorId!.isNotEmpty) {
        // Step 1: Check if the student has an enrollment ticket.
        // This is safe and avoids permission-denied errors for brand new students.
        final enrollmentDoc = await firestoreDb
            .collection('users')
            .doc(user.uid)
            .collection('enrollment')
            .doc(widget.tutorId)
            .get();

        if (enrollmentDoc.exists) {
          // Step 2: The student is enrolled, so Firestore grants them read access to their own client profile.
          // We query the tutor's workspace to see if the client profile still exists, or if the tutor deleted it.
          try {
            final existingClientQuery = await firestoreDb
                .collection('users')
                .doc(widget.tutorId)
                .collection('clients')
                .where('firebaseUid', isEqualTo: user.uid)
                .limit(1)
                .get();
            alreadyLinked = existingClientQuery.docs.isNotEmpty;
          } catch (e) {
            // If the tutor soft-deleted the client, Firestore security rules might reject the query
            // because the client profile doesn't exist anymore, triggering permission-denied.
            // In this case, we treat them as NOT linked so they can request to join again.
            if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
              alreadyLinked = false;
            } else {
              rethrow;
            }
          }
        } else {
          alreadyLinked = false;
        }
      }

      setState(() {
        _requestName = nameFromAuth.isNotEmpty
            ? nameFromAuth
            : (emailFromAuth.isNotEmpty
                ? emailFromAuth.split('@').first
                : 'Client');
        _requestPhone = phoneFromUserDoc;
        _requestEmail = emailFromAuth;
        _alreadyLinked = alreadyLinked;
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
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 52, color: Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!.contains('unavailable')
                      ? 'Firestore is temporarily unavailable. Check your internet connection and try again.'
                      : _error!,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _prepare();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasTutor = widget.tutorId != null && widget.tutorId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite from tutor: ${widget.tutorId ?? 'unknown'}'),
            const SizedBox(height: 20),
            Text('Signed-in as $_requestName'),
            const SizedBox(height: 8),
            const Text(
              'Request access to this class. Your tutor will accept or reject your request.',
            ),
            const SizedBox(height: 12),
            if (_alreadyLinked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Text(
                  'You are already enrolled under this tutor. Go to Home to see your courses and schedule.',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              )
            else
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
                      : const Text('Send Request To Join'),
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
        clientEmail: _requestEmail,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => JoinRequestWaitingPage(
            docId: docId,
            adminName: tutorId,
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
