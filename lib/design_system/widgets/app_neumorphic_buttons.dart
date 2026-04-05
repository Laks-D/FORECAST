import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';

class AppNeumorphicIconButton extends StatelessWidget {
  const AppNeumorphicIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final visual = AppVisualStyle.of(context);

    if (!visual.neumorphism) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: radius,
              boxShadow: AppVisualStyle.neumorphicShadows(
                context,
                blurRadius: 18,
                offset: const Offset(6, 6),
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AppNeumorphicPillButton extends StatelessWidget {
  const AppNeumorphicPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final visual = AppVisualStyle.of(context);

    if (!visual.neumorphism) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: radius,
            boxShadow: AppVisualStyle.neumorphicShadows(
              context,
              blurRadius: 18,
              offset: const Offset(6, 6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
