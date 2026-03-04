import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';

import '../../../client/domain/entities/client.dart';
import '../../../client/domain/entities/client_timeline_event.dart';
import 'package:gendral_app/design_system/theme/app_chrome_theme.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _query = value.toLowerCase().trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search customer / phone',
                        prefixIcon: const Icon(Icons.search),
                        prefixIconColor: chrome.mutedColor,
                        hintStyle: TextStyle(color: chrome.mutedColor),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, state) {
                        if (state is! ClientLoaded) {
                          return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        final payments = _extractPaidSummaries(state.entities)
                            .where(
                              (p) =>
                                  p.customerName
                                      .toLowerCase()
                                      .contains(_query) ||
                                  p.contact.contains(_query),
                            )
                            .toList();

                        if (payments.isEmpty) {
                          return Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                child: Text(
                                  'No payments found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: chrome.mutedColor),
                                ),
                              ),
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

                            return InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () {
                                final entity = state.entities.firstWhere(
                                  (e) => e.id == payment.entityId,
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClientTransactionsPage(clientId: entity.id),
                                  ),
                                );
                              },
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color:
                                              scheme.primary.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.payments_outlined,
                                          color: scheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              payment.customerName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              payment.contact,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      color: chrome.mutedColor),
                                            ),
                                            if (payment.note != null &&
                                                payment.note!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                payment.note!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                        color:
                                                            chrome.mutedColor),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Paid',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: chrome.mutedColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${payment.totalAmount.toStringAsFixed(0)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w900),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatDate(payment.lastPaidAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    color: chrome.mutedColor),
                                          ),
                                        ],
                                      ),
                                    ],
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

  bool _isPaidOnDate(Client client, DateTime date) {
    final key = _formatKey(date);
    for (final e in client.timeline.reversed) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      if (_formatKey(e.createdAt) != key) continue;
      final s = e.status?.trim();
      if (s == 'Paid fully' || s == 'Paid') return true;
    }
    return false;
  }

  List<_PaymentSummaryVM> _extractPaidSummaries(List<Client> entities) {
    final out = <_PaymentSummaryVM>[];
    for (final entity in entities) {
      double total = 0;
      DateTime? latest;
      String? lastNote;

      for (final event in entity.timeline) {
        if (event.type != ClientTimelineEventType.payment) continue;
        if (!_isPaidOnDate(entity, event.createdAt)) continue;

        total += event.amount ?? 0;
        if (latest == null || event.createdAt.isAfter(latest)) {
          latest = event.createdAt;
          lastNote = event.note;
        }
      }

      if (total > 0 && latest != null) {
        out.add(
          _PaymentSummaryVM(
            entityId: entity.id,
            customerName: entity.name,
            contact: entity.formattedPhone,
            totalAmount: total,
            lastPaidAt: latest,
            note: lastNote,
          ),
        );
      }
    }

    out.sort((a, b) => b.lastPaidAt.compareTo(a.lastPaidAt));
    return out;
  }

  String _formatKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return AppDateUtils.displayDate(dt);
  }
}

/* ================= INTERNAL VIEW MODEL ================= */

class _PaymentSummaryVM {
  final String entityId;
  final String customerName;
  final String contact;
  final double totalAmount;
  final String? note;
  final DateTime lastPaidAt;

  _PaymentSummaryVM({
    required this.entityId,
    required this.customerName,
    required this.contact,
    required this.totalAmount,
    required this.note,
    required this.lastPaidAt,
  });
}
