import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/notification_cubit.dart';
import '../../../design_system/theme/app_chrome_theme.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

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
                    'Notification Settings',
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      children: [
                        /* ─ Session Reminders ─ */
                        _SectionHeader(title: 'Session Reminders', chrome: chrome),
                        const SizedBox(height: 4),
                        _ToggleTile(
                          title: 'Enabled',
                          subtitle: 'Get notified before upcoming sessions',
                          value: state.sessionReminders,
                          chrome: chrome,
                          onChanged: (v) => context
                              .read<NotificationCubit>()
                              .toggleSessionReminders(v),
                        ),
                        if (state.sessionReminders) ...[
                          const SizedBox(height: 8),
                          _LeadTimePicker(
                            label: 'Remind me before',
                            options: const {
                              5: '5 minutes',
                              10: '10 minutes',
                              15: '15 minutes',
                              30: '30 minutes',
                              60: '1 hour',
                            },
                            selected: state.sessionLeadMinutes,
                            chrome: chrome,
                            onChanged: (v) => context
                                .read<NotificationCubit>()
                                .setSessionLeadMinutes(v),
                          ),
                        ],
                        const _Separator(),

                        /* ─ Payment Reminders ─ */
                        _SectionHeader(title: 'Payment Reminders', chrome: chrome),
                        const SizedBox(height: 4),
                        _ToggleTile(
                          title: 'Enabled',
                          subtitle: 'Get notified about payments at the start of the day',
                          value: state.paymentReminders,
                          chrome: chrome,
                          onChanged: (v) => context
                              .read<NotificationCubit>()
                              .togglePaymentReminders(v),
                        ),
                        if (state.paymentReminders) ...[
                          const SizedBox(height: 12),
                          _TimePicker(
                            label: 'Notification time',
                            hour: state.paymentReminderHour,
                            minute: state.paymentReminderMinute,
                            chrome: chrome,
                            onChanged: (h, m) => context
                                .read<NotificationCubit>()
                                .setPaymentReminderTime(h, m),
                          ),
                          const SizedBox(height: 12),
                          _LeadTimePicker(
                            label: 'Remind me',
                            options: const {
                              0: 'Same day',
                              1: '1 day before',
                              2: '2 days before',
                              3: '3 days before',
                              7: '1 week before',
                            },
                            selected: state.paymentDaysBefore,
                            chrome: chrome,
                            onChanged: (v) => context
                                .read<NotificationCubit>()
                                .setPaymentDaysBefore(v),
                          ),
                          const SizedBox(height: 8),
                          _ToggleTile(
                            title: 'Daily pending reminders',
                            subtitle:
                              'Keep reminding every morning for unpaid pending payments',
                            value: state.paymentOverdueDaily,
                            chrome: chrome,
                            onChanged: (v) => context
                                .read<NotificationCubit>()
                                .togglePaymentOverdueDaily(v),
                          ),
                        ],
                      ],
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

/* ──────────────────── Helpers ──────────────────── */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.chrome});
  final String title;
  final AppChromeTheme chrome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: chrome.textColor,
            ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.chrome,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final AppChromeTheme chrome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: chrome.textColor)),
      subtitle: Text(subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: chrome.mutedColor)),
      value: value,
      activeColor: chrome.accentBlue,
      onChanged: onChanged,
    );
  }
}

class _LeadTimePicker extends StatelessWidget {
  const _LeadTimePicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.chrome,
    required this.onChanged,
  });
  final String label;
  final Map<int, String> options;
  final int selected;
  final AppChromeTheme chrome;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: chrome.mutedColor),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.entries.map((e) {
            final isSelected = e.key == selected;
            return ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              selectedColor: chrome.accentBlue.withOpacity(0.18),
              labelStyle: TextStyle(
                color: isSelected ? chrome.accentBlue : chrome.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              onSelected: (_) => onChanged(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(height: 1),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.hour,
    required this.minute,
    required this.chrome,
    required this.onChanged,
  });
  final String label;
  final int hour;
  final int minute;
  final AppChromeTheme chrome;
  final void Function(int hour, int minute) onChanged;

  String _format(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: chrome.mutedColor),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: minute),
            );
            if (picked != null) {
              onChanged(picked.hour, picked.minute);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: chrome.mutedColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 18, color: chrome.accentBlue),
                const SizedBox(width: 8),
                Text(
                  _format(hour, minute),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: chrome.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
