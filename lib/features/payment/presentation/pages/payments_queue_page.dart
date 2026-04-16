import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/app/app_mode.dart';

import 'package:gendral_app/design_system/widgets/app_empty_state.dart';
import 'package:gendral_app/design_system/widgets/app_loading.dart';
import 'package:gendral_app/design_system/widgets/app_search_field.dart';

import '../../../client/domain/entities/client.dart';
import '../../../client/domain/entities/client_timeline_event.dart';
import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
import 'package:gendral_app/design_system/theme/app_visual_style.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import 'client_transactions_page.dart';

// Helper VM for single payment extraction
class _PaymentSingleVM {
  final String entityId;
  final String customerName;
  final String contact;
  final double amount;
  final String? note;
  final DateTime paidAt;

  _PaymentSingleVM({
    required this.entityId,
    required this.customerName,
    required this.contact,
    required this.amount,
    required this.note,
    required this.paidAt,
  });
}

class PaymentsQueuePage extends StatefulWidget {
  const PaymentsQueuePage({super.key, this.embedInDashboard = false});

  final bool embedInDashboard;

  @override
  State<PaymentsQueuePage> createState() => _PaymentsQueuePageState();
}

// ================= INTERNAL VIEW MODEL & LIST ITEMS =================

class _PaymentVM {
  final String entityId;
  final String customerName;
  final String contact;
  final double amount;
  final String? note;
  final DateTime paidAt;
  final int paymentCount;

  _PaymentVM({
    required this.entityId,
    required this.customerName,
    required this.contact,
    required this.amount,
    required this.note,
    required this.paidAt,
    required this.paymentCount,
  });

  _PaymentVM copyWith({
    double? amount,
    String? note,
    DateTime? paidAt,
    int? paymentCount,
  }) {
    return _PaymentVM(
      entityId: entityId,
      customerName: customerName,
      contact: contact,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      paidAt: paidAt ?? this.paidAt,
      paymentCount: paymentCount ?? this.paymentCount,
    );
  }
}

abstract class _PaymentsListItem {
  const _PaymentsListItem();
}

class _MonthHeaderItem extends _PaymentsListItem {
  const _MonthHeaderItem({required this.label, required this.total});
  final String label;
  final double total;
}

class _PaymentItem extends _PaymentsListItem {
  const _PaymentItem(this.payment);
  final _PaymentVM payment;
}

