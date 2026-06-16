import re
import sys

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

# 1. Remove import
content = content.replace("import '../../domain/entities/client_timeline_event.dart';", "")

# 2. Update _ProfileStatsCard
old_stats_card = """class _ProfileStatsCard extends StatelessWidget {
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

    final totalAmount = paidTotal + pendingTotal + upcomingTotal;
    final outstandingAmount = pendingTotal;

    final firstDate = entity.timeline.isEmpty
        ? null
        : entity.timeline.first.createdAt;
    final lastDate = entity.timeline.isEmpty
        ? null
        : entity.timeline.last.createdAt;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatRow(
                  label: 'Outstanding',
                  value: _money(outstandingAmount, currency),
                  valueStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: outstandingAmount > 0
                            ? const Color(0xFFEF4444)
                            : chrome.textColor,
                      ),
                  mutedColor: chrome.mutedColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: chrome.mutedColor.withOpacity(0.2),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _StatRow(
                    label: 'Paid',
                    value: _money(paidTotal, currency),
                    valueStyle:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: VibrantColors.pastelGreen,
                            ),
                    mutedColor: chrome.mutedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatRow(
            label: 'Upcoming',
            value: _money(upcomingTotal, currency),
            valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: VibrantColors.warmYellow,
                ),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Total Amount',
            value: _money(totalAmount, currency),
            valueStyle: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'First Activity',
            value: _formatDate(firstDate),
            valueStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            mutedColor: chrome.mutedColor,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Last Activity',
            value: _formatDate(lastDate),
            valueStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            mutedColor: chrome.mutedColor,
          ),
        ],
      ),
    );
  }
}"""

import_addition = "import '../../domain/entities/payment.dart';\nimport '../../domain/entities/client_event.dart';\nimport '../../../client/presentation/bloc/client_bloc.dart';\nimport 'package:flutter_bloc/flutter_bloc.dart';\n"
content = import_addition + content

new_stats_card = """class _ProfileStatsCard extends StatelessWidget {
  final Client entity;

  const _ProfileStatsCard({required this.entity});

  String _money(double amount, String currency) =>
      '${currency}${amount.toStringAsFixed(0)}';

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return AppDateUtils.displayDate(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = entity.currency ?? defaultCurrency;
    final paymentRepository = context.read<ClientBloc>().paymentRepository;
    final clientEventRepository = context.read<ClientBloc>().clientEventRepository;

    return StreamBuilder<List<Payment>>(
      stream: paymentRepository.watchForClient(entity.id),
      builder: (context, paySnap) {
        return StreamBuilder<List<ClientEvent>>(
          stream: clientEventRepository.watchForClient(entity.id),
          builder: (context, eventSnap) {
            double paidTotal = 0;
            double upcomingTotal = 0;
            double pendingTotal = 0;

            final now = DateTime.now();
            final payments = paySnap.data ?? [];
            for (final pay in payments) {
              final amt = pay.amount;
              if (pay.status == PaymentStatus.paid) {
                paidTotal += amt;
              } else if (pay.dueDate.isBefore(now)) {
                pendingTotal += amt;
              } else {
                upcomingTotal += amt;
              }
            }

            final totalAmount = paidTotal + pendingTotal + upcomingTotal;
            final outstandingAmount = pendingTotal;

            final events = eventSnap.data ?? [];
            final firstDate = events.isEmpty ? null : events.last.createdAt; // Assuming desc sort
            final lastDate = events.isEmpty ? null : events.first.createdAt;

            return AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatRow(
                          label: 'Outstanding',
                          value: _money(outstandingAmount, currency),
                          valueStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: outstandingAmount > 0
                                    ? const Color(0xFFEF4444)
                                    : chrome.textColor,
                              ),
                          mutedColor: chrome.mutedColor,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: chrome.mutedColor.withOpacity(0.2),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _StatRow(
                            label: 'Paid',
                            value: _money(paidTotal, currency),
                            valueStyle:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: VibrantColors.pastelGreen,
                                    ),
                            mutedColor: chrome.mutedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatRow(
                    label: 'Upcoming',
                    value: _money(upcomingTotal, currency),
                    valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: VibrantColors.warmYellow,
                        ),
                    mutedColor: chrome.mutedColor,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Total Amount',
                    value: _money(totalAmount, currency),
                    valueStyle: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    mutedColor: chrome.mutedColor,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'First Activity',
                    value: _formatDate(firstDate),
                    valueStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    mutedColor: chrome.mutedColor,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Last Activity',
                    value: _formatDate(lastDate),
                    valueStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    mutedColor: chrome.mutedColor,
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
}"""

content = content.replace(old_stats_card, new_stats_card)

