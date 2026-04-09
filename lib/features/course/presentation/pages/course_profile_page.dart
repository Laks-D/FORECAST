import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app/app_mode.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/storage/signup_profile_storage.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
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
              child: BlocBuilder<ClientBloc, ClientState>(
                builder: (context, state) {
                  Client? client;
                  if (state is ClientLoaded) {
                    for (final c in state.entities) {
                      if (c.id == clientId) {
                        client = c;
                        break;
                      }
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Course', courseName, chrome),
                      const SizedBox(height: 8),
                      _kv(context, 'Client', client?.displayName ?? 'Client', chrome),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Tutor info',
              child: FutureBuilder<SignupProfileData?>(
                future: SignupProfileStorage.getProfile(),
                builder: (context, snap) {
                  final profile = snap.data;
                  final tutorName = (profile?.fullName ?? '').trim();
                  final tutorEmail = (profile?.email ?? '').trim();

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
                      .where((s) => (s.courseName ?? '').trim() == courseName)
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
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClientTransactionsPage(clientId: clientId),
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
                  color: chrome.mutedColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
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
