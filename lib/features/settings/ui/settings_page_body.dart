import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../design_system/theme/app_chrome_theme.dart';
import '../../../design_system/theme/app_visual_style.dart';
import '../../calendar/bloc/calendar_cubit.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../calendar/ui/widgets/calendar_page_body.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/pages/client_page.dart';
import '../../course/presentation/pages/courses_page.dart';
import '../../dashboard/bloc/dashboard_cubit.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';
import '../../navigation/bloc/nav_modules_state.dart';
import '../../navigation/ui/module_customization_screen.dart';
import '../../payment/presentation/pages/payments_page.dart';
import '../../theme_customization/bloc/app_theme_cubit.dart';
import '../../theme_customization/bloc/app_theme_state.dart';
import '../../theme_customization/ui/theme_customization_screen.dart';
import 'program_management_screen.dart';
import 'profile/profile_details_screen.dart';
import 'profile/client_profile_details_screen.dart';
import '../../../core/services/notification_cubit.dart';
import '../../notifications/ui/notifications_page.dart';
import '../../notifications/ui/notification_settings_page.dart';
import '../../../core/app/app_mode.dart';
import '../../../core/app/app_mode_storage.dart';


class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppModeScope.isClient(context)) {
      return const _ClientSettingsPageBody();
    }

    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final bgColor = scheme.surface;
    final cardColor = scheme.surface;
    final onSurface = scheme.onSurface;
    final headerColor = onSurface.withOpacity(0.55);
    final chevronColor = onSurface.withOpacity(0.35);

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
                    color: onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
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
                                  chevronColor: chevronColor,
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
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: BlocBuilder<AppThemeCubit, AppThemeState>(
                          builder: (context, state) {
                            return _ThemeModePills(
                              mode: state.themeMode,
                              neumorphism: visual.neumorphism,
                              onChanged: (m) =>
                                  context.read<AppThemeCubit>().setThemeMode(m),
                            );
                          },
                        ),
                      ),
                      _SectionTileDark(
                        leading: Icons.palette_outlined,
                        title: 'Theme & Style',
                        chevronColor: chevronColor,
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
                        chevronColor: chevronColor,
                        onTap: () {
                          final navCubit = context.read<NavModulesCubit>();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BlocProvider.value(
                                value: navCubit,
                                child: const ModuleCustomizationScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      _SectionTileDark(
                        leading: Icons.menu_book_outlined,
                        title: 'Program management',
                        chevronColor: chevronColor,
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
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.notifications_none_outlined,
                        title: 'Notifications',
                        chevronColor: chevronColor,
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
                        chevronColor: chevronColor,
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
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.info_outline,
                        title: 'About application',
                        chevronColor: chevronColor,
                        onTap: () {},
                      ),
                      _SectionTileDark(
                        leading: Icons.chat_bubble_outline,
                        title: 'Help/FAQ',
                        chevronColor: chevronColor,
                        onTap: () {},
                      ),
                    ],
                  ),
                  if (AppModeConfig.isDualRole) ...[
                    _SectionCardDark(
                      color: cardColor,
                      neumorphism: visual.neumorphism,
                      children: [
                        _SectionTileDark(
                          leading: Icons.swap_horiz_rounded,
                          title: 'Switch to Student Mode',
                          subtitle: 'Re-logs you in as student',
                          chevronColor: chevronColor,
                          onTap: () async {
                            await AppModeStorage.save(AppMode.client);
                            FirebaseAuth.instance.signOut();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 32),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.logout,
                        title: 'Log out',
                        titleColor: VibrantColors.softPink,
                        chevronColor: chevronColor,
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
        return AppModeConfig.isClient ? 'Courses' : 'Clients';
      case DashboardTab.cards:
        return 'Cards';
      case DashboardTab.home:
        return 'Dashboard';
      case DashboardTab.phone:
        return 'Payment';
      case DashboardTab.settings:
        return 'Settings';
    }
  }
}

class _StandaloneModuleScreen extends StatelessWidget {
  const _StandaloneModuleScreen({required this.tab});

  final DashboardTab tab;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget body;
    switch (tab) {
      case DashboardTab.calendar:
        body = const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: CalendarPageBody(),
        );
        break;
      case DashboardTab.people:
        body = AppModeScope.isClient(context)
            ? const CoursesPage(embedInDashboard: false)
            : const ClientPage();
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
        foregroundColor: onSurface,
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

class _ClientSettingsPageBody extends StatelessWidget {
  const _ClientSettingsPageBody();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final bgColor = scheme.surface;
    final cardColor = scheme.surface;
    final onSurface = scheme.onSurface;
    final headerColor = onSurface.withOpacity(0.55);
    final chevronColor = onSurface.withOpacity(0.35);

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
                    color: onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ClientProfileCardCompact(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Customization',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: BlocBuilder<AppThemeCubit, AppThemeState>(
                          builder: (context, state) {
                            return _ThemeModePills(
                              mode: state.themeMode,
                              neumorphism: visual.neumorphism,
                              onChanged: (m) =>
                                  context.read<AppThemeCubit>().setThemeMode(m),
                            );
                          },
                        ),
                      ),
                      _SectionTileDark(
                        leading: Icons.palette_outlined,
                        title: 'Theme & Style',
                        chevronColor: chevronColor,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ThemeCustomizationScreen(),
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
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.notifications_none_outlined,
                        title: 'Notifications',
                        chevronColor: chevronColor,
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
                        chevronColor: chevronColor,
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
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.info_outline,
                        title: 'About application',
                        chevronColor: chevronColor,
                        onTap: () {},
                      ),
                      _SectionTileDark(
                        leading: Icons.chat_bubble_outline,
                        title: 'Help/FAQ',
                        chevronColor: chevronColor,
                        onTap: () {},
                      ),
                    ],
                  ),
                  if (AppModeConfig.isDualRole) ...[
                    _SectionCardDark(
                      color: cardColor,
                      neumorphism: visual.neumorphism,
                      children: [
                        _SectionTileDark(
                          leading: Icons.swap_horiz_rounded,
                          title: 'Switch to Tutor Mode',
                          subtitle: 'Re-logs you in as tutor',
                          chevronColor: chevronColor,
                          onTap: () async {
                            await AppModeStorage.save(AppMode.admin);
                            FirebaseAuth.instance.signOut();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 32),
                  _SectionCardDark(
                    color: cardColor,
                    neumorphism: visual.neumorphism,
                    children: [
                      _SectionTileDark(
                        leading: Icons.logout,
                        title: 'Log out',
                        titleColor: VibrantColors.softPink,
                        chevronColor: chevronColor,
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
}

class _ClientProfileCardCompact extends StatelessWidget {
  const _ClientProfileCardCompact();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final chrome = AppChromeTheme.of(context);
    final cardColor = scheme.surface;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withOpacity(0.55),
          fontWeight: FontWeight.w500,
        );

    return InkWell(
      onTap: () {
        final dashboardCubit = context.read<DashboardCubit>();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: dashboardCubit,
              child: const ClientProfileDetailsScreen(),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
          boxShadow: shadows,
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
                    Text('Student Profile', style: subtitleStyle),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCardDark extends StatelessWidget {
  const _SectionCardDark({
    required this.children,
    required this.color,
    required this.neumorphism,
  });

  final List<Widget> children;
  final Color color;
  final bool neumorphism;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final shadows = neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
        boxShadow: shadows,
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
    this.chevronColor,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? chevronColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleFg = titleColor ?? scheme.onSurface;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: titleFg,
          fontWeight: FontWeight.w600,
        );

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withOpacity(0.55),
          fontWeight: FontWeight.w600,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(leading, color: titleFg, size: 22),
        title: Text(title, style: titleStyle),
        subtitle:
            subtitle == null ? null : Text(subtitle!, style: subtitleStyle),
        trailing: Icon(
          Icons.chevron_right,
          color: chevronColor ?? scheme.onSurface.withOpacity(0.30),
          size: 20,
        ),
      ),
    );
  }
}

class _ThemeModePills extends StatelessWidget {
  const _ThemeModePills({
    required this.mode,
    required this.neumorphism,
    required this.onChanged,
  });

  final ThemeMode mode;
  final bool neumorphism;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final sel = chrome.accentBlue;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: neumorphism
            ? AppVisualStyle.neumorphicShadows(context, blurRadius: 18, offset: const Offset(6, 6))
            : const <BoxShadow>[],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ThemeModePill(
              label: 'System',
              icon: Icons.brightness_auto,
              selected: mode == ThemeMode.system,
              selectedColor: sel,
              onTap: () => onChanged(ThemeMode.system),
            ),
          ),
          Expanded(
            child: _ThemeModePill(
              label: 'Light',
              icon: Icons.light_mode_outlined,
              selected: mode == ThemeMode.light,
              selectedColor: sel,
              onTap: () => onChanged(ThemeMode.light),
            ),
          ),
          Expanded(
            child: _ThemeModePill(
              label: 'Dark',
              icon: Icons.dark_mode_outlined,
              selected: mode == ThemeMode.dark,
              selectedColor: sel,
              onTap: () => onChanged(ThemeMode.dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePill extends StatelessWidget {
  const _ThemeModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface.withOpacity(selected ? 1 : 0.78);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: selected ? selectedColor.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarCircleSmall extends StatelessWidget {
  const _AvatarCircleSmall();

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<DashboardCubit, DashboardState, Uint8List?>(
      selector: (state) => state.userAvatarBytes,
      builder: (context, avatarBytes) {
        return SizedBox(
          width: _size,
          height: _size,
          child: ClipOval(
            child: DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              child: avatarBytes == null
                  ? Center(
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: scheme.onSurface.withOpacity(0.55),
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
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final chrome = AppChromeTheme.of(context);
    final cardColor = scheme.surface;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withOpacity(0.55),
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
          border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
          boxShadow: shadows,
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
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
