import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firestore_db.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/get_clients_usecase.dart';
import '../../domain/entities/client.dart';
import '../pages/client_registration_page.dart';
import '../../../student_onboarding/ui/student_onboarding_screen.dart';
import '../../domain/repositories/client_repository.dart';
import '../../../student_onboarding/bloc/student_onboarding_bloc.dart';
import '../../../student_onboarding/bloc/student_onboarding_event.dart';

class InviteLandingPage extends StatefulWidget {
  final String? tutorId;
  final String? orgId;

  const InviteLandingPage({super.key, this.tutorId, this.orgId});

  @override
  State<InviteLandingPage> createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends State<InviteLandingPage> {
  String? _resolvedOrgId;
  Client? _matchedClient;
  bool _loading = true;
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

      // Load local clients to see if current Firebase user maps to a client
      await sl<ClientRepository>().loadFromStorage();
      final clients = sl<GetClientsUseCase>().execute();
      final userEmail = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
      final matched = clients.cast<dynamic>().firstWhere(
        (c) => c != null && ((c as dynamic).email as String?)?.trim().toLowerCase() == userEmail,
        orElse: () => null,
      );

      setState(() {
        _resolvedOrgId = orgId;
        _matchedClient = matched as Client?;
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
      appBar: AppBar(title: const Text('Invite')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite from tutor: ${widget.tutorId ?? 'unknown'}'),
            const SizedBox(height: 8),
            Text('Organization: ${hasOrg ? _resolvedOrgId : 'Not available'}'),
            const SizedBox(height: 20),
            if (_matchedClient != null) ...[
              Text('Signed-in as ${_matchedClient!.displayName}'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasOrg ? _joinAsClient : null,
                  child: const Text('Join Class'),
                ),
              ),
            ] else ...[
              const Text('You are not registered as a client.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Register as full client (pre-fills referredBy)
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => ClientRegistrationPage(referredBy: widget.tutorId)),
                        );
                      },
                      child: const Text('Register as Client'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasOrg)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Allow joining without registering (student onboarding)
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => StudentOnboardingScreen(orgId: _resolvedOrgId!)),
                      );
                    },
                    child: const Text('Join Without Registering'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _joinAsClient() async {
    if (_resolvedOrgId == null || _matchedClient == null) return;

    final bloc = StudentOnboardingBloc();
    // Submit using client details
    bloc.add(SubmitStudentFormEvent(
      orgId: _resolvedOrgId!,
      fullName: _matchedClient!.displayName,
      phoneNumber: _matchedClient!.formattedPhone,
      profession: '',
    ));

    // Show temporary feedback and pop after small delay to allow write
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joining class...')));
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
