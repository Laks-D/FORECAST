import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/firebase/firestore_db.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/storage/signup_profile_storage.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../calendar/domain/entities/schedule_session.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../client/domain/entities/client.dart';
import '../../../payment/presentation/pages/client_transactions_page.dart';

class CourseProfilePage extends StatelessWidget {
  const CourseProfilePage({
    super.key,
    required this.clientId,
    required this.courseName,
  });

  final String clientId;
  final String courseName;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final isClientMode = AppModeScope.isClient(context);

    final clientState = context.watch<ClientBloc>().state;
    Client? client;
    if (clientState is ClientLoaded) {
      for (final c in clientState.entities) {
        if (c.id == clientId) {
          client = c;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(courseName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: 'Course details',
              child: FutureBuilder<Map<String, String>>(
                future: isClientMode ? _getTutorInfo(isClientMode, client?.tutorId) : Future.value({}),
                builder: (context, snap) {
                  final data = snap.data ?? {};
                  final tutorName = data['name'] ?? '';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Course', courseName, chrome),
                      const SizedBox(height: 8),
                      if (isClientMode)
                        _kv(context, 'Tutor', tutorName.isEmpty ? 'Tutor' : tutorName, chrome)
                      else
                        _kv(context, 'Client', client?.displayName ?? 'Client', chrome),
                    ],
                  );
                }
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Tutor info',
              child: FutureBuilder<Map<String, String>>(
                future: _getTutorInfo(isClientMode, client?.tutorId),
                builder: (context, snap) {
                  final data = snap.data ?? {};
                  final tutorName = data['name'] ?? '';
                  final tutorEmail = data['email'] ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Name', tutorName.isEmpty ? 'Tutor' : tutorName, chrome),
                      const SizedBox(height: 8),
                      _kv(context, 'Email', tutorEmail.isEmpty ? '-' : tutorEmail, chrome),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Scheduled classes',
              trailing: isClientMode
                  ? null
                  : Text(
                      'View only for now',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
              child: BlocBuilder<SessionsCubit, SessionsState>(
                builder: (context, sessionsState) {
                  final items = sessionsState.sessions
                      .where((s) => s.clientId == clientId)
                      .where((s) {
                        final rawName = (s.courseName ?? '').trim();
                        final effectiveName = rawName.isEmpty ? 'General Sessions' : rawName;
                        return effectiveName == courseName;
                      })
                      .toList()
                    ..sort((a, b) {
                      final d = a.date.compareTo(b.date);
                      if (d != 0) return d;
                      final at = AppDateUtils.parseTimeRange(a.time)['start'] ?? 0;
                      final bt = AppDateUtils.parseTimeRange(b.time)['start'] ?? 0;
                      return at.compareTo(bt);
                    });

                  if (items.isEmpty) {
                    return Text(
                      'No scheduled classes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w700,
                          ),
                    );
                  }

                  return Column(
                    children: [
                      for (final s in items.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _sessionRow(context, s, chrome),
                        ),
                      if (items.length > 8)
                        Text(
                          '+ ${items.length - 8} more',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: chrome.mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Payments',
              child: SizedBox(
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
                          child: ClientTransactionsPage(clientId: clientId),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View transactions'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isClientMode
                  ? 'Client mode: view-only.'
                  : 'Tutor mode: course editing will be wired next.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chrome.mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(BuildContext context, ScheduleSession s, AppChromeTheme chrome) {
    final derived = AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Text(
            '#${s.sessionNo}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AppDateUtils.displayDateStr(s.date)} • ${s.time}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: chrome.textColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            derived,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _sessionStatusColor(derived, chrome),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Color _sessionStatusColor(String status, AppChromeTheme chrome) {
    switch (status.toLowerCase()) {
      case 'completed':
        return VibrantColors.pastelGreen;
      case 'cancelled':
        return VibrantColors.softPink;
      case 'pending':
        return VibrantColors.softPink;
      case 'upcoming':
        return VibrantColors.warmYellow;
      case 'overdue':
        return VibrantColors.softPink;
      default:
        return chrome.mutedColor;
    }
  }

  Future<Map<String, String>> _getTutorInfo(bool isClientMode, String? passedTutorId) async {
    if (!isClientMode) {
      final profile = await SignupProfileStorage.getProfile();
      return {
        'name': (profile?.fullName ?? '').trim(),
        'email': (profile?.email ?? '').trim(),
      };
    }

    if (passedTutorId == null) return {};

    try {
      final settingsDoc = await firestoreDb.collection('users').doc(passedTutorId).collection('settings').doc('app').get();
      var tName = 'Tutor';
      var tEmail = '';
      if (settingsDoc.exists) {
        final profile = settingsDoc.data()?['signupProfile'] as Map<String, dynamic>?;
        if (profile != null) {
          tName = (profile['fullName'] ?? profile['userName'] ?? 'Tutor').trim();
          tEmail = (profile['email'] ?? '').trim();
        }
      }
      return {
        'name': tName.isEmpty ? 'Tutor' : tName,
        'email': tEmail,
      };
    } catch (_) {
      return {
        'name': 'Tutor',
        'email': '',
      };
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: chrome.textColor,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

Widget _kv(BuildContext context, String k, String v, AppChromeTheme chrome) {
  return Row(
    children: [
      SizedBox(
        width: 70,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    ],
  );
}
