import 'package:flutter/material.dart';

@immutable
class AppVisualStyle extends ThemeExtension<AppVisualStyle> {
  const AppVisualStyle({required this.neumorphism});

  final bool neumorphism;

  static const fallback = AppVisualStyle(neumorphism: false);

  static AppVisualStyle of(BuildContext context) {
    return Theme.of(context).extension<AppVisualStyle>() ?? fallback;
  }

  /// Standard dual-shadow neumorphism.
  ///
  /// Uses subtle highlight/shadow in dark mode to avoid the bright white glow.
  static List<BoxShadow> neumorphicShadows(
    BuildContext context, {
    double blurRadius = 22,
    Offset offset = const Offset(7, 7),
    double highlightOpacityLight = 0.85,
    double highlightOpacityDark = 0.06,
    double shadowOpacityLight = 0.10,
    double shadowOpacityDark = 0.32,
  }) {
    final brightness = Theme.of(context).brightness;

    final highlightOpacity =
        brightness == Brightness.dark ? highlightOpacityDark : highlightOpacityLight;
    final shadowOpacity =
        brightness == Brightness.dark ? shadowOpacityDark : shadowOpacityLight;

    final dx = offset.dx.abs();
    final dy = offset.dy.abs();

    return <BoxShadow>[
      BoxShadow(
        color: Colors.white.withOpacity(highlightOpacity),
        blurRadius: blurRadius,
        offset: Offset(-dx, -dy),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(shadowOpacity),
        blurRadius: blurRadius,
        offset: Offset(dx, dy),
      ),
    ];
  }

  @override
  AppVisualStyle copyWith({bool? neumorphism}) {
    return AppVisualStyle(neumorphism: neumorphism ?? this.neumorphism);
  }

  @override
  AppVisualStyle lerp(ThemeExtension<AppVisualStyle>? other, double t) {
    if (other is! AppVisualStyle) return this;
    // Bool doesn't lerp; switch at halfway.
    return AppVisualStyle(neumorphism: t < 0.5 ? neumorphism : other.neumorphism);
  }
}
