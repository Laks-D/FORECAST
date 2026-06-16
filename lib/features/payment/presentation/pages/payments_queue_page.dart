import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/app/app_mode.dart';

import 'package:snow/design_system/widgets/app_empty_state.dart';
import 'package:snow/design_system/widgets/app_loading.dart';
import 'package:snow/design_system/widgets/app_search_field.dart';

import '../../../client/domain/entities/client.dart';
import 'package:snow/design_system/theme/app_chrome_theme.dart';
import 'package:snow/design_system/theme/app_visual_style.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../client/presentation/bloc/client_event.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../domain/entities/payment.dart';
import 'client_transactions_page.dart';

class PaymentsQueuePage extends StatefulWidget {
  const PaymentsQueuePage({super.key, this.embedInDashboard = false});

  final bool embedInDashboard;

  @override
  State<PaymentsQueuePage> createState() => _PaymentsQueuePageState();
}

class _PaymentsQueuePageState extends State<PaymentsQueuePage> {
  String _query = '';
  // null = All; 'Paid', 'Unpaid', 'Overdue'
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);
    final defaultCurrency = context.select((UserProfileCubit c) => c.state.currency);
    final bgColor = scheme.surface;
    final onSurface = scheme.onSurface;
    final isClient = AppModeScope.isClient(context);
    final paymentRepository = context.read<ClientBloc>().paymentRepository;

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
                  const SizedBox(height: 12),
                  // ── Filter pills ─────────────────────────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterPill(
                          label: 'All',
                          selected: _filterStatus == null,
                          onTap: () => setState(() => _filterStatus = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Paid',
                          color: VibrantColors.pastelGreen,
                          selected: _filterStatus == 'Paid',
                          onTap: () => setState(() => _filterStatus = 'Paid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Unpaid',
                          color: VibrantColors.warmYellow,
                          selected: _filterStatus == 'Unpaid',
                          onTap: () => setState(() => _filterStatus = 'Unpaid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Overdue',
                          color: const Color(0xFFEF4444),
                          selected: _filterStatus == 'Overdue',
                          onTap: () => setState(() => _filterStatus = 'Overdue'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, state) {
                        if (state is! ClientLoaded) {
                          return AppLoading(color: onSurface);
                        }

                        return StreamBuilder<List<Payment>>(
                          stream: paymentRepository.watchAll(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return AppLoading(color: onSurface);
                            }
                            
                            var rawPayments = snapshot.data!;
                            
                            if (isClient) {
                               final uid = context.read<ClientBloc>().state is ClientLoaded 
                                  ? (context.read<ClientBloc>().state as ClientLoaded).entities.firstOrNull?.firebaseUid 
                                  : null;
                               rawPayments = rawPayments.where((p) => p.firebaseUid == uid).toList();
                            }
                            
                            if (rawPayments.isEmpty && state.entities.isEmpty) {
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

                            final mappedPayments = _mapPayments(rawPayments, state.entities);

                            bool matchesQuery(_PaymentVM p) {
                              if (_query.isEmpty) return true;

                              if (!isClient) {
                              return p.customerName
                                  .toLowerCase()
                                  .contains(_query) ||
                                p.contact.toLowerCase().contains(_query);
                              }

                              final note = (p.note ?? '').toLowerCase();
                              final date = _formatDate(p.paidAt).toLowerCase();
                              final amount = p.amount.toStringAsFixed(0);
                              return note.contains(_query) ||
                                date.contains(_query) ||
                                amount.contains(_query);
                            }

                            final payments = mappedPayments
                              .where((p) {
                                // Filter by status tab
                                if (_filterStatus != null &&
                                    p.paymentStatus != _filterStatus) {
                                  return false;
                                }
                                // Filter by search query
                                return matchesQuery(p);
                              })
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

                            return RefreshIndicator(
                              onRefresh: () async {
                                context.read<ClientBloc>().add(LoadClients());
                                // Wait a short duration to let the bloc state update
                                await Future.delayed(const Duration(milliseconds: 800));
                              },
                              child: ListView.builder(
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
                                            '${item.currency}${item.total.toStringAsFixed(0)}',
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
                                    padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
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
                                                  child: ClientTransactionsPage(clientId: payment.entityId),
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
                                                    color: _paymentStatusColor(payment.paymentStatus).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: _paymentStatusColor(payment.paymentStatus).withOpacity(0.25)),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    _paymentStatusIcon(payment.paymentStatus),
                                                    color: _paymentStatusColor(payment.paymentStatus),
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
                                                      '${payment.currency}${payment.amount.toStringAsFixed(0)}',
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
                              ),
                            );
                          }
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
    final paidTotals = <int, double>{};
    final currencies = <int, String>{};
    for (final p in payments) {
      final key = ymKey(p.paidAt);
      totals[key] = (totals[key] ?? 0) + p.amount;
      if (p.paymentStatus == 'Paid') {
        paidTotals[key] = (paidTotals[key] ?? 0) + p.amount;
      }
      currencies[key] = p.currency;
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
            paidTotal: paidTotals[key] ?? 0,
            currency: currencies[key] ?? '',
          ),
        );
      }
      items.add(_PaymentItem(p));
    }
    return items;
  }

  /* ================= HELPERS ================= */

  /// Returns ALL payment events as VMs, grouped by client + day.
  /// Each VM has a `paymentStatus` of 'Paid', 'Unpaid', or 'Overdue'.
  List<_PaymentVM> _mapPayments(List<Payment> payments, List<Client> clients) {
    final now = DateTime.now();
    final singles = <_PaymentSingleVM>[];

    for (final payment in payments) {
      final client = clients.cast<Client?>().firstWhere((c) => c?.id == payment.clientId, orElse: () => null);
      if (client == null) continue;

      final isPaid = payment.status == PaymentStatus.paid;
      final isOverdue = !isPaid && payment.dueDate.isBefore(now);
      final status = isPaid
          ? 'Paid'
          : isOverdue
              ? 'Overdue'
              : 'Unpaid';

      singles.add(
        _PaymentSingleVM(
          entityId: client.id,
          customerName: client.name,
          contact: client.formattedPhone,
          amount: payment.amount,
          paidAt: payment.dueDate,
          note: payment.note,
          currency: payment.currency ?? client.currency ?? 'USD',
          paymentStatus: status,
        ),
      );
    }

    // Group by client + day + status so each combination gets its own card.
    final grouped = <String, _PaymentVM>{};
    for (final p in singles) {
      final dayKey = AppDateUtils.dateToStr(p.paidAt);
      final key = '${p.entityId}::$dayKey::${p.paymentStatus}';

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
          currency: p.currency,
          paymentStatus: p.paymentStatus,
        );
        continue;
      }

      grouped[key] = existing.copyWith(
        amount: existing.amount + p.amount,
        paymentCount: existing.paymentCount + 1,
        note: _mergeNote(existing.note, p.note),
        paidAt: existing.paidAt.isAfter(p.paidAt) ? existing.paidAt : p.paidAt,
      );
    }

    final out = grouped.values.toList();
    out.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return out;
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return VibrantColors.pastelGreen;
      case 'Overdue':
        return const Color(0xFFEF4444);
      default:
        return VibrantColors.warmYellow;
    }
  }

  IconData _paymentStatusIcon(String status) {
    switch (status) {
      case 'Paid':
        return Icons.check_circle_outline;
      case 'Overdue':
        return Icons.warning_amber_outlined;
      default:
        return Icons.schedule_outlined;
    }
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
  final String currency;
  /// 'Paid', 'Unpaid', or 'Overdue'
  final String paymentStatus;

  _PaymentVM({
    required this.entityId,
    required this.customerName,
    required this.contact,
    required this.amount,
    required this.note,
    required this.paidAt,
    required this.paymentCount,
    required this.currency,
    this.paymentStatus = 'Paid',
  });

  _PaymentVM copyWith({
    double? amount,
    String? note,
    DateTime? paidAt,
    int? paymentCount,
    String? paymentStatus,
  }) {
    return _PaymentVM(
      entityId: entityId,
      customerName: customerName,
      contact: contact,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      paidAt: paidAt ?? this.paidAt,
      paymentCount: paymentCount ?? this.paymentCount,
      currency: currency,
      paymentStatus: paymentStatus ?? this.paymentStatus,
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
  final String currency;
  final String paymentStatus;

  _PaymentSingleVM({
    required this.entityId,
    required this.customerName,
    required this.contact,
    required this.amount,
    required this.note,
    required this.paidAt,
    required this.currency,
    this.paymentStatus = 'Unpaid',
  });
}

/* ================= LIST ITEMS ================= */

abstract class _PaymentsListItem {
  const _PaymentsListItem();
}

class _MonthHeaderItem extends _PaymentsListItem {
  const _MonthHeaderItem({
    required this.label,
    required this.total,
    required this.paidTotal,
    required this.currency,
  });

  final String label;
  final double total;
  /// Total of only 'Paid' entries for the monthly revenue summary.
  final double paidTotal;
  final String currency;
}

class _PaymentItem extends _PaymentsListItem {
  const _PaymentItem(this.payment);

  final _PaymentVM payment;
}

/* ================= FILTER PILL ================= */

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = color ?? scheme.primary;
    final bg = selected
        ? accentColor.withOpacity(0.18)
        : scheme.surface;
    final border = selected
        ? accentColor.withOpacity(0.45)
        : scheme.outlineVariant.withOpacity(0.5);
    final fg = selected ? accentColor : scheme.onSurface.withOpacity(0.65);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
