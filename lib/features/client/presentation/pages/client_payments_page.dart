import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${entity.name} — Payments'),
      ),
      body: BlocBuilder<ClientBloc, ClientState>(
        builder: (context, state) {
          final current = _findUpdatedEntity(state) ?? entity;
          final payments = [...current.payments]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (payments.isEmpty) {
            return const Center(
              child: Text('No scheduled payments'),
            );
          }

          // Compute summary.
          double paidTotal = 0;
          double pendingTotal = 0;
          double overdueTotal = 0;
          for (final pay in payments) {
            final s = _paymentStatusFor(current, pay.createdAt);
            final amt = pay.amount ?? 0;
            if (s == 'Paid') {
              paidTotal += amt;
            } else if (s == 'Overdue') {
              overdueTotal += amt;
            } else {
              pendingTotal += amt;
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
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 12),
                      _SummaryChip(
                        label: 'Pending',
                        amount: pendingTotal,
                        color: Colors.orange.shade700,
                      ),
                      if (overdueTotal > 0) ...[
                        const SizedBox(width: 12),
                        _SummaryChip(
                          label: 'Overdue',
                          amount: overdueTotal,
                          color: Colors.red.shade700,
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
                final status = _paymentStatusFor(current, pay.createdAt);
                return _PaymentRow(
                  client: current,
                  paymentEvent: pay,
                  status: status,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  static String _paymentStatusFor(Client client, DateTime date) {
    final dateKey = AppDateUtils.dateToStr(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final payDay = DateTime(date.year, date.month, date.day);

    // Check for Paid fully coverage from an earlier date.
    for (final e in client.timeline) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (e.status?.trim() != 'Paid fully') continue;
      final sKey = AppDateUtils.dateToStr(e.createdAt);
      if (sKey.compareTo(dateKey) < 0) return 'Paid';
    }

    for (final e in client.timeline.reversed) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (AppDateUtils.dateToStr(e.createdAt) != dateKey) continue;
      final s = e.status?.trim();
      if (s == 'Paid' || s == 'Paid fully') return 'Paid';
    }

    if (payDay.isBefore(today)) return 'Overdue';
    return 'Pending';
  }
}

/* ─────────────── Summary Chip ─────────────── */

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
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
            '₹${amount.toStringAsFixed(0)}',
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

  const _PaymentRow({
    required this.client,
    required this.paymentEvent,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final dateStr = AppDateUtils.displayDate(paymentEvent.createdAt);
    final amountStr = paymentEvent.amount != null
        ? '₹${paymentEvent.amount!.toStringAsFixed(0)}'
        : 'No amount';

    Color statusColor;
    if (status == 'Paid') {
      statusColor = Colors.green.shade700;
    } else if (status == 'Overdue') {
      statusColor = Colors.red.shade700;
    } else {
      statusColor = Colors.orange.shade700;
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'Pending', child: Text('Pending')),
                PopupMenuItem(value: 'Paid', child: Text('Paid')),
                PopupMenuItem(
                    value: 'Paid fully', child: Text('Paid fully')),
                PopupMenuItem(
                    value: 'Will pay later',
                    child: Text('Will pay later')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* ── Status change handlers (same logic) ── */

  /// Returns true if a "Paid fully" event covers [date] (same day or earlier).
  bool _hasPaidFullyCoverage(DateTime date) {
    final dateKey = AppDateUtils.dateToStr(date);
    for (final e in client.timeline) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (e.status?.trim() != 'Paid fully') continue;
      final sKey = AppDateUtils.dateToStr(e.createdAt);
      if (sKey.compareTo(dateKey) <= 0) return true;
    }
    return false;
  }

  void _handleStatusChange(BuildContext context, String newStatus) {
    if (newStatus == 'Pending') {
      // If covered by "Paid fully", ask to revert the whole thing.
      if (_hasPaidFullyCoverage(paymentEvent.createdAt)) {
        showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Revert Paid Fully?'),
            content: const Text(
              'This payment was marked via "Paid fully". '
              'Reverting will reset ALL payments that were covered.\n\n'
              'Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Revert'),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true && context.mounted) {
            context.read<ClientBloc>().add(
                  RevertClientPaidFully(entityId: client.id),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 1),
                content: Text('Paid fully reverted'),
              ),
            );
          }
        });
        return;
      }

      final dateKey = AppDateUtils.dateToStr(paymentEvent.createdAt);
      context.read<ClientBloc>().add(ClearPaymentStatusForDate(
        entityId: client.id,
        date: paymentEvent.createdAt,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Payment reset to Pending for $dateKey'),
        ),
      );
      return;
    }

    if (newStatus == 'Will pay later') {
      // If currently paid, clear the paid status first, then reschedule.
      if (status == 'Paid') {
        if (_hasPaidFullyCoverage(paymentEvent.createdAt)) {
          context.read<ClientBloc>().add(
                RevertClientPaidFully(entityId: client.id),
              );
        } else {
          context.read<ClientBloc>().add(ClearPaymentStatusForDate(
            entityId: client.id,
            date: paymentEvent.createdAt,
          ));
        }
      }
      _openReschedule(context);
      return;
    }

    if (newStatus == 'Paid') {
      context.read<ClientBloc>().add(UpdateClientStatus(
        entityId: client.id,
        status: 'Paid',
        createdAt: paymentEvent.createdAt,
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
      final baseKey = AppDateUtils.dateToStr(paymentEvent.createdAt);
      context.read<ClientBloc>().add(MarkClientPaidFully(
        entityId: client.id,
        fromDate: paymentEvent.createdAt,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Marked Paid fully from $baseKey'),
        ),
      );
      return;
    }
  }

  /* ── Reschedule sheet ── */

  void _openReschedule(BuildContext context) {
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
                        _doReschedule(ctx, newDate);
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
    final timeline = client.timeline;
    final oldDay = DateTime(
      paymentEvent.createdAt.year,
      paymentEvent.createdAt.month,
      paymentEvent.createdAt.day,
    );
    final targetDay =
        DateTime(newDate.year, newDate.month, newDate.day);
    final targetKey = AppDateUtils.dateToStr(targetDay);

    if (AppDateUtils.dateToStr(oldDay) == targetKey) {
      Navigator.of(context).pop();
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

    if (existing != null) {
      final existingAmt = existing.amount ?? 0;
      final oldAmt = paymentEvent.amount ?? 0;
      final merged = existingAmt + oldAmt;

      showDialog<bool>(
        context: context,
        builder: (dCtx) {
          return AlertDialog(
            title: const Text('Warning'),
            content: Text(
              '${client.name} already has ₹${existingAmt.toStringAsFixed(0)} on $targetKey.\n'
              'Merge with ₹${oldAmt.toStringAsFixed(0)} for a total of ₹${merged.toStringAsFixed(0)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dCtx).pop(true),
                child: const Text('Merge'),
              ),
            ],
          );
        },
      ).then((ok) {
        if (ok != true) return;

        if (!context.mounted) return;

        final ex = existing!;
        String? mergedNote;
        if (ex.note != null && ex.note!.trim().isNotEmpty) {
          mergedNote = ex.note!.trim();
        } else if (paymentEvent.note != null &&
            paymentEvent.note!.trim().isNotEmpty) {
          mergedNote = paymentEvent.note!.trim();
        }

        context.read<ClientBloc>().add(MergeClientPayments(
          entityId: client.id,
          sourcePaymentId: paymentEvent.id,
          sourceDate: oldDay,
          targetPaymentId: ex.id,
          targetDate: targetDay,
          mergedAmount: merged,
          mergedNote: mergedNote,
        ));

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return;
    }

    // Simple move.
    context.read<ClientBloc>().add(RescheduleClientPayment(
      entityId: client.id,
      paymentId: paymentEvent.id,
      oldDate: oldDay,
      newDate: targetDay,
    ));

    Navigator.of(context).pop();
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
