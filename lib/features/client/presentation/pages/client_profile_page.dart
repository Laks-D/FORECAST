import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:snow/design_system/theme/app_chrome_theme.dart';
import 'package:snow/design_system/widgets/app_card.dart';
import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../calendar/domain/entities/schedule_session.dart';
import '../../../calendar/domain/services/schedule_generator.dart';
import '../../../calendar/ui/widgets/schedule_sessions_sheet.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_event.dart';
import '../bloc/client_state.dart';
import 'client_payments_page.dart';
import 'client_personal_details_page.dart';
import '../ui/scan_invite_page.dart';

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
    const options = <String>['Active', 'On Hold', 'Inactive', 'Pending'];

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

    return BlocConsumer<ClientBloc, ClientState>(
      listenWhen: (previous, current) {
        if (current is! ClientLoaded) return false;
        final currHas = current.entities.any((e) => e.id == entity.id);
        if (currHas) return false;

        if (previous is ClientLoaded) {
          final prevHas = previous.entities.any((e) => e.id == entity.id);
          return prevHas;
        }

        return true;
      },
      listener: (context, state) {
        Navigator.of(context).maybePop();
      },
      builder: (context, state) {
        if (state is ClientLoaded) {
          final exists = state.entities.any((e) => e.id == entity.id);
          if (!exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).maybePop();
            });
            return const Scaffold(body: SizedBox.shrink());
          }
        }

        final updated = _findUpdatedEntity(state);
        final current = updated ?? entity;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Scan to join class',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanInvitePage()),
                  );
                },
              ),
            ],
          ),
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

  String _money(double amount, String currency) =>
      '${currency}${amount.toStringAsFixed(0)}';

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
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = entity.currency ?? defaultCurrency;

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
            value: _money(entity.outstandingAmount, currency),
            valueStyle: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Paid',
            value: _money(paidTotal, currency),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: VibrantColors.deep(VibrantColors.pastelGreen)),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Upcoming',
            value: _money(upcomingTotal, currency),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: VibrantColors.deep(VibrantColors.warmYellow)),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Pending',
            value: _money(pendingTotal, currency),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Scheduled Classes',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (sessions.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _ModifySessionsRangeSheet(
                                    clientId: clientId,
                                    sessions: sessions,
                                  ),
                                );
                              },
                              child: const Text('Modify'),
                            ),
                        ],
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
                            session.courseName ?? 'Session #${session.sessionNo}',
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
                            horizontal: 10,
                            vertical: 5,
                          ),
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

class _ModifySessionsRangeSheet extends StatefulWidget {
  const _ModifySessionsRangeSheet({
    required this.clientId,
    required this.sessions,
  });

  final String clientId;
  final List<ScheduleSession> sessions;

  @override
  State<_ModifySessionsRangeSheet> createState() =>
      _ModifySessionsRangeSheetState();
}

class _ModifySessionsRangeSheetState extends State<_ModifySessionsRangeSheet> {
  final _formKey = GlobalKey<FormState>();
  late List<ScheduleSession> _sortedSessions;
  late List<ScheduleSession> _editableSessions;
  int? _fromSessionNo;

  int? _toSessionNo;
  late DateTime _startDate;

  bool _hasGenerated = false;
  List<ScheduleSession> _draftUpdated = const [];
  List<ScheduleSession> _draftClashes = const [];

  String _frequency = 'Weekly';
  int _weeklyDay = DateTime.monday;
  int _monthlyDate = 1;
  int _customDays = 1;
  int _startTimeMinutes = 10 * 60;
  SessionDuration _duration = SessionDuration.oneHour;

  @override
  void initState() {
    super.initState();

    _sortedSessions = [...widget.sessions]
      ..sort((a, b) => a.sessionNo.compareTo(b.sessionNo));

    _editableSessions = _sortedSessions.where(_canEditSession).toList(growable: false);
    _fromSessionNo = _editableSessions.isEmpty ? null : _editableSessions.first.sessionNo;
    _toSessionNo = _editableSessions.isEmpty ? null : _editableSessions.last.sessionNo;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstSessionDate = _editableSessions.isNotEmpty
        ? AppDateUtils.parseSessionDate(_editableSessions.first.date)
        : today;
    _startDate = firstSessionDate.isBefore(today) ? today : firstSessionDate;

    if (_editableSessions.isNotEmpty) {
      final parsed = AppDateUtils.parseTimeRange(_editableSessions.first.time);
      _startTimeMinutes = parsed['start'] ?? _startTimeMinutes;
      if (_editableSessions.first.duration != null) {
        _duration = _editableSessions.first.duration!;
      }
      _weeklyDay = _startDate.weekday;
      _monthlyDate = _startDate.day;
    }
  }

