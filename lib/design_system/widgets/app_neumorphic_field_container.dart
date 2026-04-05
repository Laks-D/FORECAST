import 'package:flutter/material.dart';

import '../theme/app_chrome_theme.dart';
import '../theme/app_visual_style.dart';

class AppNeumorphicFieldContainer extends StatefulWidget {
  const AppNeumorphicFieldContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets? padding;

  @override
  State<AppNeumorphicFieldContainer> createState() =>
      _AppNeumorphicFieldContainerState();
}

class _AppNeumorphicFieldContainerState
    extends State<AppNeumorphicFieldContainer> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final visual = AppVisualStyle.of(context);
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!visual.neumorphism) {
      return widget.padding == null
          ? widget.child
          : Padding(padding: widget.padding!, child: widget.child);
    }

    // Apply the neumorphic depth only when the field is focused/active.
    final shadows = _focused
        ? AppVisualStyle.neumorphicShadows(
            context,
            blurRadius: 18,
            offset: const Offset(6, 6),
          )
        : const <BoxShadow>[];

    final border = Border.all(
      color: chrome.mutedColor.withOpacity(_focused ? 0.14 : 0.10),
    );

    return Focus(
      onFocusChange: (v) {
        if (!mounted) return;
        setState(() => _focused = v);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: widget.borderRadius,
          border: border,
          boxShadow: shadows,
        ),
        child: widget.child,
      ),
    );
  }
}
