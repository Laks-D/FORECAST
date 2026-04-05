import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.radius,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = AppVisualStyle.of(context);
    final r = radius ?? AppRadii.lg;

    final surface = color ?? scheme.surface;

    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(
            context,
            blurRadius: 18,
            offset: const Offset(6, 6),
            shadowOpacityLight: 0.08,
          )
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ];

    final cardChild = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(r),
            boxShadow: shadows,
          ),
          child: cardChild,
        ),
      ),
    );
  }
}
