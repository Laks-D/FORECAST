import re
import sys

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

old_timeline = """class _Timeline extends StatelessWidget {
  final Client entity;

  const _Timeline({required this.entity});

  @override
  Widget build(BuildContext context) {
    final defaultCurrency =
        context.select((UserProfileCubit c) => c.state.currency);
    final currency = entity.currency ?? defaultCurrency;
    final events = [...entity.timeline]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filter out payment and payment-related statusChanged events.
    final nonPaymentEvents = events.where((e) {
      if (e.type == ClientTimelineEventType.payment) return false;
      if (e.type == ClientTimelineEventType.statusChanged) {
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully' || s == 'Will pay later') {
          return false;
        }
      }
      return true;
    }).toList();

    if (nonPaymentEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Activity (${nonPaymentEvents.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        ...nonPaymentEvents.map((e) {
          final subtitle = _subtitleForEvent(e, currency);
          return Card(
            child: ListTile(
              title: Text(_titleForEvent(e)),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: Text(
                AppDateUtils.displayDate(e.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }),
      ],
    );
  }

  String? _subtitleForEvent(ClientTimelineEvent e, String currency) {
    switch (e.type) {
      case ClientTimelineEventType.payment:
        if (e.amount == null) return e.note;
        if (e.note != null && e.note!.trim().isNotEmpty) {
          return '${currency}${e.amount} • ${e.note!}';
        }
        return '${currency}${e.amount}';
      case ClientTimelineEventType.statusChanged:
        return e.status;
      case ClientTimelineEventType.note:
        return e.note;
      case ClientTimelineEventType.profileCreated:
        return null;
    }
  }

  String _titleForEvent(ClientTimelineEvent e) {
    switch (e.type) {
      case ClientTimelineEventType.profileCreated:
        return 'Profile created';
      case ClientTimelineEventType.statusChanged:
        return 'Status changed';
      case ClientTimelineEventType.payment:
        return 'Payment received';
      case ClientTimelineEventType.note:
        return 'Note added';
    }
  }
}"""

new_timeline = """class _Timeline extends StatelessWidget {
  final Client entity;

  const _Timeline({required this.entity});

  @override
  Widget build(BuildContext context) {
    final clientEventRepository = context.read<ClientBloc>().clientEventRepository;
    return StreamBuilder<List<ClientEvent>>(
      stream: clientEventRepository.watchForClient(entity.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final events = snapshot.data!;
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Activity (${events.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            ...events.map((e) {
              final subtitle = _subtitleForEvent(e);
              return Card(
                child: ListTile(
                  title: Text(_titleForEvent(e)),
                  subtitle: subtitle == null ? null : Text(subtitle),
                  trailing: Text(
                    AppDateUtils.displayDate(e.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }),
          ],
        );
      }
    );
  }

  String? _subtitleForEvent(ClientEvent e) {
    switch (e.type) {
      case ClientEventType.statusChanged:
        final oldStatus = e.metadata?['oldStatus'];
        final newStatus = e.metadata?['newStatus'];
        if (oldStatus != null && newStatus != null) {
          return 'Changed from $oldStatus to $newStatus';
        }
        return 'Status updated';
      case ClientEventType.note:
        return e.note;
      case ClientEventType.profileCreated:
        return null;
      default:
        return null;
    }
  }

  String _titleForEvent(ClientEvent e) {
    switch (e.type) {
      case ClientEventType.profileCreated:
        return 'Profile created';
      case ClientEventType.statusChanged:
        return 'Status changed';
      case ClientEventType.note:
        return 'Note added';
      default:
        return 'Activity';
    }
  }
}"""

content = content.replace(old_timeline, new_timeline)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)

