import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/notification_cubit.dart';
import '../../../core/services/notification_storage.dart';
import '../../../design_system/theme/app_chrome_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Column(
          children: [
            /* ─── Header ─── */
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Notifications',
                    style: tt.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  BlocBuilder<NotificationCubit, NotificationState>(
                    builder: (context, state) {
                      if (state.records.isEmpty) return const SizedBox.shrink();
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          final cubit = context.read<NotificationCubit>();
                          if (value == 'read') cubit.markAllRead();
                          if (value == 'clear') cubit.clearAll();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'read',
                            child: Text('Mark all as read'),
                          ),
                          const PopupMenuItem(
                            value: 'clear',
                            child: Text('Clear all'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            /* ─── Body ─── */
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: BlocBuilder<NotificationCubit, NotificationState>(
                  builder: (context, state) {
                    if (state.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: chrome.mutedColor.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: tt.bodyLarge
                                  ?.copyWith(color: chrome.mutedColor),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: state.records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = state.records[index];
                        return _NotificationTile(notification: n);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
        return Colors.orange;
      case AppNotificationType.general:
        return chrome.mutedColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final tt = Theme.of(context).textTheme;
    final unread = !notification.read;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
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
                        color: chrome.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: tt.bodySmall?.copyWith(color: chrome.mutedColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: tt.labelSmall?.copyWith(
                        color: chrome.mutedColor.withOpacity(0.7),
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
