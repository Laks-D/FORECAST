import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../../calendar/bloc/calendar_cubit.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../calendar/ui/widgets/calendar_page_body.dart';
import '../../client/presentation/bloc/client_bloc.dart';
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

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F0F0F); // Near-black background
    const cardColor = Color(0xFF1C1C1E); // iOS-style dark surface

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor,
            elevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            pinned: false,
            floating: false,
            snap: false,
            primary: false,
            titleSpacing: 16,
            title: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCardCompact(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Modules',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    children: [
                      BlocBuilder<NavModulesCubit, NavModulesState>(
                        builder: (context, state) {
                          final all = state.order
                              .where((t) => t != DashboardTab.settings)
                              .toList();
                          return Column(
                            children: [
                              for (final tab in all)
                                _SectionTileDark(
                                  leading: _iconFor(tab),
                                  title: _labelFor(tab),
                                  subtitle: state.enabled.contains(tab) ||
                                          tab == DashboardTab.home
                                      ? null
                                      : 'Hidden from nav bar',
                                  onTap: () {
                                    if (state.visibleTabs.contains(tab)) {
                                      // Settings is a dashboard tab (not a pushed route),
                                      // so don't pop the navigator here.
                                      context
                                          .read<DashboardCubit>()
                                          .selectTab(tab);
                                      return;
                                    }

                                    // When a module is hidden from the bottom nav, open it
                                    // as a standalone screen, but keep required BLoCs.
                                    final calendarCubit =
                                        context.read<CalendarCubit>();
                                    final sessionsCubit =
                                        context.read<SessionsCubit>();
                                    final clientBloc =
                                        context.read<ClientBloc>();

                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => MultiBlocProvider(
                                          providers: [
                                            BlocProvider.value(
                                                value: calendarCubit),
                                            BlocProvider.value(
                                                value: sessionsCubit),
                                            BlocProvider.value(
                                                value: clientBloc),
                                          ],
                                          child:
                                              _StandaloneModuleScreen(tab: tab),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Customization',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    children: [
                      _SectionTileDark(
                        leading: Icons.palette_outlined,
                        title: 'Theme & Style',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ThemeCustomizationScreen(),
                            ),
                          );
                        },
                      ),
                      _SectionTileDark(
                        leading: Icons.tune_outlined,
                        title: 'Module customization',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ModuleCustomizationScreen(),
                            ),
                          );
                        },
                      ),
                      _SectionTileDark(
                        leading: Icons.menu_book_outlined,
                        title: 'Program management',
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
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    children: [
                      _SectionTileDark(
                        leading: Icons.notifications_none_outlined,
                        title: 'Notifications',
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
                      _SectionTileDark(
                        leading: Icons.tune_outlined,
                        title: 'Notification Settings',
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
                  const SizedBox(height: 24),
                  _SectionCardDark(
                    color: cardColor,
                    children: [
                      _SectionTileDark(
                        leading: Icons.info_outline,
                        title: 'About application',
                        onTap: () {},
                      ),
                      _SectionTileDark(
                        leading: Icons.chat_bubble_outline,
                        title: 'Help/FAQ',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _SectionCardDark(
                    color: cardColor,
                    children: [
                      _SectionTileDark(
                        leading: Icons.logout,
                        title: 'Log out',
                        titleColor: VibrantColors.softPink,
                        onTap: () => FirebaseAuth.instance.signOut(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
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
        return 'Clients';
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
    const bgColor = Color(0xFF0F0F0F);

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
      case DashboardTab.cards:
      case DashboardTab.settings:
        body = const SizedBox.expand();
        break;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(SettingsPageBody._labelFor(tab)),
      ),
      body: SafeArea(
        top: false,
        child: body,
      ),
    );
  }
}

class _SectionCardDark extends StatelessWidget {
  const _SectionCardDark({required this.children, required this.color});

  final List<Widget> children;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SectionTileDark extends StatelessWidget {
  const _SectionTileDark({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleColor,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: titleColor ?? Colors.white,
          fontWeight: FontWeight.w600,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withOpacity(0.55),
          fontWeight: FontWeight.w600,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(leading, color: titleColor ?? Colors.white, size: 22),
        title: Text(title, style: titleStyle),
        subtitle:
            subtitle == null ? null : Text(subtitle!, style: subtitleStyle),
        trailing: Icon(Icons.chevron_right,
            color: Colors.white.withOpacity(0.3), size: 20),
      ),
    );
  }
}

class _AvatarCircleSmall extends StatelessWidget {
  const _AvatarCircleSmall();

  static const _size = 52.0;

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
                color: Color(0xFF2C2C2E),
              ),
              child: avatarBytes == null
                  ? Center(
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.white.withOpacity(0.6),
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

class _ProfileCardCompact extends StatelessWidget {
  const _ProfileCardCompact();

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1C1C1E);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withOpacity(0.5),
          fontWeight: FontWeight.w500,
        );

    return InkWell(
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
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _AvatarCircleSmall(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocSelector<DashboardCubit, DashboardState, String>(
                      selector: (state) => state.userName ?? 'User',
                      builder: (context, name) {
                        return Text(name, style: titleStyle);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text('Product/UI Designer', style: subtitleStyle),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
