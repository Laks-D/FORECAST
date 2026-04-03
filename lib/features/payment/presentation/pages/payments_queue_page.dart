import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';

import 'package:gendral_app/design_system/widgets/app_empty_state.dart';
import 'package:gendral_app/design_system/widgets/app_loading.dart';
import 'package:gendral_app/design_system/widgets/app_search_field.dart';

import '../../../client/domain/entities/client.dart';
import '../../../client/domain/entities/client_timeline_event.dart';
import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import 'client_transactions_page.dart';

class PaymentsQueuePage extends StatefulWidget {
  const PaymentsQueuePage({super.key, this.embedInDashboard = false});

  final bool embedInDashboard;

  @override
  State<PaymentsQueuePage> createState() => _PaymentsQueuePageState();
}

class _PaymentsQueuePageState extends State<PaymentsQueuePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: Stack(
        children: [
          SafeArea(
            top: !widget.embedInDashboard,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AppSearchField(
                    hintText: 'Search customer / phone',
                    onChanged: (value) {
                      setState(() => _query = value.toLowerCase().trim());
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, state) {
                        if (state is! ClientLoaded) {
                          return const AppLoading(color: Colors.white);
                        }

                        final payments = _extractPaidPayments(state.entities)
                            .where(
                              (p) =>
                                  p.customerName
                                      .toLowerCase()
                                      .contains(_query) ||
                                  p.contact.contains(_query),
                            )
                            .toList();

                        if (payments.isEmpty) {
                          return const Center(
                            child: AppEmptyState(
                              message: 'No payments found',
                              icon: Icons.payments_outlined,
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: payments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final payment = payments[index];
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

                            return Container(
                              decoration: BoxDecoration(
                                color: chrome.surfaceColor,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
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
                                              '₹${payment.amount.toStringAsFixed(0)}',
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    color: Colors.white,
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

    final grouped = <String, _PaymentVM>{};
    for (final p in singles) {
      final dayKey = AppDateUtils.dateToStr(p.paidAt);
      final key = '${p.entityId}::$dayKey';

      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = _PaymentVM(
          entityId: p.entityId,
          customerName: p.customerName,
          contact: p.contact,
          amount: p.amount,
          paidAt: p.paidAt,
          note: p.note,
          paymentCount: 1,
        );
        continue;
      }

      grouped[key] = existing.copyWith(
        amount: existing.amount + p.amount,
        paymentCount: existing.paymentCount + 1,
        note: _mergeNote(existing.note, p.note),
        // keep the date stable; but ensure we sort properly if times differ
        paidAt: existing.paidAt.isAfter(p.paidAt) ? existing.paidAt : p.paidAt,
      );
    }

    final out = grouped.values.toList();
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

  String _formatDate(DateTime dt) {
    return AppDateUtils.displayDate(dt);
  }
}

/* ================= INTERNAL VIEW MODEL ================= */

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
