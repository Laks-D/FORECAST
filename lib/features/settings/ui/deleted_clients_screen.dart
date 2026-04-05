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
        title: const Text('Deleted clients'),
      ),
      body: BlocBuilder<ClientBloc, ClientState>(
        builder: (context, _) {
          final deleted = context.read<ClientBloc>().repository.getDeletedClients();

          if (deleted.isEmpty) {
            return Center(
              child: Text(
                'No deleted clients',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
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

  Future<void> _restore(BuildContext context) async {
    final sessionsCubit = context.read<SessionsCubit>();
    final clientBloc = context.read<ClientBloc>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore client?'),
          content: Text('Restore ${client.displayName} and upcoming classes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!context.mounted) return;
    clientBloc.add(RestoreClient(entityId: client.id));

    messenger.showSnackBar(
      const SnackBar(duration: Duration(seconds: 1), content: Text('Client restored.')),
    );

    // Restore upcoming sessions in the background so the client reappears
    // immediately.
    sessionsCubit.restoreDeletedUpcomingSessionsForClient(client.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadows = neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.18)),
        boxShadow: shadows,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          client.displayName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          client.formattedPhone,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.55),
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton(
          onPressed: () => _restore(context),
          child: const Text('Restore'),
        ),
      ),
    );
  }
}
