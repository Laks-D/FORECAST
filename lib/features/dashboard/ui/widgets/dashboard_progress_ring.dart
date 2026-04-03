import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';

class DashboardProgressRing extends StatelessWidget {
  const DashboardProgressRing({
    super.key,
    required this.progress, // 0..1
    required this.centerValue,
    required this.centerLabel,
    this.size,
    this.strokeWidth = 10,
    this.progressColor = VibrantColors.pastelGreen,
    this.trackColor,
    this.textColor,
  });

  final double progress;
  final String centerValue;
  final String centerLabel;

  final double? size;
  final double strokeWidth;
  final Color progressColor;
  final Color? trackColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final resolvedTrackColor = trackColor ?? chrome.mutedColor.withOpacity(0.15);
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: textColor ?? chrome.textColor,
          fontWeight: FontWeight.w700,
        );

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: (textColor ?? chrome.mutedColor).withOpacity(0.8),
          fontWeight: FontWeight.w500,
        );

    final content = Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _RingPainter(
            progress: p,
            strokeWidth: strokeWidth,
            progressColor: progressColor,
            trackColor: resolvedTrackColor,
          ),
          child: const SizedBox.expand(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(centerValue, style: valueStyle),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(centerLabel, style: labelStyle),
              ),
            ],
          ),
        ),
      ],
    );

    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(width: s, height: s, child: content);
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Match the reference: a ~3/4 ring (open gap at bottom-right).
    final startAngle = _degToRad(140);
    final totalSweep = _degToRad(260);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(rect, startAngle, totalSweep, false, paint);

    paint.color = progressColor;
    canvas.drawArc(rect, startAngle, totalSweep * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
