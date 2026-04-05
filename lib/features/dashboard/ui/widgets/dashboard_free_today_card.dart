import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';

class DashboardFreeTodayCard extends StatelessWidget {
  const DashboardFreeTodayCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);

    final cardBgColor = visual.neumorphism ? scheme.surface : chrome.surfaceColor;
    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(context, blurRadius: 22, offset: const Offset(7, 7))
        : const <BoxShadow>[];

    final messageStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: chrome.textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
          boxShadow: shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final circleColor = scheme.onSurface.withOpacity(
                      visual.neumorphism ? 0.06 : 0.10,
                    );

                    final s = constraints.biggest.shortestSide;

                    return Center(
                      child: SizedBox(
                        width: s,
                        height: s,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    circleColor,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/no_schedule_image-removebg-preview.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Relax, you are free today!',
                style: messageStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'No sessions scheduled for now',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chrome.mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
