import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/notification_cubit.dart';
import '../../../core/services/notification_storage.dart';
import '../../../design_system/theme/app_chrome_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bgColor = scheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: tt.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              final now = DateTime.now();
              final hasVisible =
                  state.records.any((n) => !n.createdAt.isAfter(now));
              if (!hasVisible) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: scheme.onSurface),
                onSelected: (value) {
                  final cubit = context.read<NotificationCubit>();
                  if (value == 'read') cubit.markAllRead();
                  if (value == 'clear') cubit.clearAll();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'read',
                    child: Text('Mark all as read'),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear all'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          final now = DateTime.now();
          // Only show notifications that are due/triggered (not future scheduled).
          final visibleRecords = state.records
              .where((n) => !n.createdAt.isAfter(now))
              .toList(growable: false);

          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (visibleRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: scheme.onSurface.withOpacity(0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: tt.bodyLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: visibleRecords.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.outlineVariant.withOpacity(0.45),
            ),
            itemBuilder: (context, index) {
              final n = visibleRecords[index];
              return _NotificationTile(notification: n);
            },
          );
        },
      ),
    );
  }
}

/* ──────────────────── Single notification tile ──────────────────── */

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  IconData get _icon {
    switch (notification.type) {
      case AppNotificationType.sessionReminder:
        return Icons.event_outlined;
      case AppNotificationType.paymentReminder:
        return Icons.payment_outlined;
      case AppNotificationType.general:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(AppChromeTheme chrome) {
    switch (notification.type) {
      case AppNotificationType.sessionReminder:
        return chrome.accentBlue;
      case AppNotificationType.paymentReminder:
        return VibrantColors.warmYellow;
      case AppNotificationType.general:
        return chrome.mutedColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unread = !notification.read;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: VibrantColors.softPink,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        context.read<NotificationCubit>().deleteRecord(notification.id);
      },
      child: InkWell(
        onTap: () {
          if (unread) {
            context.read<NotificationCubit>().markRead(notification.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconColor(chrome).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: _iconColor(chrome)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.60),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 4),
                  decoration: BoxDecoration(
                    color: chrome.accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) {
      // future notification schedule
      final abs = diff.abs();
      if (abs.inDays > 0) return 'in ${abs.inDays}d';
      if (abs.inHours > 0) return 'in ${abs.inHours}h';
      return 'in ${abs.inMinutes}m';
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
