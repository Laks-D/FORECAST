import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
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
                title: 'Upcoming',
                subtitle: '',
                bgColor: VibrantColors.warmYellow,
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
                            'Upcoming',
                      )
                      .toList();
                },
                clientNames: clientNames,
              ),
              const SizedBox(height: 16),
              _ScheduleSummaryCard(
                height: cardH,
                title: 'Pending',
                subtitle: '',
                bgColor: VibrantColors.softPink,
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
                title: 'Completed',
                subtitle: '',
                bgColor: VibrantColors.pastelGreen,
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
    );
  }
}

class _ScheduleSummaryCard extends StatefulWidget {
  const _ScheduleSummaryCard({
    required this.height,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.chrome,
    required this.pickSessions,
    required this.clientNames,
  });

  final double height;
  final String title;
  final String subtitle;
  final Color bgColor;
  final AppChromeTheme chrome;
  final List<ScheduleSession> Function(List<ScheduleSession> all) pickSessions;
  final Map<String, String> clientNames;

  @override
  State<_ScheduleSummaryCard> createState() => _ScheduleSummaryCardState();
}

class _ScheduleSummaryCardState extends State<_ScheduleSummaryCard> {
  bool? _userExpanded;

  static const String _postponeActionValue = '__postpone__';

  Color _statusColor(String status, AppChromeTheme chrome) {
    switch (status) {
      case 'Completed':
        return VibrantColors.pastelGreen;
      case 'Cancelled':
        return chrome.mutedColor;
      case 'Pending':
        return VibrantColors.softPink;
      case 'Upcoming':
      default:
        return VibrantColors.warmYellow;
    }
  }

