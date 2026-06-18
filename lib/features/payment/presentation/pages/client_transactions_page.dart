import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app/app_mode.dart';
import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/utils/date_utils.dart';

import 'package:snow/design_system/widgets/app_card.dart';
import 'package:snow/design_system/widgets/app_empty_state.dart';
import 'package:snow/design_system/widgets/app_loading.dart';

import '../../../client/domain/entities/client.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../client/presentation/pages/client_profile_page.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';

class ClientTransactionsPage extends StatefulWidget {
  const ClientTransactionsPage({
    super.key,
    required this.clientId,
    this.fromProfile = false,
  });

  final String clientId;
  final bool fromProfile;

  @override
  State<ClientTransactionsPage> createState() => _ClientTransactionsPageState();
}

class _ClientTransactionsPageState extends State<ClientTransactionsPage> {
  late Stream<List<Payment>> _paymentsStream;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final clientBloc = context.read<ClientBloc>();
      final client = _findClient(clientBloc.state);
      final paymentRepository = clientBloc.paymentRepository;
      _paymentsStream = AppModeScope.isClient(context)
          ? paymentRepository.watchForStudent(client?.firebaseUid ?? '')
          : paymentRepository.watchForClient(widget.clientId);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.surface;
    final onSurface = scheme.onSurface;
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: onSurface,
        elevation: 0,
        title: const Text('Transactions'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: BlocBuilder<ClientBloc, ClientState>(
            builder: (context, state) {
              if (state is! ClientLoaded) {
                return AppLoading(color: onSurface);
              }

              final client = _findClient(state);
              if (client == null) {
                return const Center(
                  child: AppEmptyState(
                    message: 'Client not found',
                    icon: Icons.error_outline,
                  ),
                );
              }

              final currency = client.currency ?? defaultCurrency;
              final paymentRepository = context.read<ClientBloc>().paymentRepository;

              return StreamBuilder<List<Payment>>(
                stream: _paymentsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return AppLoading(color: onSurface);
                  }

                  final payments = snapshot.data!.toList();
                  payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
                  final listItems = _buildMonthGroupedItems(payments);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(
                        client: client,
                        onTap: AppModeScope.isClient(context)
                            ? null
                            : () {
                                if (widget.fromProfile) {
                                  Navigator.of(context).pop();
                                } else {
                                  final clientBloc = context.read<ClientBloc>();
                                  final sessionsCubit = context.read<SessionsCubit>();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MultiBlocProvider(
                                        providers: [
                                          BlocProvider.value(value: clientBloc),
                                          BlocProvider.value(value: sessionsCubit),
                                        ],
                                        child: ClientProfilePage(entity: client),
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(payments: payments, currency: currency),
                      const SizedBox(height: 14),
                      Expanded(
                        child: payments.isEmpty
                            ? const Center(
                                child: AppEmptyState(
                                  message: 'No transactions yet',
                                  icon: Icons.receipt_long_outlined,
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: listItems.length,
                                itemBuilder: (context, index) {
                                  final item = listItems[index];
                                  if (item is _MonthHeaderItem) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(2, 2, 2, 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    color: AppChromeTheme.of(context)
                                                        .mutedColor,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            '${currency}${item.total.toStringAsFixed(0)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final p = (item as _PaymentItem).payment;
                                  final isTutor = !AppModeScope.isClient(context);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _TransactionCard(
                                      payment: p, 
                                      currency: currency,
                                      onTap: isTutor ? () => _showEditStatusSheet(context, p) : null,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEditStatusSheet(BuildContext context, Payment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: VibrantColors.pastelGreen),
                  title: const Text('Paid', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    context.read<ClientBloc>().paymentRepository.setStatus(payment.paymentId, PaymentStatus.paid);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined, color: VibrantColors.warmYellow),
                  title: const Text('Unpaid', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    context.read<ClientBloc>().paymentRepository.setStatus(payment.paymentId, PaymentStatus.unpaid);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Client? _findClient(ClientState state) {
    if (state is! ClientLoaded) return null;
    for (final c in state.entities) {
      if (c.id == widget.clientId) return c;
    }
    return null;
  }

  List<_PaymentsListItem> _buildMonthGroupedItems(List<Payment> payments) {
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
      final key = ymKey(p.dueDate);
      totals[key] = (totals[key] ?? 0) + p.amount;
    }

    final items = <_PaymentsListItem>[];
    int? lastKey;
    for (final p in payments) {
      final key = ymKey(p.dueDate);
      if (lastKey != key) {
        lastKey = key;
        items.add(
          _MonthHeaderItem(
            label: monthLabel(p.dueDate),
            total: totals[key] ?? 0,
          ),
        );
      }
      items.add(_PaymentItem(p));
    }
    return items;
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

  final Payment payment;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.client, this.onTap});

  final Client client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return AppCard(
      onTap: onTap,
      border: Border.all(color: scheme.outlineVariant.withOpacity(0.35), width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              client.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              client.formattedPhone,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chrome.mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.payment, required this.currency, this.onTap});

  final Payment payment;
  final String currency;
  final VoidCallback? onTap;

  bool get isPaid => payment.status == PaymentStatus.paid;
  bool get isOverdue => !isPaid && payment.dueDate.isBefore(DateTime.now());

  String get statusLabel => isPaid ? 'Paid' : (isOverdue ? 'Overdue' : 'Unpaid');
  
  Color statusColor(BuildContext context) {
    if (isPaid) return VibrantColors.pastelGreen;
    if (isOverdue) return const Color(0xFFEF4444);
    return VibrantColors.warmYellow;
  }
  
  IconData get statusIcon {
    if (isPaid) return Icons.check_circle_outline;
    if (isOverdue) return Icons.warning_amber_outlined;
    return Icons.schedule_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final sColor = statusColor(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: sColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sColor.withOpacity(0.25)),
              ),
              alignment: Alignment.center,
              child: Icon(statusIcon, color: sColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currency}${payment.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(payment.dueDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (payment.note != null && payment.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      payment.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: chrome.mutedColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.more_vert, color: chrome.mutedColor.withOpacity(0.5)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) => AppDateUtils.displayDate(dt);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.payments, required this.currency});

  final List<Payment> payments;
  final String currency;

  @override
  Widget build(BuildContext context) {
    double paid = 0;
    double unpaid = 0;
    double overdue = 0;
    
    final now = DateTime.now();

    for (final p in payments) {
      if (p.status == PaymentStatus.paid) {
        paid += p.amount;
      } else {
        if (p.dueDate.isBefore(now)) {
          overdue += p.amount;
        } else {
          unpaid += p.amount;
        }
      }
    }

    return AppCard(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35), width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _SummaryItem(label: 'Paid', amount: paid, color: VibrantColors.pastelGreen, currency: currency)),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
          Expanded(child: _SummaryItem(label: 'Unpaid', amount: unpaid, color: VibrantColors.warmYellow, currency: currency)),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
          Expanded(child: _SummaryItem(label: 'Pending', amount: overdue, color: const Color(0xFFEF4444), currency: currency)),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  final String label;
  final double amount;
  final Color color;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$currency${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}
