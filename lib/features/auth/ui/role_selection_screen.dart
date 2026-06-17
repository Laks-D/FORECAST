import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app/app_mode_cubit.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';
import 'new_signup_screen.dart';
import 'new_login_screen.dart';

/// Entry screen. Users choose:
///  - Sign In:  Tutor login  /  Student login
///  - Sign Up:  As Tutor  /  As Student  /  As Both
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _pushLogin(String role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<AppModeCubit>(),
          child: NewLoginScreen(role: role),
        ),
      ),
    );
  }

  void _pushSignup(String role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<AppModeCubit>(),
          child: NewSignupScreen(role: role),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? Theme.of(context).scaffoldBackgroundColor : chrome.frameColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // ── Brand / Title ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: chrome.mutedColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: chrome.mutedColor.withOpacity(0.15)),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 34,
                      color: scheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: chrome.textColor,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in or create a new account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // ── Tab bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SegmentedTabs(controller: _tabController),
            ),
            const SizedBox(height: 28),
            // ── Tab views ─────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Sign In tab
                  _RoleCardGrid(
                    cards: [
                      _RoleCard(
                        icon: Icons.cast_for_education_rounded,
                        title: 'Tutor',
                        subtitle: 'Manage students, sessions & payments',
                        accentColor: VibrantColors.warmYellow,
                        onTap: () => _pushLogin('tutor'),
                      ),
                      _RoleCard(
                        icon: Icons.menu_book_rounded,
                        title: 'Student',
                        subtitle: 'View your courses, sessions & history',
                        accentColor: VibrantColors.pastelGreen,
                        onTap: () => _pushLogin('client'),
                      ),
                    ],
                    chrome: chrome,
                    scheme: scheme,
                    visual: visual,
                  ),
                  // Sign Up tab
                  _RoleCardGrid(
                    cards: [
                      _RoleCard(
                        icon: Icons.cast_for_education_rounded,
                        title: 'As Tutor',
                        subtitle: 'I teach students',
                        accentColor: VibrantColors.warmYellow,
                        onTap: () => _pushSignup('tutor'),
                      ),
                      _RoleCard(
                        icon: Icons.menu_book_rounded,
                        title: 'As Student',
                        subtitle: 'I take classes',
                        accentColor: VibrantColors.pastelGreen,
                        onTap: () => _pushSignup('client'),
                      ),
                    ],
                    chrome: chrome,
                    scheme: scheme,
                    visual: visual,
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

// ── Segmented tab bar ────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isSignIn = controller.index == 0;
        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: chrome.mutedColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: chrome.mutedColor.withOpacity(0.15)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: isSignIn ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: chrome.textColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TabChip(
                      label: 'Sign In',
                      selected: isSignIn,
                      selectedColor: scheme.surface,
                      unselectedColor: scheme.onSurface.withOpacity(0.65),
                      onTap: () => controller.animateTo(0),
                    ),
                  ),
                  Expanded(
                    child: _TabChip(
                      label: 'Sign Up',
                      selected: !isSignIn,
                      selectedColor: scheme.surface,
                      unselectedColor: scheme.onSurface.withOpacity(0.65),
                      onTap: () => controller.animateTo(1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? selectedColor : unselectedColor,
                ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ── Role card grid ───────────────────────────────────────────────────────────

class _RoleCardGrid extends StatelessWidget {
  const _RoleCardGrid({
    required this.cards,
    required this.chrome,
    required this.scheme,
    required this.visual,
  });
  final List<_RoleCard> cards;
  final AppChromeTheme chrome;
  final ColorScheme scheme;
  final AppVisualStyle visual;

  @override
  Widget build(BuildContext context) {
    // Separate wide cards from regular ones.
    final regular = cards.where((c) => !c.wide).toList();
    final wide = cards.where((c) => c.wide).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          if (regular.isNotEmpty)
            Row(
              children: [
                for (int i = 0; i < regular.length; i++) ...[
                  Expanded(
                    child: _buildCard(context, regular[i]),
                  ),
                  if (i < regular.length - 1) const SizedBox(width: 14),
                ],
              ],
            ),
          for (final w in wide) ...[
            const SizedBox(height: 14),
            _buildCard(context, w),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _RoleCard card) {
    final cardColor = visual.neumorphism ? scheme.surface : chrome.surfaceColor;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.10)),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: card.onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: card.wide
                ? Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: card.accentColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: card.accentColor.withOpacity(0.18)),
                        ),
                        child: Icon(card.icon, color: card.accentColor, size: 26),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: chrome.textColor,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: chrome.mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: chrome.mutedColor,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: card.accentColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: card.accentColor.withOpacity(0.18)),
                        ),
                        child: Icon(card.icon, color: card.accentColor, size: 26),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: chrome.textColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: chrome.mutedColor,
                              fontWeight: FontWeight.w500,
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

class _RoleCard {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.wide = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool wide;
}