  Future<void> _pickStatus(BuildContext context, ScheduleSession session) async {
    final chrome = AppChromeTheme.of(context);
    final sessionsCubit = context.read<SessionsCubit>();

    final derived = AppDateUtils.determineSessionStatus(
      session.status,
      session.date,
      session.time,
    );
    if (derived == 'Cancelled' || derived == 'Completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 1),
          content: Text(
            derived == 'Cancelled'
                ? 'Cancelled classes can’t be restored.'
                : 'Completed classes can’t be modified.',
          ),
        ),
      );
      return;
    }

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

        Widget actionOption({
          required String label,
          required IconData icon,
          required Color color,
          required String value,
        }) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              label,
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
                    actionOption(
                      label: 'Postpone (change time today)',
                      icon: Icons.schedule,
                      color: VibrantColors.warmYellow,
                      value: _postponeActionValue,
                    ),
                    option('Upcoming'),
                    option('Completed'),
                    option('Pending'),
                    option('Cancelled'),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (picked == null) return;

    if (picked == _postponeActionValue) {
      await _postponeSessionTime(context, session, sessionsCubit);
      return;
    }

    if (picked == 'Cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dctx) {
          return AlertDialog(
            title: const Text('Cancel class?'),
            content: const Text('This can’t be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(true),
                child: const Text('Cancel class'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (confirmed != true) return;
    }

    // If marking as completed, allow feedback entry.
    if (picked == 'Completed') {
      final feedback = await _collectCompletionFeedback(context, session);

      if (!context.mounted) return;
      await sessionsCubit.updateSession(
        session.copyWith(
          status: picked,
          rating: feedback?.rating ?? session.rating,
          comments: feedback?.comments ?? session.comments,
        ),
      );
      return;
    }

    await sessionsCubit.updateSession(session.copyWith(status: picked));

    if (!context.mounted) return;
    if (picked == 'Cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Class cancelled.'),
        ),
      );
    }
  }

  Future<void> _postponeSessionTime(
    BuildContext context,
    ScheduleSession session,
    SessionsCubit sessionsCubit,
  ) async {
    final currentRange = AppDateUtils.parseTimeRange(session.time);
    final currentStart = currentRange['start'] ?? 0;
    final currentEnd = currentRange['end'] ?? currentStart;
    final durationMinutes = session.duration != null
        ? (session.duration!.hours * 60).round()
        : (currentEnd - currentStart).clamp(5, 24 * 60);

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (currentStart ~/ 60) % 24,
        minute: currentStart % 60,
      ),
    );

    if (picked == null) return;
    if (!context.mounted) return;

    final newStart = (picked.hour * 60) + picked.minute;
    final newEnd = newStart + durationMinutes;
    if (newEnd > 24 * 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Pick an earlier time (must stay on the same day).'),
        ),
      );
      return;
    }

    final newTime = AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: AppDateUtils.formatTimeLabelFromMinutes(newStart),
      durationMinutes: durationMinutes,
    );

    bool overlapsTimeRange(String a, String b) {
      final ra = AppDateUtils.parseTimeRange(a);
      final rb = AppDateUtils.parseTimeRange(b);
      final aStart = ra['start'] ?? 0;
      final aEnd = ra['end'] ?? aStart;
      final bStart = rb['start'] ?? 0;
      final bEnd = rb['end'] ?? bStart;
      return aStart < bEnd && bStart < aEnd;
    }

    ScheduleSession? clash;
    for (final other in sessionsCubit.state.sessions) {
      if (other.id == session.id) continue;
      if (other.date != session.date) continue;

      final derived = AppDateUtils.determineSessionStatus(
        other.status,
        other.date,
        other.time,
      );
      if (derived == 'Cancelled' || derived == 'Completed') continue;

      if (overlapsTimeRange(newTime, other.time)) {
        clash = other;
        break;
      }
    }

    if (clash != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            'Clash with another class at ${clash.time}.',
          ),
        ),
      );
      return;
    }

    await sessionsCubit.updateSession(
      session.copyWith(
        time: newTime,
        status: 'Upcoming',
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Class postponed to $newTime.'),
      ),
    );
  }

  Future<_CompletionFeedback?> _collectCompletionFeedback(
    BuildContext context,
    ScheduleSession session,
  ) {
    final chrome = AppChromeTheme.of(context);
    final controller = TextEditingController(text: session.comments ?? '');
    var rating = session.rating;

    Widget star(int index, void Function(void Function()) setState) {
      final active = (rating ?? 0) >= index;
      return IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() => rating = index),
        icon: Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          color: active ? VibrantColors.warmYellow : chrome.mutedColor,
        ),
      );
    }

    return showModalBottomSheet<_CompletionFeedback>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.surfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Session feedback',
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
                        Text(
                          'Rating',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: chrome.mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Row(
                          children: [
                            star(1, setState),
                            star(2, setState),
                            star(3, setState),
                            star(4, setState),
                            star(5, setState),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Comment (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Skip'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop(
                                    _CompletionFeedback(
                                      rating: rating,
                                      comments: controller.text.trim().isEmpty
                                          ? null
                                          : controller.text.trim(),
                                    ),
                                  );
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);

    final cardColor = visual.neumorphism ? scheme.surface : chrome.surfaceColor;
    final dividerColor = visual.neumorphism
        ? scheme.outlineVariant.withOpacity(0.35)
        : const Color(0xFF111827).withOpacity(0.12);
    final headerFg = visual.neumorphism ? scheme.onSurface : chrome.textColor;
    final chevronFg =
      visual.neumorphism ? scheme.onSurface.withOpacity(0.55) : chrome.mutedColor;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];
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
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: chrome.textColor,
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
                      color: _statusColor(derivedStatus, chrome),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chrome.mutedColor,
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
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
              boxShadow: shadows,
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _userExpanded = !expanded;
                        });
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: widget.bgColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.bgColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: headerFg,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      fontSize: 16,
                                    ),
                              ),
                            ),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: expanded ? -0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: chevronFg,
                                size: 24,
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
                                  color: dividerColor,
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

class _CompletionFeedback {
  final int? rating;
  final String? comments;

  const _CompletionFeedback({
    required this.rating,
    required this.comments,
  });
}
