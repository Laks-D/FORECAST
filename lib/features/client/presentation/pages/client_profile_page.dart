import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
import 'package:gendral_app/design_system/widgets/app_card.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../calendar/domain/entities/schedule_session.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_event.dart';
import '../bloc/client_state.dart';
import 'client_payments_page.dart';
import 'client_personal_details_page.dart';

class ClientProfilePage extends StatelessWidget {
  final Client entity;

  const ClientProfilePage({
    super.key,
    required this.entity,
  });

  /* ================= ADD NOTE ================= */

  void _showAddNoteModal(
    BuildContext context, {
    required Client entity,
  }) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write something important...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;

                    context.read<ClientBloc>().add(
                          AddNoteToClient(
                            entityId: entity.id,
                            note: text,
                          ),
                        );

                    Navigator.pop(context);
                  },
                  child: const Text('Save Note'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Client? _findUpdatedEntity(ClientState state) {
    if (state is! ClientLoaded) return null;
    for (final e in state.entities) {
      if (e.id == entity.id) return e;
    }
    return null;
  }

  /* ================= UPDATE STATUS ================= */

  Future<void> _showStatusPicker(
    BuildContext context, {
    required Client entity,
  }) async {
    final chrome = AppChromeTheme.of(context);
    const options = <String>['Active', 'Pending', 'Inactive'];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget option(String value) {
          final selected =
              value.trim().toLowerCase() == entity.status.trim().toLowerCase();
          return ListTile(
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: chrome.accentBlue,
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
                            'Set client status',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
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
                    const SizedBox(height: 10),
                    for (final v in options) option(v),
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
    if (!context.mounted) return;
    if (picked.trim().toLowerCase() == entity.status.trim().toLowerCase()) {
      return;
    }

    context.read<ClientBloc>().add(
          UpdateClientStatus(entityId: entity.id, status: picked),
        );
  }

  /* ================= PERSONAL DETAILS ================= */

  void _openPersonalDetails(
    BuildContext context, {
    required Client entity,
  }) {
    final clientBloc = context.read<ClientBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: clientBloc,
          child: ClientPersonalDetailsPage(entity: entity),
        ),
      ),
    );
  }

  /* ================= BUILD ================= */

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return BlocBuilder<ClientBloc, ClientState>(
      builder: (context, state) {
        final updated = _findUpdatedEntity(state);
        final current = updated ?? entity;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProfileHeaderCard(
                entity: current,
                mutedColor: chrome.mutedColor,
                onStatusTap: () => _showStatusPicker(
                  context,
                  entity: current,
                ),
                onTap: () => _openPersonalDetails(
                  context,
                  entity: current,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.note_add_outlined,
                      label: 'Note',
                      onTap: () => _showAddNoteModal(
                        context,
                        entity: current,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.payments_outlined,
                      label: 'Payment',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ClientBloc>(),
                            child: ClientPaymentsPage(entity: current),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileStatsCard(entity: current),
              const SizedBox(height: 16),
              _ScheduledClassesButton(clientId: current.id),
              const SizedBox(height: 16),
              _Timeline(entity: current),
            ],
          ),
        );
      },
    );
  }
}

/* ================= HEADER ================= */

class _ProfileHeaderCard extends StatelessWidget {
  final Client entity;
  final Color mutedColor;
  final VoidCallback onStatusTap;
  final VoidCallback onTap;

  const _ProfileHeaderCard({
    required this.entity,
    required this.mutedColor,
    required this.onStatusTap,
    required this.onTap,
  });

