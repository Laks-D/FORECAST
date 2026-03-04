import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../calendar/domain/entities/schedule_session.dart';
import '../../../client/domain/usecases/get_clients_usecase.dart';
import '../../../../core/utils/date_utils.dart';

class DashboardMiddleCard extends StatelessWidget {
  const DashboardMiddleCard({super.key, this.height = 330});

  final double height;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final targetStr = AppDateUtils.dateToStr(DateTime.now());

              final availableH = constraints.maxHeight;
              final cardH = ((availableH - 32) / 3).clamp(78.0, 180.0);

              final clients = sl<GetClientsUseCase>().execute();
              final clientNames = {for (final c in clients) c.id: c.name};

              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _ScheduleSummaryCard(
                    height: cardH,
                    title: 'Pending',
                    subtitle: '',
                    chrome: chrome,
                    pickSessions: (sessions) {
                      return sessions
                          .where((s) => s.date == targetStr)
                          .where(
                            (s) =>
                                AppDateUtils.determineSessionStatus(
                                  s.status,
                                  s.date,
                                  s.time,
                                ) ==
                                'Pending',
                          )
                          .toList();
                    },
                    clientNames: clientNames,
                  ),
                  const SizedBox(height: 16),
                  _ScheduleSummaryCard(
                    height: cardH,
                    title: 'Overdue',
                    subtitle: '',
                    chrome: chrome,
                    pickSessions: (sessions) {
                      return sessions
                          .where((s) => s.date == targetStr)
                          .where(
                            (s) =>
                                AppDateUtils.determineSessionStatus(
                                  s.status,
                                  s.date,
                                  s.time,
                                ) ==
                                'Overdue',
                          )
                          .toList();
                    },
                    clientNames: clientNames,
                  ),
                  const SizedBox(height: 16),
                  _ScheduleSummaryCard(
                    height: cardH,
                    title: 'Completed',
                    subtitle: '',
                    chrome: chrome,
                    pickSessions: (sessions) {
                      return sessions
                          .where((s) => s.date == targetStr)
                          .where(
                            (s) =>
                                AppDateUtils.determineSessionStatus(
                                  s.status,
                                  s.date,
                                  s.time,
                                ) ==
                                'Completed',
                          )
                          .toList();
                    },
                    clientNames: clientNames,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduleSummaryCard extends StatefulWidget {
  const _ScheduleSummaryCard({
    required this.height,
    required this.title,
    required this.subtitle,
    required this.chrome,
    required this.pickSessions,
    required this.clientNames,
  });

  final double height;
  final String title;
  final String subtitle;
  final AppChromeTheme chrome;
  final List<ScheduleSession> Function(List<ScheduleSession> all) pickSessions;
  final Map<String, String> clientNames;

  @override
  State<_ScheduleSummaryCard> createState() => _ScheduleSummaryCardState();
}

class _ScheduleSummaryCardState extends State<_ScheduleSummaryCard> {
  bool? _userExpanded;

  Color _statusColor(String status, AppChromeTheme chrome) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF58C7B3);
      case 'Overdue':
        return const Color(0xFFEF4444);
      case 'Pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _pickStatus(BuildContext context, ScheduleSession session) async {
    final chrome = AppChromeTheme.of(context);
    final sessionsCubit = context.read<SessionsCubit>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget option(String value) {
          final selected = value == session.status;
          return ListTile(
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: _statusColor(value, chrome),
            ),
            title: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: chrome.textColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            onTap: () => Navigator.of(context).pop(value),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.surfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Set session status',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: chrome.textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: chrome.mutedColor),
                        ),
                      ],
                    ),
                    Text(
                      '${session.date} • ${session.time}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    option('Pending'),
                    option('Completed'),
                    option('Overdue'),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    await sessionsCubit.updateSession(
          session.copyWith(status: picked),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, sessionsState) {
        final picked = widget.pickSessions(sessionsState.sessions);
        picked.sort((a, b) {
          final ad = AppDateUtils.parseSessionDate(a.date);
          final bd = AppDateUtils.parseSessionDate(b.date);
          final d = ad.compareTo(bd);
          if (d != 0) return d;
          final at = AppDateUtils.parseTimeRange(a.time)['start'] ?? 0;
          final bt = AppDateUtils.parseTimeRange(b.time)['start'] ?? 0;
          return at.compareTo(bt);
        });

        final hasItems = picked.isNotEmpty;
        final expanded = _userExpanded ?? hasItems;

        // If the list becomes empty, force collapse.
        if (!hasItems && expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _userExpanded = false);
          });
        }

        final visible = picked.take(3).toList(growable: false);

        Widget sessionRow(ScheduleSession s) {
          final name = widget.clientNames[s.clientId] ?? 'Client';
          final derivedStatus = AppDateUtils.determineSessionStatus(
            s.status,
            s.date,
            s.time,
          );
          final stColor = _statusColor(derivedStatus, widget.chrome);
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 0,
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.chrome.textColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${s.date} • ${s.time} • '),
                  TextSpan(
                    text: derivedStatus,
                    style: TextStyle(
                      color: stColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.chrome.mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            onTap: () => _pickStatus(context, s),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.chrome.surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.chrome.mutedColor.withOpacity(0.18),
              ),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _userExpanded = !expanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: widget.chrome.textColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 160),
                              turns: expanded ? 0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: widget.chrome.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (expanded && visible.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < visible.length; i++) ...[
                              if (i != 0)
                                Divider(
                                  height: 1,
                                  color: widget.chrome.mutedColor.withOpacity(0.12),
                                ),
                              sessionRow(visible[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
