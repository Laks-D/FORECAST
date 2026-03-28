import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
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
    const options = <String>['Active', 'Pending', 'Overdue', 'Inactive'];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget option(String value) {
          final selected = value.trim().toLowerCase() == entity.status.trim().toLowerCase();
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
    if (picked.trim().toLowerCase() == entity.status.trim().toLowerCase()) return;

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

  String _money(double amount) {
    return '₹${amount.toStringAsFixed(1)}';
  }

  Color _statusBg(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'active') return Colors.green.withOpacity(0.12);
    if (s == 'overdue') return Colors.orange.withOpacity(0.12);
    return Colors.blue.withOpacity(0.12);
  }

  Color _statusFg(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'active') return Colors.green.shade700;
    if (s == 'overdue') return Colors.orange.shade800;
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                      entity.formattedPhone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                              'Client',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _money(entity.outstandingAmount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ),
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

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.7),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
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

  String _paymentStatusFor(DateTime date) {
    final dateKey = AppDateUtils.dateToStr(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final payDay = DateTime(date.year, date.month, date.day);

    for (final e in entity.timeline.reversed) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
      final s = e.status?.trim();
      if (s == 'Paid' || s == 'Paid fully') return 'Paid';
    }
    if (payDay.isBefore(today)) return 'Overdue';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    double paidTotal = 0;
    double pendingTotal = 0;
    double overdueTotal = 0;

    for (final pay in entity.payments) {
      final s = _paymentStatusFor(pay.createdAt);
      final amt = pay.amount ?? 0;
      if (s == 'Paid') {
        paidTotal += amt;
      } else if (s == 'Overdue') {
        overdueTotal += amt;
      } else {
        pendingTotal += amt;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
              label: 'Status',
              value: entity.status,
              valueStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              mutedColor: chrome.mutedColor,
            ),
            const SizedBox(height: 12),
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
              valueStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: Colors.green.shade700),
              mutedColor: chrome.mutedColor,
            ),
            const SizedBox(height: 12),
            _StatRow(
              label: 'Pending',
              value: _money(pendingTotal),
              valueStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: Colors.orange.shade700),
              mutedColor: chrome.mutedColor,
            ),
            if (overdueTotal > 0) ...[
              const SizedBox(height: 12),
              _StatRow(
                label: 'Overdue',
                value: _money(overdueTotal),
                valueStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: Colors.red.shade700),
                mutedColor: chrome.mutedColor,
              ),
            ],
          ],
        ),
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
              sessions: clientSessions,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    required List<ScheduleSession> sessions,
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: chrome.mutedColor,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final s = sessions[index];
                              final displayStatus = AppDateUtils.determineSessionStatus(
                                s.status,
                                s.date,
                                s.time,
                              );
                              final isPast = displayStatus == 'Overdue' ||
                                  displayStatus == 'Completed' ||
                                  displayStatus == 'Cancelled';
                              final statusColor = _statusColor(displayStatus, scheme);

                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: chrome.mutedColor.withOpacity(0.15),
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
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '#${s.sessionNo}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: statusColor,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.courseName ?? 'Session ${s.sessionNo}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: isPast
                                                        ? chrome.mutedColor
                                                        : null,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${AppDateUtils.displayDateStr(s.date)}  •  ${s.time}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: chrome.mutedColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          displayStatus,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: statusColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
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
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'overdue':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange;
      default:
        return scheme.primary;
    }
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
            'Activity',
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