class _PaymentsQueuePageState extends State<PaymentsQueuePage> {
    String _formatDate(DateTime dt) {
      return AppDateUtils.displayDate(dt);
    }
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);
    final defaultCurrency = context.select((UserProfileCubit c) => c.state.currency);
    final bgColor = scheme.surface;
    final onSurface = scheme.onSurface;
    final isClient = AppModeScope.isClient(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SafeArea(
            top: !widget.embedInDashboard,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      isClient ? 'My payments' : 'Payment',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppSearchField(
                      hintText:
                          isClient ? 'Search note / date / amount' : 'Search customer / phone',
                      onChanged: (value) {
                        setState(() => _query = value.toLowerCase().trim());
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, state) {
                        if (state is! ClientLoaded) {
                          return AppLoading(color: onSurface);
                        }

                        if (state.entities.isEmpty) {
                          return Center(
                            child: AppEmptyState(
                              message: isClient
                                  ? 'No profile linked to this account'
                                  : 'No payments found',
                              icon: isClient
                                  ? Icons.person_outline
                                  : Icons.payments_outlined,
                            ),
                          );
                        }

                        bool matchesQuery(_PaymentVM p) {
                          if (_query.isEmpty) return true;

                          if (!isClient) {
                          return p.customerName
                              .toLowerCase()
                              .contains(_query) ||
                            p.contact.contains(_query);
                          }

                          final note = (p.note ?? '').toLowerCase();
                          final date = _formatDate(p.paidAt).toLowerCase();
                          final amount = p.amount.toStringAsFixed(0);
                          return note.contains(_query) ||
                            date.contains(_query) ||
                            amount.contains(_query);
                        }

                        final payments = _extractPaidPayments(state.entities)
                          .where(matchesQuery)
                          .toList();

                        if (payments.isEmpty) {
                          return const Center(
                            child: AppEmptyState(
                              message: 'No payments found',
                              icon: Icons.payments_outlined,
                            ),
                          );
                        }

                        final listItems = _buildMonthGroupedItems(payments);

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];
                            if (item is _MonthHeaderItem) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: chrome.mutedColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${defaultCurrency}${item.total.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: chrome.textColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final payment = (item as _PaymentItem).payment;
                            final subtitle = () {
                              final rawNote = (payment.note ?? '').trim();

                              if (payment.paymentCount <= 1) {
                                if (rawNote.isEmpty) return '';
                                return rawNote;
                              }

                              if (rawNote.isEmpty || rawNote == 'Multiple payments') {
                                return '${payment.paymentCount} payments';
                              }

                              return '${payment.paymentCount} payments • $rawNote';
                            }();

                            final cardColor = visual.neumorphism
                                ? scheme.surface
                                : chrome.surfaceColor;
                            final shadows = visual.neumorphism
                                ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
                                : <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
                                  boxShadow: shadows,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // If this payment is 'Paid fully', update all for this client+date to 'Paid'
                                      if ((payment.note?.toLowerCase().contains('paid fully') ?? false)) {
                                        // TODO: Dispatch a Bloc event or call your repository/service here to update
                                        // all payments for this client and date to status 'Paid'.
                                        // Example:
                                        // context.read<ClientBloc>().add(UpdatePaymentsStatus(
                                        //   clientId: payment.entityId,
                                        //   date: payment.paidAt,
                                        //   status: 'Paid',
                                        // ));
                                      }
                                      final entity = state.entities.firstWhere(
                                        (e) => e.id == payment.entityId,
                                      );
                                      final clientBloc = context.read<ClientBloc>();
                                      final sessionsCubit = context.read<SessionsCubit>();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MultiBlocProvider(
                                            providers: [
                                              BlocProvider.value(value: clientBloc),
                                              BlocProvider.value(value: sessionsCubit),
                                            ],
                                            child: ClientTransactionsPage(clientId: entity.id),
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(28),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 58,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              color: VibrantColors.pastelGreen.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: VibrantColors.pastelGreen.withOpacity(0.2)),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.payments_outlined,
                                              color: VibrantColors.pastelGreen,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  payment.customerName,
                                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                        color: chrome.textColor,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 18,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  payment.contact,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: chrome.mutedColor,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                ),
                                                if (subtitle.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    subtitle,
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: chrome.mutedColor.withOpacity(0.7),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${defaultCurrency}${payment.amount.toStringAsFixed(0)}',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      color: chrome.textColor,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 20,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(payment.paidAt).toUpperCase(),
                                                style: TextStyle(
                                                  color: chrome.mutedColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_PaymentsListItem> _buildMonthGroupedItems(List<_PaymentVM> payments) {
    int ymKey(DateTime d) => d.year * 100 + d.month;

    String monthLabel(DateTime d) {
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      return '${months[d.month - 1]} ${d.year}';
    }

    final totals = <int, double>{};
    for (final p in payments) {
      final key = ymKey(p.paidAt);
      totals[key] = (totals[key] ?? 0) + p.amount;
    }

    final items = <_PaymentsListItem>[];
    int? lastKey;
    for (final p in payments) {
      final key = ymKey(p.paidAt);
      if (lastKey != key) {
        lastKey = key;
        items.add(
          _MonthHeaderItem(
            label: monthLabel(p.paidAt),
            total: totals[key] ?? 0,
          ),
        );
      }
          // Do NOT merge payments for 'Paid fully' (show each payment as a separate row)
          items.add(_PaymentItem(p));
    }
    return items;
  }

  /* ================= HELPERS ================= */

  bool _isPaymentPaid({
    required Client client,
    required ClientTimelineEvent payment,
  }) {
    final dateKey = AppDateUtils.dateToStr(payment.createdAt);

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
      if (e.refId != payment.id) continue;
      final s = e.status?.trim();
      if (s == 'Paid' || s == 'Paid fully') return true;
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
        if (s == 'Paid' || s == 'Paid fully') return true;
      }
    }

    return false;
  }

  List<_PaymentVM> _extractPaidPayments(List<Client> entities) {
    // Build per-payment VMs first (so paid-logic remains correct), then
    // group by client + day for the Payment tab UI.
    final singles = <_PaymentSingleVM>[];
    for (final entity in entities) {
      for (final event in entity.timeline) {
        if (event.type != ClientTimelineEventType.payment) continue;
        if (!_isPaymentPaid(client: entity, payment: event)) continue;

        singles.add(
          _PaymentSingleVM(
            entityId: entity.id,
            customerName: entity.name,
            contact: entity.formattedPhone,
            amount: event.amount ?? 0,
            paidAt: event.createdAt,
            note: event.note,
          ),
        );
      }
    }

    // Absolutely no merging: every payment is a separate entry, with its own status and amount
    final out = singles.map((p) => _PaymentVM(
      entityId: p.entityId,
      customerName: p.customerName,
      contact: p.contact,
      amount: p.amount,
      paidAt: p.paidAt,
      note: p.note,
      paymentCount: 1,
    )).toList();
    out.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return out;
  }

  String? _mergeNote(String? a, String? b) {
    final aa = (a ?? '').trim();
    final bb = (b ?? '').trim();
    if (aa.isEmpty && bb.isEmpty) return null;
    if (aa.isEmpty) return bb;
    if (bb.isEmpty) return aa;
    if (aa == bb) return aa;
    return 'Multiple payments';
  }
}

