import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/firebase/firestore_db.dart';
import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/storage/signup_profile_storage.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    this.initialFullName,
    this.initialProfession,
  });

  final String uid;
  final String email;
  final String? initialFullName;
  final String? initialProfession;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _professionController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: (widget.initialFullName ?? '').trim());
    _professionController = TextEditingController(text: (widget.initialProfession ?? '').trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final fullName = _nameController.text.trim();
    final profession = _professionController.text.trim();

    try {
      await firestoreDb.collection('users').doc(widget.uid).set(
        {
          'email': widget.email,
          'fullName': fullName,
          'profession': profession,
          'updatedAt': FieldValue.serverTimestamp(),
          // Keep defaults stable across the app.
          'nationality': 'India',
          'currency': '₹',
        },
        SetOptions(merge: true),
      );

      await SignupProfileStorage.saveProfile(
        SignupProfileData(
          fullName: fullName,
          profession: profession,
          email: widget.email,
          nationality: 'India',
          currency: '₹',
        ),
      );

      if (mounted) {
        try {
          context.read<UserProfileCubit>().refresh();
        } catch (_) {}
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to save profile (${e.code})')),
      );
      setState(() => _submitting = false);
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile')),
      );
      setState(() => _submitting = false);
      return;
    }

    if (!mounted) return;

    // No explicit navigation: LandingScreen gate will re-check Firestore and
    // switch to the dashboard automatically.
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Complete profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Please enter your details to continue.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name *'),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _professionController,
                    decoration: const InputDecoration(labelText: 'Profession *'),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Required';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Signed in as ${widget.email}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCompletionGate extends StatelessWidget {
  const ProfileCompletionGate({
    super.key,
    required this.child,
  });

  final Widget child;

  bool _isComplete(Map<String, dynamic>? data) {
    final fullName = (data?['fullName'] as String?)?.trim() ?? '';
    final profession = (data?['profession'] as String?)?.trim() ?? '';
    return fullName.isNotEmpty && profession.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.trim().isEmpty) return child;

    final email = (user?.email ?? '').trim();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestoreDb.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data?.data();
        if (_isComplete(data)) return child;

        return CompleteProfileScreen(
          uid: uid,
          email: email,
          initialFullName: (data?['fullName'] as String?)?.trim().isNotEmpty == true
              ? (data?['fullName'] as String?)
              : user?.displayName,
          initialProfession: (data?['profession'] as String?)?.trim(),
        );
      },
    );
  }
}