# 3. Replace timeline list
old_timeline_widget = """class _TimelineList extends StatelessWidget {
  final Client entity;

  const _TimelineList({required this.entity});

  @override
  Widget build(BuildContext context) {
    if (entity.timeline.isEmpty) {
      return const AppEmptyState(
        message: 'No timeline activity.',
        icon: Icons.history_outlined,
      );
    }

    final events = List<ClientTimelineEvent>.from(entity.timeline);
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++) ...[
          _TimelineItemTile(
            event: events[i],
            client: entity,
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
          if (i < events.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Container(
                height: 16,
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
        ],
      ],
    );
  }
}

class _TimelineItemTile extends StatelessWidget {
  final ClientTimelineEvent event;
  final Client client;
  final bool isFirst;
  final bool isLast;

  const _TimelineItemTile({
    required this.event,
    required this.client,
    this.isFirst = false,
    this.isLast = false,
  });

  String _formatDateTime(DateTime dt) {
    return '${AppDateUtils.displayDate(dt)} • ${TimeOfDay.fromDateTime(dt).format(null as dynamic)}'; // Wait context?
  }

  bool _isPaymentPaid() {
    if (event.type == ClientTimelineEventType.payment) return false;
    if (event.type == ClientTimelineEventType.statusChanged) {
      return event.status == 'Paid' || event.status == 'Paid fully';
    }
    return false;
  }

  Color _iconColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (event.type) {
      case ClientTimelineEventType.profileCreated:
        return scheme.primary;
      case ClientTimelineEventType.statusChanged:
        if (_isPaymentPaid()) return VibrantColors.pastelGreen;
        return VibrantColors.warmYellow;
      case ClientTimelineEventType.payment:
        return const Color(0xFFEF4444);
      case ClientTimelineEventType.note:
        return VibrantColors.softPink;
    }
  }

  IconData _iconData() {
    switch (event.type) {
      case ClientTimelineEventType.profileCreated:
        return Icons.person_add_outlined;
      case ClientTimelineEventType.statusChanged:
        if (_isPaymentPaid()) return Icons.check_circle_outline;
        return Icons.cached_outlined;
      case ClientTimelineEventType.payment:
        return Icons.payments_outlined;
      case ClientTimelineEventType.note:
        return Icons.edit_note_outlined;
    }
  }

  String? _subtitleForEvent(ClientTimelineEvent e, String currency) {
    switch (e.type) {
      case ClientTimelineEventType.payment:
        return 'Amount: $currency${e.amount?.toStringAsFixed(0) ?? '0'}'
            '${e.note != null && e.note!.isNotEmpty ? ' • ${e.note}' : ''}';
      case ClientTimelineEventType.statusChanged:
        return 'Changed to: ${e.status}';
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
        return 'Status update';
      case ClientTimelineEventType.payment:
        return 'Payment added';
      case ClientTimelineEventType.note:
        return 'Note added';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = client.currency ?? defaultCurrency;

    final title = _titleForEvent(event);
    final sub = _subtitleForEvent(event, currency);
    final iconCol = _iconColor(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconCol.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: iconCol.withOpacity(0.25)),
            ),
            child: Icon(
              _iconData(),
              color: iconCol,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: chrome.textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(event.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: chrome.mutedColor.withOpacity(0.7),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}"""

new_timeline_widget = """class _TimelineList extends StatelessWidget {
  final Client entity;

  const _TimelineList({required this.entity});

  @override
  Widget build(BuildContext context) {
    final clientEventRepository = context.read<ClientBloc>().clientEventRepository;
    
    return StreamBuilder<List<ClientEvent>>(
      stream: clientEventRepository.watchForClient(entity.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
           return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data!;
        
        if (events.isEmpty) {
          return const AppEmptyState(
            message: 'No timeline activity.',
            icon: Icons.history_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < events.length; i++) ...[
              _TimelineItemTile(
                event: events[i],
                client: entity,
                isFirst: i == 0,
                isLast: i == events.length - 1,
              ),
              if (i < events.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Container(
                    height: 16,
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
            ],
          ],
        );
      }
    );
  }
}

class _TimelineItemTile extends StatelessWidget {
  final ClientEvent event;
  final Client client;
  final bool isFirst;
  final bool isLast;

  const _TimelineItemTile({
    required this.event,
    required this.client,
    this.isFirst = false,
    this.isLast = false,
  });

  String _formatDateTime(DateTime dt, BuildContext context) {
    return '${AppDateUtils.displayDate(dt)} • ${TimeOfDay.fromDateTime(dt).format(context)}';
  }

  Color _iconColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (event.type) {
      case ClientEventType.profileCreated:
        return scheme.primary;
      case ClientEventType.statusChanged:
        return VibrantColors.warmYellow;
      case ClientEventType.note:
        return VibrantColors.softPink;
      default:
        return scheme.primary;
    }
  }

  IconData _iconData() {
    switch (event.type) {
      case ClientEventType.profileCreated:
        return Icons.person_add_outlined;
      case ClientEventType.statusChanged:
        return Icons.cached_outlined;
      case ClientEventType.note:
        return Icons.edit_note_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String? _subtitleForEvent(ClientEvent e, String currency) {
    switch (e.type) {
      case ClientEventType.statusChanged:
        final oldStatus = e.metadata?['oldStatus'];
        final newStatus = e.metadata?['newStatus'];
        if (oldStatus != null && newStatus != null) {
          return 'Changed from $oldStatus to $newStatus';
        }
        return 'Status updated';
      case ClientEventType.note:
        return e.note;
      case ClientEventType.profileCreated:
        return null;
      default:
        return null;
    }
  }

  String _titleForEvent(ClientEvent e) {
    switch (e.type) {
      case ClientEventType.profileCreated:
        return 'Profile created';
      case ClientEventType.statusChanged:
        return 'Status update';
      case ClientEventType.note:
        return 'Note added';
      default:
        return 'Activity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = client.currency ?? defaultCurrency;

    final title = _titleForEvent(event);
    final sub = _subtitleForEvent(event, currency);
    final iconCol = _iconColor(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconCol.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: iconCol.withOpacity(0.25)),
            ),
            child: Icon(
              _iconData(),
              color: iconCol,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: chrome.textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(event.createdAt, context),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: chrome.mutedColor.withOpacity(0.7),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}"""

content = content.replace(old_timeline_widget, new_timeline_widget)


with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

