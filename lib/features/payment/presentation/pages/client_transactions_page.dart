import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';

import '../../../client/domain/entities/client.dart';
import '../../../client/domain/entities/client_timeline_event.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_state.dart';
import '../../../client/presentation/pages/client_profile_page.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';

class ClientTransactionsPage extends StatelessWidget {
  const ClientTransactionsPage({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Transactions'),
        actions: [
          BlocBuilder<ClientBloc, ClientState>(
            buildWhen: (p, n) => p.runtimeType != n.runtimeType,
            builder: (context, state) {
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
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
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
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final client = _findClient(state);
              if (client == null) {
                return _EmptyCard(
                  message: 'Client not found',
                  surfaceColor: Theme.of(context).colorScheme.surface,
                  mutedColor: chrome.mutedColor,
                );
              }

              final payments = _extractPayments(client);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(client: client),
                  const SizedBox(height: 14),
                  Expanded(
                    child: payments.isEmpty
                        ? Center(
                            child: _EmptyCard(
                              message: 'No transactions yet',
                              surfaceColor:
                                  Theme.of(context).colorScheme.surface,
                              mutedColor: chrome.mutedColor,
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: payments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = payments[index];
                              return _TransactionCard(payment: p);
                            },
                          ),
                  ),
                ],
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

  List<_PaymentVM> _extractPayments(Client client) {
    bool isPaidOnDate(DateTime date) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      for (final e in client.timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        final k = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
        if (k != dateKey) continue;
        final s = e.status?.trim();
        if (s == 'Paid fully' || s == 'Paid') return true;
      }
      return false;
    }

    final out = <_PaymentVM>[];
    for (final e in client.timeline) {
      if (e.type != ClientTimelineEventType.payment) continue;
      if (!isPaidOnDate(e.createdAt)) continue;
      out.add(
        _PaymentVM(
          amount: e.amount ?? 0,
          note: e.note,
          date: e.createdAt,
        ),
      );
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return DecoratedBox(
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
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.payment});

  final _PaymentVM payment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);

    return DecoratedBox(
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
                    '₹${payment.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(payment.date),
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
      ),
    );
  }

  static String _formatDate(DateTime dt) => AppDateUtils.displayDate(dt);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.message,
    required this.surfaceColor,
    required this.mutedColor,
  });

  final String message;
  final Color surfaceColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: mutedColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PaymentVM {
  _PaymentVM({required this.amount, required this.note, required this.date});

  final double amount;
  final String? note;
  final DateTime date;
}
