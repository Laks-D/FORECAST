import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;

import '../../../core/app/app_mode.dart';
import '../../../core/app/app_mode_cubit.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import '../../../design_system/theme/app_visual_style.dart';

class ModeChooserScreen extends StatefulWidget {
  const ModeChooserScreen({super.key});

  @override
  State<ModeChooserScreen> createState() => _ModeChooserScreenState();
}

class _ModeChooserScreenState extends State<ModeChooserScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);

    Widget modeCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      final shadows = visual.neumorphism
          ? AppVisualStyle.neumorphicShadows(
              context,
              blurRadius: 22,
              offset: const Offset(7, 7),
            )
          : <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ];

      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: chrome.mutedColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: chrome.textColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: chrome.mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: chrome.mutedColor),
                ],
              ),
            ),
          ),
        ),
      );
    }


    Widget floatingIcon({
      required IconData icon,
      required Alignment alignment,
      required double baseSize,
      required double phase,
      required double opacity,
    }) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final dy = math.sin(t + phase) * 10;
          final dx = math.cos(t + phase) * 6;
          return Align(
            alignment: alignment,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Icon(
                icon,
                size: baseSize,
                color: chrome.mutedColor.withOpacity(opacity),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Floating background symbols (theme-tinted).
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      floatingIcon(
                        icon: Icons.calendar_month_outlined,
                        alignment: const Alignment(-0.95, -0.85),
                        baseSize: 34,
                        phase: 0.2,
                        opacity: 0.22,
                      ),
                      floatingIcon(
                        icon: Icons.payments_outlined,
                        alignment: const Alignment(0.92, -0.72),
                        baseSize: 36,
                        phase: 1.3,
                        opacity: 0.20,
                      ),
                      floatingIcon(
                        icon: Icons.menu_book_outlined,
                        alignment: const Alignment(-0.90, 0.15),
                        baseSize: 40,
                        phase: 2.1,
                        opacity: 0.18,
                      ),
                      floatingIcon(
                        icon: Icons.school_outlined,
                        alignment: const Alignment(0.95, 0.10),
                        baseSize: 44,
                        phase: 0.8,
                        opacity: 0.16,
                      ),
                      floatingIcon(
                        icon: Icons.star_outline,
                        alignment: const Alignment(0.70, 0.92),
                        baseSize: 32,
                        phase: 2.8,
                        opacity: 0.16,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Foreground content.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you a student or tutor?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick your perspective to continue.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: chrome.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 18),
                  modeCard(
                    title: 'Tutor',
                    subtitle: 'Manage students, classes, and payments',
                    icon: Icons.school_outlined,
                    onTap: () =>
                        context.read<AppModeCubit>().setMode(AppMode.admin),
                  ),
                  const SizedBox(height: 14),
                  modeCard(
                    title: 'Student',
                    subtitle: 'View your classes, courses, and payments',
                    icon: Icons.person_outline,
                    onTap: () =>
                        context.read<AppModeCubit>().setMode(AppMode.client),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: chrome.mutedColor.withOpacity(0.10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: chrome.mutedColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Student mode is view-only, with profile editing.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: chrome.mutedColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
