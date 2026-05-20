import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:snow/design_system/theme/app_chrome_theme.dart';
import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../bloc/client_bloc.dart';
import '../bloc/client_event.dart';
import '../bloc/client_state.dart';

class ClientPaymentsPage extends StatelessWidget {
  final Client entity;

  const ClientPaymentsPage({super.key, required this.entity});

  Client? _findUpdatedEntity(ClientState state) {
    if (state is ClientLoaded) {
      try {
        return state.entities.firstWhere((c) => c.id == entity.id);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final defaultCurrency = context.select((UserProfileCubit c) => c.state.currency);
    return Scaffold(
      appBar: AppBar(
        title: Text('${entity.name} — Payments'),
      ),
      body: BlocBuilder<ClientBloc, ClientState>(
        builder: (context, state) {
          final current = _findUpdatedEntity(state) ?? entity;
          final currency = current.currency ?? defaultCurrency;
          final payments = [...current.payments]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (payments.isEmpty) {
            return const Center(
              child: Text('No scheduled payments'),
            );
          }

          // Compute summary.
          double paidTotal = 0;
          double upcomingTotal = 0;
          double pendingTotal = 0;
          for (final pay in payments) {
            final s = _paymentStatusFor(current, pay.createdAt, pay.id);
            final amt = pay.amount ?? 0;
            if (s == 'Paid') {
              paidTotal += amt;
            } else if (s == 'Pending') {
              pendingTotal += amt;
            } else {
              upcomingTotal += amt;
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Summary card ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _SummaryChip(
                        label: 'Paid',
                        amount: paidTotal,
                        color: VibrantColors.deep(VibrantColors.pastelGreen),
                        currency: currency,
                      ),
                      const SizedBox(width: 12),
                      _SummaryChip(
                        label: 'Upcoming',
                        amount: upcomingTotal,
                        color: VibrantColors.deep(VibrantColors.warmYellow),
                        currency: currency,
                      ),
                      if (pendingTotal > 0) ...[
                        const SizedBox(width: 12),
                        _SummaryChip(
                          label: 'Pending',
                          amount: pendingTotal,
                          color: VibrantColors.deep(VibrantColors.softPink),
                          currency: currency,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Client details card ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Divider(),
                      _DetailRow(label: 'Name', value: current.displayName),
                      _DetailRow(label: 'Phone', value: current.formattedPhone),
                      _DetailRow(label: 'Email', value: (current.email != null && current.email!.isNotEmpty) ? current.email! : '—'),
                      _DetailRow(label: 'Gender', value: (current.gender != null && current.gender!.isNotEmpty) ? current.gender! : '—'),
                      _DetailRow(
                        label: 'Date of Birth',
                        value: current.dateOfBirth != null
                            ? AppDateUtils.displayDate(current.dateOfBirth!)
                            : '—',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Payment rows ──
              ...payments.map((pay) {
                final status = _paymentStatusFor(current, pay.createdAt, pay.id);
                return _PaymentRow(
                  key: ValueKey(pay.id),
                  client: current,
                  paymentEvent: pay,
                  status: status,
                  currency: currency,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  static String _paymentStatusFor(Client client, DateTime date, String paymentEventId) {
    final dateKey = AppDateUtils.dateToStr(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final payDay = DateTime(date.year, date.month, date.day);

    final hasMultiplePaymentsThatDay = client.timeline
        .where((e) =>
          e.type == ClientTimelineEventType.payment &&
          AppDateUtils.dateToStr(e.createdAt) == dateKey)
        .length >
      1;

    // Prefer payment-specific status changes.
    for (final e in client.timeline.reversed) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
      if (e.refId != paymentEventId) continue;
      final s = e.status?.trim();
      if (s == 'Paid' || s == 'Paid fully') return 'Paid';
      if (s == 'Will pay later') return 'Will pay later';
      if (s == 'Unpaid') return 'Pending';
    }

    // Fallback to legacy date-based status changes (no refId).
    // If there are multiple payments that day, legacy status changes would
    // incorrectly affect all of them.
    if (!hasMultiplePaymentsThatDay) {
      for (final e in client.timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
        if (e.refId != null) continue;
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully') return 'Paid';
        if (s == 'Will pay later') return 'Will pay later';
        if (s == 'Unpaid') return 'Pending';
      }
    }

    if (payDay.isBefore(today)) return 'Pending';
    return 'Upcoming';
  }
}

/* ─────────────── Summary Chip ─────────────── */

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String currency;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currency}${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────── Payment Row ─────────────── */

class _PaymentRow extends StatelessWidget {
  final Client client;
  final ClientTimelineEvent paymentEvent;
  final String status;
  final String currency;

  const _PaymentRow({
    super.key,
    required this.client,
    required this.paymentEvent,
    required this.status,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final dateStr = AppDateUtils.displayDate(paymentEvent.createdAt);
    final amountStr = paymentEvent.amount != null
      ? '${currency}${paymentEvent.amount!.toStringAsFixed(0)}'
        : 'No amount';

    Color statusColor;
    if (status == 'Paid') {
      statusColor = VibrantColors.deep(VibrantColors.pastelGreen);
    } else if (status == 'Pending') {
      statusColor = VibrantColors.deep(VibrantColors.softPink);
    } else {
      statusColor = VibrantColors.deep(VibrantColors.warmYellow);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: chrome.mutedColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Date column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (paymentEvent.note != null &&
                      paymentEvent.note!.trim().isNotEmpty)
                    Text(
                      paymentEvent.note!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: chrome.mutedColor,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount
            Text(
              amountStr,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),

            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),

            // Status popup menu (compact arrow)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_drop_down,
                  size: 22, color: chrome.mutedColor),
              onSelected: (v) => _handleStatusChange(context, v),
              itemBuilder: (_) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final payDay = DateTime(
                  paymentEvent.createdAt.year,
                  paymentEvent.createdAt.month,
                  paymentEvent.createdAt.day,
                );
                final resetLabel = payDay.isBefore(today) ? 'Pending' : 'Upcoming';
                return [
                  PopupMenuItem(
                    value: '__reset__',
                    child: Text('Reset to $resetLabel'),
                  ),
                  const PopupMenuItem(value: 'Paid', child: Text('Paid')),
                  const PopupMenuItem(value: 'Paid fully', child: Text('Paid fully')),
                  const PopupMenuItem(
                    value: 'Will pay later',
                    child: Text('Will pay later'),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ── Status change handlers (same logic) ── */

  void _handleStatusChange(BuildContext context, String newStatus) {
    if (newStatus == '__reset__') {
      final dateKey = AppDateUtils.dateToStr(paymentEvent.createdAt);
      context.read<ClientBloc>().add(ClearPaymentStatusForDate(
        entityId: client.id,
        date: paymentEvent.createdAt,
        paymentId: paymentEvent.id,
      ));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final payDay = DateTime(
        paymentEvent.createdAt.year,
        paymentEvent.createdAt.month,
        paymentEvent.createdAt.day,
      );
      final resetLabel = payDay.isBefore(today) ? 'Pending' : 'Upcoming';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Payment reset to $resetLabel for $dateKey'),
        ),
      );
      return;
    }

    if (newStatus == 'Will pay later') {
      // Clear any existing paid marker for this payment/day, then tag as "Will pay later"
      // so UI/payment module can reflect the change immediately.
      context.read<ClientBloc>().add(ClearPaymentStatusForDate(
        entityId: client.id,
        date: paymentEvent.createdAt,
        paymentId: paymentEvent.id,
      ));

      context.read<ClientBloc>().add(UpdateClientStatus(
        entityId: client.id,
        status: 'Will pay later',
        createdAt: paymentEvent.createdAt,
        refId: paymentEvent.id,
      ));

      _openReschedule(context);
      return;
    }

    if (newStatus == 'Paid') {
      context.read<ClientBloc>().add(UpdateClientStatus(
        entityId: client.id,
        status: 'Paid',
        createdAt: paymentEvent.createdAt,
        refId: paymentEvent.id,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
                'Marked Paid for ${AppDateUtils.displayDate(paymentEvent.createdAt)}')),
      );
      return;
    }

    if (newStatus == 'Paid fully') {
      context.read<ClientBloc>().add(MarkClientPaidFully(
        entityId: client.id,
        fromDate: paymentEvent.createdAt,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: const Text('Combined remaining payments and recorded as paid today'),
        ),
      );
      return;
    }
  }

  /* ── Reschedule sheet ── */

  void _openReschedule(BuildContext context) {
    final parentContext = context;
    DateTime newDate = DateTime(
      paymentEvent.createdAt.year,
      paymentEvent.createdAt.month,
      paymentEvent.createdAt.day,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reschedule Payment',
                          style:
                              Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: newDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setSheetState(() {
                          newDate = DateTime(
                              picked.year, picked.month, picked.day);
                        });
                      },
                      child: Text(AppDateUtils.displayDate(newDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        _doReschedule(parentContext, newDate);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
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

  void _doReschedule(BuildContext context, DateTime newDate) {
    // Use the freshest state at the moment of saving.
    // Without this, the widget may hold a stale payment instance after
    // status changes/rebuilds, and the reschedule can appear to do nothing.
    Client? latestClient;
    ClientTimelineEvent? latestPayment;
    final blocState = context.read<ClientBloc>().state;
    if (blocState is ClientLoaded) {
      try {
        latestClient = blocState.entities.firstWhere((c) => c.id == client.id);
        latestPayment = latestClient.timeline.firstWhere(
          (e) => e.type == ClientTimelineEventType.payment && e.id == paymentEvent.id,
        );
      } catch (_) {
        // Fall back to the widget's captured values.
      }
    }

    final timeline = (latestClient ?? client).timeline;
    final effectivePayment = latestPayment ?? paymentEvent;

    final oldDay = DateTime(
      effectivePayment.createdAt.year,
      effectivePayment.createdAt.month,
      effectivePayment.createdAt.day,
    );
    final targetDay =
        DateTime(newDate.year, newDate.month, newDate.day);
    final targetKey = AppDateUtils.dateToStr(targetDay);

    if (AppDateUtils.dateToStr(oldDay) == targetKey) {
      return;
    }

    // Find existing payment on target date.
    ClientTimelineEvent? existing;
    for (final e in timeline) {
      if (identical(e, paymentEvent)) continue;
      if (e.type != ClientTimelineEventType.payment) continue;
      if (AppDateUtils.dateToStr(DateTime(
              e.createdAt.year, e.createdAt.month, e.createdAt.day)) ==
          targetKey) {
        existing = e;
        break;
      }
    }

    // If there is already a payment on the target day, we still reschedule.
    // Payments should remain separate; we do not merge amounts.
    if (existing != null) {
      context.read<ClientBloc>().add(RescheduleClientPayment(
        entityId: client.id,
        paymentId: effectivePayment.id,
        oldDate: oldDay,
        newDate: targetDay,
      ));
      return;
    }

    // Simple move.
    context.read<ClientBloc>().add(RescheduleClientPayment(
      entityId: client.id,
      paymentId: effectivePayment.id,
      oldDate: oldDay,
      newDate: targetDay,
    ));
  }
}

/* ─────────────── Detail Row ─────────────── */

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
