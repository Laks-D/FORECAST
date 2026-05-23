import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_db.dart';
import '../../../join_request/join_request_service.dart';
import '../../../join_request/ui/join_request_waiting_page.dart';

class InviteLandingPage extends StatefulWidget {
  final String? tutorId;
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
  String? _resolvedOrgId;
  String _requestName = 'Client';
  String _requestPhone = '';
  String _adminName = 'Tutor';
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
      // Resolve orgId: use provided orgId or lookup by tutorId -> organizations.ownerId
      var orgId = widget.orgId;
      if (orgId == null && widget.tutorId != null) {
        final snap = await firestoreDb
            .collection('organizations')
            .where('ownerId', isEqualTo: widget.tutorId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) orgId = snap.docs.first.id;
      }

      final user = FirebaseAuth.instance.currentUser;
      final nameFromAuth = (user?.displayName ?? '').trim();
      final emailFromAuth = (user?.email ?? '').trim();
      final userDoc = user == null
          ? null
          : await firestoreDb.collection('users').doc(user.uid).get();

      String adminName = 'Tutor';
      if (orgId != null) {
        final orgDoc = await firestoreDb.collection('organizations').doc(orgId).get();
        final data = orgDoc.data();
        final nameCandidate = (data?['name'] as String?)?.trim();
        if (nameCandidate != null && nameCandidate.isNotEmpty) {
          adminName = nameCandidate;
        }
      }

      final phoneFromUserDoc = ((userDoc?.data()?['phone'] as String?) ?? '').trim();

      setState(() {
        _resolvedOrgId = orgId;
        _requestName = nameFromAuth.isNotEmpty
            ? nameFromAuth
            : (emailFromAuth.isNotEmpty ? emailFromAuth.split('@').first : 'Client');
        _requestPhone = phoneFromUserDoc;
        _adminName = adminName;
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text('Error: $_error')));

    final hasOrg = _resolvedOrgId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite from tutor: ${widget.tutorId ?? 'unknown'}'),
            const SizedBox(height: 8),
            Text('Organization: ${hasOrg ? _resolvedOrgId : 'Not available'}'),
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
                onPressed: hasOrg && !_sending ? _sendJoinRequest : null,
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
    final orgId = _resolvedOrgId;
    final user = FirebaseAuth.instance.currentUser;
    if (orgId == null || user == null) return;

    if (!JoinRequestService.isQrValid(widget.qrTimestampMs)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invite QR has expired. Please scan a new one.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final docId = await JoinRequestService.sendRequest(
        orgId: orgId,
        clientFirebaseUid: user.uid,
        clientName: _requestName,
        clientPhone: _requestPhone,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => JoinRequestWaitingPage(
            docId: docId,
            adminName: _adminName,
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