  bool _canEditSession(ScheduleSession s) {
    final derived = AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
    return derived != 'Completed' && derived != 'Cancelled';
  }

  bool _rangeHasLockedSessions(int from, int to) {
    final a = from <= to ? from : to;
    final b = from <= to ? to : from;

    for (final s in widget.sessions) {
      if (s.clientId != widget.clientId) continue;
      if (s.sessionNo < a || s.sessionNo > b) continue;
      if (!_canEditSession(s)) return true;
    }
    return false;
  }

  void _invalidateDraft() {
    _hasGenerated = false;
    _draftUpdated = const [];
    _draftClashes = const [];
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _weeklyDay = picked.weekday;
      _monthlyDate = picked.day;
      _invalidateDraft();
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (_startTimeMinutes ~/ 60) % 24,
        minute: _startTimeMinutes % 60,
      ),
    );
    if (picked == null) return;
    setState(() {
      _startTimeMinutes = picked.hour * 60 + picked.minute;
      _invalidateDraft();
    });
  }

  List<ScheduleSession> _sessionsInRange(int from, int to) {
    final a = from <= to ? from : to;
    final b = from <= to ? to : from;

    final items = widget.sessions
        .where((s) => s.clientId == widget.clientId)
        .where((s) => s.sessionNo >= a && s.sessionNo <= b)
        .where(_canEditSession)
        .toList();
    items.sort((x, y) => x.sessionNo.compareTo(y.sessionNo));
    return items;
  }

  List<ScheduleSession> _buildUpdatedSessions({
    required List<ScheduleSession> target,
    required List<ScheduleSession> generated,
  }) {
    final out = <ScheduleSession>[];
    for (var i = 0; i < target.length && i < generated.length; i++) {
      final old = target[i];
      final gen = generated[i];

      out.add(
        old.copyWith(
          date: gen.date,
          time: gen.time,
          duration: _duration,
        ),
      );
    }
    return out;
  }

  List<ScheduleSession> _findClashes({
    required List<ScheduleSession> updated,
    required List<ScheduleSession> all,
  }) {
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

    final updatedIds = updated.map((e) => e.id).toSet();
    final clashes = <ScheduleSession>[];

    for (final u in updated) {
      final uDate = u.date;
      for (final other in all) {
        if (updatedIds.contains(other.id)) continue;
        if (other.date != uDate) continue;

        final derived = AppDateUtils.determineSessionStatus(
          other.status,
          other.date,
          other.time,
        );
        if (derived == 'Cancelled' || derived == 'Completed') continue;

        if (overlapsTimeRange(u.time, other.time)) {
          clashes.add(other);
          break;
        }
      }
    }

    return clashes;
  }

  String _sessionInfoLabel(ScheduleSession s) {
    return '#${s.sessionNo}  •  ${AppDateUtils.displayDateStr(s.date)}  •  ${s.time}';
  }

  String _draftInfoLabel(ScheduleSession s) {
    return '#${s.sessionNo}  •  ${AppDateUtils.displayDateStr(s.date)}  •  ${s.time}';
  }

  String _sessionDisplayStatus(ScheduleSession s) {
    return AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
  }

  Color _sessionStatusColor(
    String status,
    ColorScheme scheme,
    AppChromeTheme chrome,
  ) {
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
        return chrome.mutedColor;
    }
  }

  Widget _statusChip(
    BuildContext context, {
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Widget _sessionDropdownRow(
    BuildContext context,
    ScheduleSession s, {
    required bool showStatus,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final status = _sessionDisplayStatus(s);
    final color = _sessionStatusColor(status, scheme, chrome);

    return Row(
      children: [
        Expanded(
          child: Text(
            _sessionInfoLabel(s),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showStatus) ...[
          const SizedBox(width: 10),
          _statusChip(context, status: status, color: color),
        ],
      ],
    );
  }

  Future<void> _generate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final from = _fromSessionNo;
    final to = _toSessionNo;
    if (from == null || to == null) return;

    if (_rangeHasLockedSessions(from, to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            'Completed/Cancelled classes cannot be modified. Select a range without them.',
          ),
        ),
      );
      return;
    }

    final target = _sessionsInRange(from, to);
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('No editable sessions found in this range.'),
        ),
      );
      return;
    }

    final timeRange = AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
      durationMinutes: (_duration.hours * 60).round(),
    );

    final generated = ScheduleGenerator.generate(
      count: target.length,
      startDate: _startDate,
      frequency: _frequency,
      timeSlot: timeRange,
      weeklyDay: _weeklyDay,
      monthlyDate: _monthlyDate,
      customDays: _customDays,
      clientId: widget.clientId,
      duration: _duration,
    );

    final updated = _buildUpdatedSessions(target: target, generated: generated);

    final cubit = context.read<SessionsCubit>();
    final clashes = _findClashes(updated: updated, all: cubit.state.sessions);

    setState(() {
      _hasGenerated = true;
      _draftUpdated = updated;
      _draftClashes = clashes;
    });
  }

  Future<void> _save() async {
    if (!_hasGenerated) {
      await _generate();
      return;
    }
    if (_draftUpdated.isEmpty) return;
    if (_draftClashes.isNotEmpty) return;

    final cubit = context.read<SessionsCubit>();
    await cubit.updateSessions(_draftUpdated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openAddClassPopup() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _startDate.isBefore(today) ? today : _startDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleSessionsSheet(
        initialDate: initial,
        presetClientId: widget.clientId,
        lockClient: true,
        initialCount: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final hasEditableSessions = _editableSessions.isNotEmpty;

    final fromNo = _fromSessionNo;
    final toNo = _toSessionNo;
    final a = (fromNo != null && toNo != null) ? (fromNo <= toNo ? fromNo : toNo) : null;
    final b = (fromNo != null && toNo != null) ? (fromNo <= toNo ? toNo : fromNo) : null;
    final targetCount = (a != null && b != null) ? (b - a + 1) : 0;

    final clashText = _draftClashes.isEmpty
      ? 'No clash for the new schedule.'
      : 'Clash with existing session (#${_draftClashes.first.sessionNo}) on ${AppDateUtils.displayDateStr(_draftClashes.first.date)} at ${_draftClashes.first.time}.';

    final fromOptions = _editableSessions
      .where((s) => toNo == null ? true : s.sessionNo <= toNo)
      .toList(growable: false);
    final toOptions = _editableSessions
      .where((s) => fromNo == null ? true : s.sessionNo >= fromNo)
      .toList(growable: false);

    final startLabel =
        AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes);
    final timeRangeLabel = AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: startLabel,
      durationMinutes: (_duration.hours * 60).round(),
    );

    const weekDayItems = <MapEntry<int, String>>[
      MapEntry(DateTime.monday, 'Monday'),
      MapEntry(DateTime.tuesday, 'Tuesday'),
      MapEntry(DateTime.wednesday, 'Wednesday'),
      MapEntry(DateTime.thursday, 'Thursday'),
      MapEntry(DateTime.friday, 'Friday'),
      MapEntry(DateTime.saturday, 'Saturday'),
      MapEntry(DateTime.sunday, 'Sunday'),
    ];

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
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Modify classes',
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
                    if (!hasEditableSessions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'No editable classes. Completed/Cancelled classes cannot be modified.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: chrome.mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    DropdownButtonFormField<int>(
                      value: _fromSessionNo,
                      isExpanded: true,
                      items: fromOptions
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.sessionNo,
                              child:
                                  _sessionDropdownRow(context, s, showStatus: true),
                            ),
                          )
                          .toList(growable: false),
                      selectedItemBuilder: (context) {
                        return fromOptions
                            .map(
                              (s) => _sessionDropdownRow(
                                context,
                                s,
                                showStatus: false,
                              ),
                            )
                            .toList(growable: false);
                      },
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _fromSessionNo = v;

                          final picked = _editableSessions.firstWhere(
                            (s) => s.sessionNo == v,
                            orElse: () => _editableSessions.first,
                          );
                          final fromDate =
                              AppDateUtils.parseSessionDate(picked.date);
                          _startDate = fromDate.isBefore(today) ? today : fromDate;
                          _weeklyDay = _startDate.weekday;
                          _monthlyDate = _startDate.day;

                          // Keep To >= From.
                          if (_toSessionNo != null && _toSessionNo! < v) {
                            _toSessionNo = v;
                          }

                          _invalidateDraft();
                        });
                      },
                      validator: (v) => v == null ? 'Select a class' : null,
                      decoration: const InputDecoration(
                        labelText: 'From class',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _toSessionNo,
                      isExpanded: true,
                      items: toOptions
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.sessionNo,
                              child:
                                  _sessionDropdownRow(context, s, showStatus: true),
                            ),
                          )
                          .toList(growable: false),
                      selectedItemBuilder: (context) {
                        return toOptions
                            .map(
                              (s) => _sessionDropdownRow(
                                context,
                                s,
                                showStatus: false,
                              ),
                            )
                            .toList(growable: false);
                      },
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _toSessionNo = v;
                          _invalidateDraft();
                        });
                      },
                      validator: (v) => v == null ? 'Select a class' : null,
                      decoration: const InputDecoration(
                        labelText: 'To class',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      targetCount <= 0 || a == null || b == null
                          ? 'Select From/To classes'
                          : 'Modifying $targetCount class${targetCount == 1 ? '' : 'es'} (#$a to #$b)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        'Start date: ${AppDateUtils.displayDate(_startDate)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: chrome.textColor,
                        side: BorderSide(
                          color: chrome.mutedColor.withOpacity(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickStartTime,
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
                              Icon(
                                Icons.access_time,
                                color: chrome.mutedColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _frequency,
                            items: const [
                              DropdownMenuItem(
                                value: 'Daily',
                                child: Text('Daily'),
                              ),
                              DropdownMenuItem(
                                value: 'Weekly',
                                child: Text('Weekly'),
                              ),
                              DropdownMenuItem(
                                value: 'Monthly',
                                child: Text('Monthly'),
                              ),
                              DropdownMenuItem(
                                value: 'Custom',
                                child: Text('Custom'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _frequency = v;
                                _invalidateDraft();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<SessionDuration>(
                            value: _duration,
                            items: SessionDuration.values
                                .map(
                                  (d) => DropdownMenuItem<SessionDuration>(
                                    value: d,
                                    child: Text(d.displayName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _duration = v;
                                _invalidateDraft();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_frequency == 'Weekly')
                      DropdownButtonFormField<int>(
                        value: _weeklyDay,
                        items: weekDayItems
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _weeklyDay = v;
                            _invalidateDraft();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Day of week',
                        ),
                      )
                    else if (_frequency == 'Monthly')
                      DropdownButtonFormField<int>(
                        value: _monthlyDate.clamp(1, 28),
                        items: List.generate(
                          28,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _monthlyDate = v;
                            _invalidateDraft();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Monthly date',
                        ),
                      )
                    else if (_frequency == 'Custom')
                      TextFormField(
                        initialValue: _customDays.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Every N days',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) return 'Enter days';
                          return null;
                        },
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          if (n == null) return;
                          setState(() {
                            _customDays = n.clamp(1, 365);
                            _invalidateDraft();
                          });
                        },
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed:
                                  (_startDate.isBefore(today) || !hasEditableSessions)
                                      ? null
                                      : _generate,
                              child: const Text('Generate'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  (_startDate.isBefore(today) || !_hasGenerated || !hasEditableSessions)
                                      ? null
                                      : (_draftClashes.isNotEmpty
                                          ? null
                                          : _save),
                              child: const Text('Save changes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _startDate.isBefore(today) ? null : _openAddClassPopup,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add new class'),
                      ),
                    ),
                    if (_hasGenerated) ...[
                      const SizedBox(height: 12),
                      Text(
                        clashText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: chrome.mutedColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (_draftUpdated.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...(() {
                          final items = _draftUpdated.length <= 10
                              ? _draftUpdated
                              : _draftUpdated.take(10).toList(growable: false);
                          return [
                            for (final s in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  _draftInfoLabel(s),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: chrome.mutedColor),
                                ),
                              ),
                            if (_draftUpdated.length > items.length)
                              Text(
                                '+ ${_draftUpdated.length - items.length} more',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: chrome.mutedColor),
                              ),
                          ];
                        })(),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= TIMELINE (NON-PAYMENT) ================= */

class _Timeline extends StatelessWidget {
  final Client entity;

  const _Timeline({required this.entity});

  @override
  Widget build(BuildContext context) {
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = entity.currency ?? defaultCurrency;
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
          final subtitle = _subtitleForEvent(e, currency);
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

  String? _subtitleForEvent(ClientTimelineEvent e, String currency) {
    switch (e.type) {
      case ClientTimelineEventType.payment:
        if (e.amount == null) return e.note;
        if (e.note != null && e.note!.trim().isNotEmpty) {
          return '${currency}${e.amount} • ${e.note!}';
        }
        return '${currency}${e.amount}';
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
