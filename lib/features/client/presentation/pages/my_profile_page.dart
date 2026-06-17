import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../client/domain/entities/client.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_state.dart';
import 'client_personal_details_page.dart';
import '../../../payment/presentation/pages/client_transactions_page.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final onSurface = scheme.onSurface;
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);

    return BlocBuilder<ClientBloc, ClientState>(
      buildWhen: (p, n) => p.runtimeType != n.runtimeType || p != n,
      builder: (context, state) {
        final current = () {
          if (state is ClientLoaded) {
            for (final c in state.entities) {
              if (c.id == client.id) return c;
            }
          }
          return client;
        }();

        final currency = (current.currency ?? '').trim().isEmpty
            ? defaultCurrency
            : current.currency!.trim();

        String textOrDash(String? v) {
          final s = (v ?? '').trim();
          return s.isEmpty ? '-' : s;
        }

        String dobLabel(DateTime? dt) {
          if (dt == null) return '-';
          return AppDateUtils.displayDate(dt);
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            foregroundColor: onSurface,
            elevation: 0,
            title: const Text('My Profile'),
            actions: [
              TextButton(
                onPressed: () {
                  final clientBloc = context.read<ClientBloc>();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: clientBloc,
                        child: ClientPersonalDetailsPage(
                          entity: current,
                          allowStatusEdit: false,
                          allowEmailEdit: false,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Edit'),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _SectionCard(
                  title: 'Personal details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Name', current.displayName, chrome),
                      const SizedBox(height: 10),
                      _kv(
                        context,
                        'Middle name',
                        textOrDash(current.middleName),
                        chrome,
                      ),
                      const SizedBox(height: 10),
                      _kv(context, 'Phone', current.formattedPhone, chrome),
                      const SizedBox(height: 10),
                      _kv(
                        context,
                        'Email',
                        textOrDash(current.email),
                        chrome,
                      ),
                      const SizedBox(height: 10),
                      _kv(
                        context,
                        'Gender',
                        textOrDash(current.gender),
                        chrome,
                      ),
                      const SizedBox(height: 10),
                      _kv(
                        context,
                        'Date of birth',
                        dobLabel(current.dateOfBirth),
                        chrome,
                      ),
                      const SizedBox(height: 10),
                      _kv(
                        context,
                        'Address',
                        textOrDash(current.address),
                        chrome,
                      ),
                      const SizedBox(height: 10),
                      _kv(context, 'Status', current.status, chrome),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EnrolledTutorCard(),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Payments',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Currency', currency, chrome),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final clientBloc = context.read<ClientBloc>();
                            final sessionsCubit = context.read<SessionsCubit>();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MultiBlocProvider(
                                  providers: [
                                    BlocProvider.value(value: clientBloc),
                                    BlocProvider.value(value: sessionsCubit),
                                  ],
                                  child: ClientTransactionsPage(
                                    clientId: current.id,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          label: const Text('View transactions'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'About',
                  child: Text(
                    'Client app: view-only.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(BuildContext context, String k, String v, AppChromeTheme chrome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            k,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: chrome.mutedColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            v,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: chrome.textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: chrome.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: chrome.textColor,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Shows which tutor the currently logged-in client is enrolled with.
///
/// Reads the first enrollment document from
/// `users/{uid}/enrollment` and displays the tutorName stored there.
class _EnrolledTutorCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    final chrome = AppChromeTheme.of(context);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get()
          .then((snap) => snap.docs.isNotEmpty ? snap.docs.first : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SectionCard(
            title: 'My Tutor',
            child: SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chrome.mutedColor,
                  ),
                ),
              ),
            ),
          );
        }

        final doc = snapshot.data;
        final tutorName = doc?.data()?['tutorName'] as String? ?? '';
        final tutorId = doc?.data()?['tutorId'] as String? ?? '';

        if (tutorName.isEmpty && tutorId.isEmpty) {
          return _SectionCard(
            title: 'My Tutor',
            child: Text(
              'Not enrolled with any tutor yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chrome.mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          );
        }

        return _SectionCard(
          title: 'My Tutor',
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
                child: Text(
                  tutorName.isNotEmpty
                      ? tutorName.characters.first.toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tutorName.isNotEmpty ? tutorName : tutorId,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: chrome.textColor,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
