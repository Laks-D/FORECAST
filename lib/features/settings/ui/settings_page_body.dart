import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../../calendar/ui/widgets/calendar_page_body.dart';
import '../../client/presentation/pages/client_page.dart';
import '../../dashboard/bloc/dashboard_cubit.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';
import '../../navigation/bloc/nav_modules_state.dart';
import '../../navigation/ui/module_customization_screen.dart';
import '../../payment/presentation/pages/payments_page.dart';
import '../../theme_customization/ui/theme_customization_screen.dart';
import 'program_management_screen.dart';
import 'profile/profile_details_screen.dart';
import '../../../core/services/notification_cubit.dart';
import '../../notifications/ui/notifications_page.dart';
import '../../notifications/ui/notification_settings_page.dart';

class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({super.key});

  static const _cardRadius = 40.0;
  static AppChromeTheme _chrome(BuildContext context) => AppChromeTheme.of(context);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _ProfileCard(),
                  const SizedBox(height: 14),
                  const _ModulesSection(),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Customization',
                    children: [
                      _SectionTile(
                        leading: Icons.palette_outlined,
                        title: 'Theme & Style',
                        subtitle: 'Customize colors and fonts',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ThemeCustomizationScreen(),
                            ),
                          );
                        },
                      ),
                      _SectionTile(
                        leading: Icons.tune_outlined,
                        title: 'Module customization',
                        subtitle: 'Show/hide modules in nav bar',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ModuleCustomizationScreen(),
                            ),
                          );
                        },
                      ),
                      _SectionTile(
                        leading: Icons.menu_book_outlined,
                        title: 'Program management',
                        subtitle: 'Create and manage programs',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProgramManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Notifications',
                    children: [
                      _SectionTile(
                        leading: Icons.notifications_none_outlined,
                        title: 'Notifications',
                        subtitle: 'View all notifications',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BlocProvider.value(
                                value: context.read<NotificationCubit>(),
                                child: const NotificationsPage(),
                              ),
                            ),
                          );
                        },
                      ),
                      _SectionTile(
                        leading: Icons.tune_outlined,
                        title: 'Notification Settings',
                        subtitle: 'Manage reminders & alerts',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BlocProvider.value(
                                value: context.read<NotificationCubit>(),
                                child: const NotificationSettingsPage(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'About',
                    children: [
                      _SectionTile(
                        leading: Icons.info_outline,
                        title: 'About',
                        subtitle: 'Version, credits & more',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 14),
                  const _LogoutButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  static const _profileCardRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    final nameStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_profileCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              const _AvatarCircle(),
              const SizedBox(width: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BlocSelector<DashboardCubit, DashboardState, String>(
                        selector: (state) => state.userName ?? 'User',
                        builder: (context, name) {
                          return Text(
                            name,
                            style: nameStyle,
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _PillButton(
                        text: 'more details',
                        onTap: () {
                          final dashboardCubit = context.read<DashboardCubit>();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BlocProvider.value(
                                value: dashboardCubit,
                                child: const ProfileDetailsScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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

class _ModulesSection extends StatelessWidget {
  const _ModulesSection();

  void _openModule(BuildContext context, NavModulesState navState, DashboardTab tab) {
    if (navState.visibleTabs.contains(tab)) {
      context.read<DashboardCubit>().selectTab(tab);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StandaloneModuleScreen(tab: tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Modules',
      children: [
        BlocBuilder<NavModulesCubit, NavModulesState>(
          buildWhen: (p, n) => p.order != n.order || p.enabled != n.enabled || p.visibleTabs != n.visibleTabs,
          builder: (context, state) {
            final all = state.order.where((t) => t != DashboardTab.settings).toList(growable: false);
            return Column(
              children: [
                for (final tab in all)
                  _SectionTile(
                    leading: _iconFor(tab),
                    title: _labelFor(tab),
                    subtitle: state.enabled.contains(tab) || tab == DashboardTab.home ? null : 'Hidden from nav bar',
                    onTap: () => _openModule(context, state, tab),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.black.withOpacity(0.35),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static IconData _iconFor(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.calendar:
        return Icons.calendar_month_outlined;
      case DashboardTab.people:
        return Icons.group_outlined;
      case DashboardTab.cards:
        return Icons.menu_book_outlined;
      case DashboardTab.home:
        return Icons.home_outlined;
      case DashboardTab.phone:
        return Icons.credit_card_outlined;
      case DashboardTab.settings:
        return Icons.settings_outlined;
    }
  }

  static String _labelFor(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.calendar:
        return 'Calendar';
      case DashboardTab.people:
        return 'Client';
      case DashboardTab.cards:
        return 'Cards';
      case DashboardTab.home:
        return 'Dashboard';
      case DashboardTab.phone:
        return 'Payment';
      case DashboardTab.settings:
        return 'Profile';
    }
  }
}

class _StandaloneModuleScreen extends StatelessWidget {
  const _StandaloneModuleScreen({required this.tab});

  final DashboardTab tab;

  @override
  Widget build(BuildContext context) {
    final chrome = SettingsPageBody._chrome(context);

    Widget body;
    switch (tab) {
      case DashboardTab.calendar:
        body = const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: CalendarPageBody(),
        );
        break;
      case DashboardTab.people:
        body = const ClientPage();
        break;
      case DashboardTab.phone:
        body = const PaymentsPage();
        break;
      case DashboardTab.home:
        body = const SizedBox.expand();
        break;
      case DashboardTab.cards:
        body = const SizedBox.expand();
        break;
      case DashboardTab.settings:
        body = const SizedBox.expand();
        break;
    }

    return Scaffold(
      backgroundColor: chrome.frameColor,
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_ModulesSection._labelFor(tab)),
      ),
      body: SafeArea(
        top: false,
        child: body,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(SettingsPageBody._cardRadius),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
    Widget? trailing,
  }) : trailing = trailing;

  final IconData leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black.withOpacity(0.55),
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            dense: true,
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(leading, color: Colors.black87, size: 20),
              ),
            ),
            title: Text(title, style: titleStyle),
            subtitle: subtitle == null ? null : Text(subtitle!, style: subtitleStyle),
            trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle();

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DashboardCubit, DashboardState, Uint8List?>(
      selector: (state) => state.userAvatarBytes,
      builder: (context, avatarBytes) {
        return SizedBox(
          width: _size,
          height: _size,
          child: ClipOval(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFE6E6E6),
              ),
              child: avatarBytes == null
                  ? Center(
                      child: Icon(
                        Icons.person_outline,
                        size: 34,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    )
                  : Image.memory(
                      avatarBytes,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    final chrome = SettingsPageBody._chrome(context);

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              FirebaseAuth.instance.signOut();
            },
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: chrome.accentBlue.withOpacity(0.25)),
              ),
              child: Center(
                child: Text(
                  'Log out',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.black.withOpacity(0.78),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
