import 'package:flutter/material.dart';

class VibrantColors {
  // Slightly deeper pastels for better contrast on light surfaces.
  static const pastelGreen = Color(0xFF8FD4B6);
  static const softBlue = Color(0xFFAED7FF);
  static const warmYellow = Color(0xFFFFD178);
  static const softPink = Color(0xFFFFBDBC);

  /// Derive a deeper (more readable) tone from a pastel.
  /// Useful for text/icons on light tinted backgrounds.
  static Color deep(Color base) {
    final hsl = HSLColor.fromColor(base);
    // Clamp to a mid-dark lightness to keep contrast predictable.
    final l = (hsl.lightness * 0.55).clamp(0.22, 0.42);
    final s = (hsl.saturation * 1.05).clamp(0.25, 0.85);
    return hsl.withLightness(l).withSaturation(s).toColor();
  }

  /// Soft tinted background from a pastel.
  static Color tint(Color base, {double opacity = 0.14}) {
    return base.withOpacity(opacity.clamp(0.0, 1.0));
  }
}

@immutable
class AppChromeTheme extends ThemeExtension<AppChromeTheme> {
  const AppChromeTheme({
    required this.frameColor,
    required this.accentBlue,
    required this.surfaceColor,
    required this.textColor,
    required this.mutedColor,
  });

  static const fallback = AppChromeTheme(
    frameColor: Color(0xFF0B0B0C),
    accentBlue: Color(0xFF4F86B7),
    surfaceColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF111827),
    mutedColor: Color(0xFF6B7280),
  );

  final Color frameColor;
  final Color accentBlue;
  final Color surfaceColor;
  final Color textColor;
  final Color mutedColor;

  static AppChromeTheme of(BuildContext context) {
    return Theme.of(context).extension<AppChromeTheme>() ?? fallback;
  }

  @override
  AppChromeTheme copyWith({
    Color? frameColor,
    Color? accentBlue,
    Color? surfaceColor,
    Color? textColor,
    Color? mutedColor,
  }) {
    return AppChromeTheme(
      frameColor: frameColor ?? this.frameColor,
      accentBlue: accentBlue ?? this.accentBlue,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      textColor: textColor ?? this.textColor,
      mutedColor: mutedColor ?? this.mutedColor,
    );
  }

  @override
  AppChromeTheme lerp(ThemeExtension<AppChromeTheme>? other, double t) {
    if (other is! AppChromeTheme) return this;

    return AppChromeTheme(
      frameColor: Color.lerp(frameColor, other.frameColor, t) ?? frameColor,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t) ?? accentBlue,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t) ?? surfaceColor,
      textColor: Color.lerp(textColor, other.textColor, t) ?? textColor,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t) ?? mutedColor,
    );
  }
}