  Color _statusBg(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'active') return VibrantColors.tint(VibrantColors.pastelGreen);
    if (s == 'pending') return VibrantColors.tint(VibrantColors.warmYellow);
    if (s == 'inactive') return Colors.grey.withOpacity(0.12);
    return VibrantColors.tint(VibrantColors.softBlue);
  }

  Color _statusFg(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'active') return VibrantColors.deep(VibrantColors.pastelGreen);
    if (s == 'pending') return VibrantColors.deep(VibrantColors.warmYellow);
    if (s == 'inactive') return Colors.grey.shade700;
    return VibrantColors.deep(VibrantColors.softBlue);
  }

  @override
  Widget build(BuildContext context) {
    final rawEmail = (entity.email ?? '').trim();
    final emailText = rawEmail.isEmpty ? '—' : rawEmail;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: mutedColor.withOpacity(0.10),
            child: Text(
              entity.name.isEmpty ? '?' : entity.name.characters.first,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  emailText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entity.formattedPhone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStatusTap,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusBg(entity.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entity.status,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _statusFg(entity.status),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: _statusFg(entity.status),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= QUICK ACTION ================= */

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/* ================= STATS ================= */

class _ProfileStatsCard extends StatelessWidget {
  final Client entity;

  const _ProfileStatsCard({required this.entity});

  String _money(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return AppDateUtils.displayDate(dt);
  }

  String _paymentStatusFor(DateTime date, String paymentEventId) {
    final dateKey = AppDateUtils.dateToStr(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final payDay = DateTime(date.year, date.month, date.day);

    final hasMultiplePaymentsThatDay = entity.timeline
            .where((e) =>
                e.type == ClientTimelineEventType.payment &&
                AppDateUtils.dateToStr(e.createdAt) == dateKey)
            .length >
        1;

    // Prefer payment-specific status.
    for (final e in entity.timeline.reversed) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
      if (e.refId != paymentEventId) continue;
      final s = e.status?.trim();
      if (s == 'Paid' || s == 'Paid fully') return 'Paid';
    }

    // Legacy fallback (date-based) only when a single payment exists that day.
    if (!hasMultiplePaymentsThatDay) {
      for (final e in entity.timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
        if (e.refId != null) continue;
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully') return 'Paid';
      }
    }
    if (payDay.isBefore(today)) return 'Pending';
    return 'Upcoming';
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    double paidTotal = 0;
    double upcomingTotal = 0;
    double pendingTotal = 0;

    for (final pay in entity.payments) {
      final s = _paymentStatusFor(pay.createdAt, pay.id);
      final amt = pay.amount ?? 0;
      if (s == 'Paid') {
        paidTotal += amt;
      } else if (s == 'Pending') {
        pendingTotal += amt;
      } else {
        upcomingTotal += amt;
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _StatRow(
            label: 'Last Activity',
            value: _formatDate(entity.lastActivityAt),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Total Amount',
            value: _money(entity.outstandingAmount),
            valueStyle: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Paid',
            value: _money(paidTotal),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: VibrantColors.deep(VibrantColors.pastelGreen)),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Upcoming',
            value: _money(upcomingTotal),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: VibrantColors.deep(VibrantColors.warmYellow)),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Pending',
            value: _money(pendingTotal),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: VibrantColors.deep(VibrantColors.softPink)),
            mutedColor: chrome.mutedColor,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Color mutedColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.mutedColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: mutedColor),
          ),
        ),
        Text(
          value,
          style: valueStyle ?? Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/* ================= SCHEDULED CLASSES ================= */

class _ScheduledClassesButton extends StatelessWidget {
  final String clientId;

  const _ScheduledClassesButton({required this.clientId});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, state) {
        final clientSessions = state.sessions
            .where((s) => s.clientId == clientId)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showScheduledClasses(
              context,
              clientId: clientId,
              chrome: chrome,
              scheme: scheme,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: chrome.textColor.withOpacity(0.7),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scheduled Classes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${clientSessions.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: chrome.mutedColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showScheduledClasses(
    BuildContext context, {
    required String clientId,
    required AppChromeTheme chrome,
    required ColorScheme scheme,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return BlocBuilder<SessionsCubit, SessionsState>(
              builder: (context, state) {
                final sessions = state.sessions
                    .where((s) => s.clientId == clientId)
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: chrome.mutedColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scheduled Classes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: chrome.mutedColor,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: sessions.isEmpty
                            ? Center(
                                child: Text(
                                  'No scheduled classes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: chrome.mutedColor,
                                      ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: sessions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final s = sessions[index];
                                  final displayStatus =
                                      AppDateUtils.determineSessionStatus(
                                    s.status,
                                    s.date,
                                    s.time,
                                  );
                                  final isPast = displayStatus == 'Pending' ||
                                      displayStatus == 'Completed' ||
                                      displayStatus == 'Cancelled';
                                  final statusColor =
                                      _statusColor(displayStatus, scheme);

                                  void openDetails() {
                                    _showSessionDetails(
                                      context,
                                      session: s,
                                      displayStatus: displayStatus,
                                      statusColor: statusColor,
                                      chrome: chrome,
                                      scheme: scheme,
                                    );
                                  }

                                  return Material(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: openDetails,
                                      borderRadius: BorderRadius.circular(16),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: chrome.mutedColor
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '#${s.sessionNo}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: statusColor,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      s.courseName ??
                                                          'Session ${s.sessionNo}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: isPast
                                                                ? chrome
                                                                    .mutedColor
                                                                : null,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${AppDateUtils.displayDateStr(s.date)}  •  ${s.time}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: chrome
                                                                .mutedColor,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  displayStatus,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: statusColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'completed':
        return VibrantColors.pastelGreen;
      case 'cancelled':
        return VibrantColors.softPink;
      case 'pending':
        return VibrantColors.softPink;
      case 'upcoming':
        return VibrantColors.warmYellow;
      // Legacy.
      case 'overdue':
        return VibrantColors.softPink;
      default:
        return scheme.primary;
    }
  }

  void _showSessionDetails(
    BuildContext context, {
    required ScheduleSession session,
    required String displayStatus,
    required Color statusColor,
    required AppChromeTheme chrome,
    required ColorScheme scheme,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final rating = session.rating;
        final comments = session.comments;

        String restoredStatusForCancelledSession() {
          try {
            final now = DateTime.now();
            final todayDate = DateTime(now.year, now.month, now.day);
            final nowInMinutes = now.hour * 60 + now.minute;

            final sessionDate = AppDateUtils.parseSessionDate(session.date);
            final sessionOnlyDate =
                DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

            if (sessionOnlyDate.isBefore(todayDate)) {
              return 'Pending';
            }
            if (sessionOnlyDate.isAfter(todayDate)) {
              return 'Upcoming';
            }

            final range = AppDateUtils.parseTimeRange(session.time);
            final startMinutes = range['start'] ?? 0;
            final endMinutes = range['end'] ?? startMinutes;
            if (nowInMinutes >= endMinutes) return 'Pending';
            return 'Upcoming';
          } catch (_) {
            return 'Upcoming';
          }
        }

        bool overlapsTimeRange(String a, String b) {
          final ra = AppDateUtils.parseTimeRange(a);
          final rb = AppDateUtils.parseTimeRange(b);
          final aStart = ra['start'] ?? 0;
          final aEnd = ra['end'] ?? aStart;
          final bStart = rb['start'] ?? 0;
          final bEnd = rb['end'] ?? bStart;
          // Treat touching endpoints as NOT a clash.
          return aStart < bEnd && bStart < aEnd;
        }

        bool hasRestoreClash(
            List<ScheduleSession> all, ScheduleSession restoring) {
          for (final other in all) {
            if (other.id == restoring.id) continue;
            if (other.date != restoring.date) continue;

            final otherStatus = AppDateUtils.determineSessionStatus(
              other.status,
              other.date,
              other.time,
            );
            if (otherStatus == 'Cancelled' || otherStatus == 'Completed') {
              continue;
            }

            if (overlapsTimeRange(other.time, restoring.time)) {
              return true;
            }
          }
          return false;
        }

        Future<void> openRescheduleCancelledSessionSheet() async {
          if (!context.mounted) return;
          // Close the session details sheet first.
          Navigator.of(ctx).pop();

          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _RescheduleSingleSessionSheet(session: session),
          );
        }

        Widget stars(int value) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final active = value >= (i + 1);
              return Icon(
                active ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18,
                color: active ? VibrantColors.warmYellow : chrome.mutedColor,
              );
            }),
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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.courseName ??
                                'Session #${session.sessionNo}',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                  color: chrome.textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close, color: chrome.mutedColor),
                        ),
                      ],
                    ),
                    Text(
                      '${AppDateUtils.displayDateStr(session.date)} • ${session.time}',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: chrome.mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            displayStatus,
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (displayStatus == 'Cancelled') ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            final cubit = ctx.read<SessionsCubit>();
                            final restored =
                                restoredStatusForCancelledSession();
                            final restoring =
                                session.copyWith(status: restored);

                            if (hasRestoreClash(
                                cubit.state.sessions, restoring)) {
                              showDialog<void>(
                                context: ctx,
                                builder: (dctx) {
                                  return AlertDialog(
                                    title: const Text('Slot already booked'),
                                    content: const Text(
                                      'This time slot already has another class. Please reschedule this cancelled class to a free slot.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dctx).pop();
                                          openRescheduleCancelledSessionSheet();
                                        },
                                        child: const Text('Reschedule'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              return;
                            }

                            cubit.updateSession(restoring);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Restore'),
                        ),
                      ),
                    ],
                    if (displayStatus == 'Completed') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Rating',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: chrome.mutedColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          stars(rating ?? 0),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Comment',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: chrome.mutedColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (comments == null || comments.trim().isEmpty)
                            ? '—'
                            : comments.trim(),
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w700,
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

/* ================= TIMELINE (NON-PAYMENT) ================= */

class _Timeline extends StatelessWidget {
  final Client entity;

  const _Timeline({required this.entity});

  @override
  Widget build(BuildContext context) {
    final events = [...entity.timeline]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filter out payment and payment-related statusChanged events.
    final nonPaymentEvents = events.where((e) {
      if (e.type == ClientTimelineEventType.payment) return false;
      if (e.type == ClientTimelineEventType.statusChanged) {
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully' || s == 'Will pay later') {
          return false;
        }
      }
      return true;
    }).toList();

    if (nonPaymentEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Activity (${nonPaymentEvents.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        ...nonPaymentEvents.map((e) {
          final subtitle = _subtitleForEvent(e);
          return Card(
            child: ListTile(
              title: Text(_titleForEvent(e)),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: Text(
                AppDateUtils.displayDate(e.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }),
      ],
    );
  }

  String? _subtitleForEvent(ClientTimelineEvent e) {
    switch (e.type) {
      case ClientTimelineEventType.payment:
        if (e.amount == null) return e.note;
        if (e.note != null && e.note!.trim().isNotEmpty) {
          return '₹${e.amount} • ${e.note!}';
        }
        return '₹${e.amount}';
      case ClientTimelineEventType.statusChanged:
        return e.status;
      case ClientTimelineEventType.note:
        return e.note;
      case ClientTimelineEventType.profileCreated:
        return null;
    }
  }

  String _titleForEvent(ClientTimelineEvent e) {
    switch (e.type) {
      case ClientTimelineEventType.profileCreated:
        return 'Profile created';
      case ClientTimelineEventType.statusChanged:
        return 'Status changed';
      case ClientTimelineEventType.payment:
        return 'Payment received';
      case ClientTimelineEventType.note:
        return 'Note added';
    }
  }
}

class _RescheduleSingleSessionSheet extends StatefulWidget {
  const _RescheduleSingleSessionSheet({required this.session});

  final ScheduleSession session;

  @override
  State<_RescheduleSingleSessionSheet> createState() =>
      _RescheduleSingleSessionSheetState();
}

class _RescheduleSingleSessionSheetState
    extends State<_RescheduleSingleSessionSheet> {
  late DateTime _date;
  late int _startTimeMinutes;
  SessionDuration _duration = SessionDuration.oneHour;

  SessionDuration _durationFromMinutes(int minutes) {
    switch (minutes) {
      case 30:
        return SessionDuration.halfHour;
      case 60:
        return SessionDuration.oneHour;
      case 120:
        return SessionDuration.twoHours;
      case 180:
        return SessionDuration.threeHours;
      case 480:
        return SessionDuration.wholeDay;
      default:
        return SessionDuration.oneHour;
    }
  }

  int _durationMinutesForSession() => (_duration.hours * 60).round();

  String _selectedTimeRangeLabel() {
    return AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
      durationMinutes: _durationMinutesForSession(),
    );
  }

  List<ScheduleSession> _findClashes(List<ScheduleSession> existing) {
    final selectedDate = AppDateUtils.dateToStr(_date);
    final selectedRange =
        AppDateUtils.parseTimeRange(_selectedTimeRangeLabel());
    final selectedStart = selectedRange['start'] ?? 0;
    final selectedEnd = selectedRange['end'] ?? selectedStart;

    return existing.where((s) {
      if (s.id == widget.session.id) return false;
      if (s.date != selectedDate) return false;

      // Cancelled/Completed sessions should not block rescheduling.
      final derived =
          AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
      if (derived == 'Cancelled' || derived == 'Completed') return false;

      final exRange = AppDateUtils.parseTimeRange(s.time);
      final exStart = exRange['start'] ?? 0;
      final exEnd = exRange['end'] ?? exStart;

      return (selectedStart < exEnd) && (selectedEnd > exStart);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _date = AppDateUtils.parseSessionDate(widget.session.date);

    final parsed = AppDateUtils.parseTimeRange(widget.session.time);
    final startMinutes = parsed['start'] ?? 0;
    _startTimeMinutes = startMinutes;

    if (widget.session.duration != null) {
      _duration = widget.session.duration!;
    } else {
      final endMinutes = parsed['end'] ?? startMinutes;
      final diff = endMinutes - startMinutes;
      _duration = _durationFromMinutes(diff > 0 ? diff : 60);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final cubit = context.read<SessionsCubit>();
    final clashes = _findClashes(cubit.state.sessions);
    if (clashes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Selected slot clashes with existing sessions.'),
        ),
      );
      return;
    }

    final durationMinutes = _durationMinutesForSession();
    final updated = widget.session.copyWith(
      date: AppDateUtils.dateToStr(_date),
      time: AppDateUtils.formatTimeRangeFromStartAndDuration(
        startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
        durationMinutes: durationMinutes,
      ),
      duration: _duration,
      // Rescheduling a cancelled class restores it back to active scheduling.
      status: widget.session.status == 'Cancelled'
          ? 'Upcoming'
          : widget.session.status,
    );

    await cubit.updateSession(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final durationMinutes = _durationMinutesForSession();
    final startLabel =
        AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes);
    final timeRangeLabel = AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: startLabel,
      durationMinutes: durationMinutes,
    );

    Future<void> pickStartTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (_startTimeMinutes ~/ 60) % 24,
          minute: _startTimeMinutes % 60,
        ),
      );
      if (picked == null) return;
      setState(() => _startTimeMinutes = picked.hour * 60 + picked.minute);
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: BlocBuilder<SessionsCubit, SessionsState>(
              builder: (context, state) {
                final clashes = _findClashes(state.sessions);
                final hasClash = clashes.isNotEmpty;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reschedule class',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text('Date: ${AppDateUtils.displayDate(_date)}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: chrome.textColor,
                        side: BorderSide(
                            color: chrome.mutedColor.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: pickStartTime,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  timeRangeLabel,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              Icon(Icons.access_time, color: chrome.mutedColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SessionDuration>(
                      value: _duration,
                      items: SessionDuration.values
                          .map(
                            (d) => DropdownMenuItem<SessionDuration>(
                              value: d,
                              child: Text(d.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _duration = v);
                      },
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasClash
                          ? 'Clash found with ${clashes.length} session(s): ${clashes.take(2).map((s) => s.time).join(', ')}${clashes.length > 2 ? '...' : ''}'
                          : 'No clash for selected time.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: hasClash
                                ? VibrantColors.softPink
                                : VibrantColors.pastelGreen,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: hasClash ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
