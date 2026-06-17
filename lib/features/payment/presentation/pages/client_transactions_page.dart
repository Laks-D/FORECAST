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
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';

class ClientTransactionsPage extends StatelessWidget {
  const ClientTransactionsPage({
    super.key,
    required this.clientId,
  });

  final String clientId;

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
        actions: [
          BlocBuilder<ClientBloc, ClientState>(
            buildWhen: (p, n) => p.runtimeType != n.runtimeType,
            builder: (context, state) {
              if (AppModeScope.isClient(context)) {
                return const SizedBox.shrink();
              }

              final client = _findClient(state);
              return Padding(
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                child: TextButton(
                  onPressed: client == null
                      ? null
                      : () {
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
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface,
                    side: BorderSide(
                      color: scheme.outlineVariant.withOpacity(0.75),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text('Profile'),
                ),
              );
            },
          ),
        ],
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
                stream: AppModeScope.isClient(context)
                    ? paymentRepository.watchForStudent(client.firebaseUid ?? '')
                    : paymentRepository.watchForClient(client.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return AppLoading(color: onSurface);
                  }

                  final payments = snapshot.data!.where((p) => p.status == PaymentStatus.paid).toList();
                  payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
                  final listItems = _buildMonthGroupedItems(payments);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(client: client),
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
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _TransactionCard(payment: p, currency: currency),
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

  Client? _findClient(ClientState state) {
    if (state is! ClientLoaded) return null;
    for (final c in state.entities) {
      if (c.id == clientId) return c;
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
  const _HeaderCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                client.name.isEmpty ? '?' : client.name.characters.first,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client.formattedPhone,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.payment, required this.currency});

  final Payment payment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.payments_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid',
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
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) => AppDateUtils.displayDate(dt);
}
