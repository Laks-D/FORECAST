import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../../../design_system/theme/app_visual_style.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../client/domain/entities/client.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../client/presentation/bloc/client_state.dart';

class DeletedClientsScreen extends StatelessWidget {
  const DeletedClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.surface;
    final cardColor = scheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        title: const Text('Deleted Clients'),
      ),
      body: FutureBuilder<List<Client>>(
        future: context.read<ClientBloc>().repository.getDeletedClients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final deleted = snapshot.data ?? const [];

          if (deleted.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_sweep_outlined,
                    size: 56,
                    color: scheme.onSurface.withOpacity(0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No deleted clients',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Deleted clients will appear here for 30 days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.35),
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: deleted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = deleted[index];
              return _DeletedClientCard(
                client: c,
                chrome: chrome,
                cardColor: cardColor,
                neumorphism: visual.neumorphism,
              );
            },
          );
        },
      ),
    );
  }
}

class _DeletedClientCard extends StatelessWidget {
  const _DeletedClientCard({
    required this.client,
    required this.chrome,
    required this.cardColor,
    required this.neumorphism,
  });

  final Client client;
  final AppChromeTheme chrome;
  final Color cardColor;
  final bool neumorphism;

  // ── Days remaining before auto-purge ──────────────────────────────────────
  int get _daysRemaining {
    final deleted = client.deletedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(deleted).inDays;
    return (30 - elapsed).clamp(0, 30);
  }

  // ── Tap → bottom action sheet ─────────────────────────────────────────────
  void _showActions(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.surfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.displayName,
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  color: chrome.textColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close, color: chrome.mutedColor),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Deleted ${DateTime.now().difference(client.deletedAt ?? DateTime.now()).inDays} day(s) ago  •  $_daysRemaining day(s) left',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: chrome.mutedColor,
                            ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.restore_outlined,
                        color: chrome.accentBlue,
                      ),
                      title: Text(
                        'Restore client',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _restore(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: scheme.error,
                      ),
                      title: Text(
                        'Delete permanently',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _permanentDelete(context);
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _restore(BuildContext context) async {
    final sessionsCubit = context.read<SessionsCubit>();
    final clientBloc = context.read<ClientBloc>();
    final messenger = ScaffoldMessenger.of(context);

    clientBloc.add(RestoreClient(entityId: client.id));
    sessionsCubit.restoreDeletedUpcomingSessionsForClient(client.id);

    messenger.showSnackBar(
      const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Client restored successfully.')),
    );
  }

  Future<void> _permanentDelete(BuildContext context) async {
    final clientBloc = context.read<ClientBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'This will permanently delete ${client.displayName} and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    clientBloc.add(PermanentlyDeleteClient(entityId: client.id));

    messenger.showSnackBar(
      const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Client permanently deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadows = neumorphism
        ? AppVisualStyle.neumorphicShadows(context,
            blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    final daysLeft = _daysRemaining;
    final isUrgent = daysLeft <= 3;
    final chipColor = isUrgent ? scheme.error : chrome.mutedColor;

    return InkWell(
      onTap: () => _showActions(context),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
          boxShadow: shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  client.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: chipColor.withOpacity(0.25)),
                ),
                child: Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
