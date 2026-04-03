import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';

class DashboardMeter extends StatelessWidget {
  const DashboardMeter({
    super.key,
    required this.completed,
    required this.pending,
    required this.upcoming,
    required this.total,
    required this.centerValue,
    required this.centerLabel,
    this.size,
    this.strokeWidth = 20,
    this.trackColor,
    this.textColor,
  });

  final int completed;
  final int pending;
  final int upcoming;
  final int total;
  final String centerValue;
  final String centerLabel;

  final double? size;
  final double strokeWidth;
  final Color? trackColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final resolvedTrackColor = trackColor ?? chrome.mutedColor.withOpacity(0.08);

    final valueStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          color: textColor ?? chrome.textColor,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -1,
          height: 1.0,
        );

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: (textColor ?? chrome.mutedColor).withOpacity(0.5),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.2,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        
        // We want a wide arch, so we prioritize width but limit height by constraints
        final meterWidth = size ?? availableWidth;
        final meterHeight = math.min(availableHeight, meterWidth * 0.65);

        return SizedBox(
          width: meterWidth,
          height: meterHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CustomPaint(
                size: Size(meterWidth, meterHeight),
                painter: _MeterPainter(
                  completed: completed,
                  pending: pending,
                  upcoming: upcoming,
                  total: total,
                  strokeWidth: strokeWidth,
                  trackColor: resolvedTrackColor,
                ),
              ),
              // Center the text in the hollow area of the arch
              Positioned(
                bottom: strokeWidth * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      style: valueStyle,
                    ),
                    if (centerLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        centerLabel.toUpperCase(),
                        style: labelStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({
    required this.completed,
    required this.pending,
    required this.upcoming,
    required this.total,
    required this.strokeWidth,
    required this.trackColor,
  });

  final int completed;
  final int pending;
  final int upcoming;
  final int total;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Center at the bottom to maximize the "arch" look
    final strokeOffset = strokeWidth / 2;
    final center = Offset(size.width / 2, size.height - strokeOffset);
    
    // Radius must be constrained by both width and height to prevent clipping
    final radius = math.min(size.width / 2, size.height - strokeOffset) - strokeOffset;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Perfect semi-circle with sharp ends.
    const totalSweep = math.pi;
    const startAngle = math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 1. Draw Background Track
    paint.color = trackColor;
    canvas.drawArc(rect, startAngle, totalSweep, false, paint);

    if (total <= 0) return;

    final safeTotal = total.toDouble();
    double currentAngle = startAngle;

    void drawSegment(double count, Color color) {
      if (count <= 0) return;
      
      final sweep = (count / safeTotal) * totalSweep;

      paint.color = color;
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      
      currentAngle += sweep;
    }

    // Sequence: Done (Green) -> Wait (Pink) -> Next (Yellow)
    drawSegment(completed.toDouble(), VibrantColors.pastelGreen);
    drawSegment(pending.toDouble(), VibrantColors.softPink);
    drawSegment(upcoming.toDouble(), VibrantColors.warmYellow);
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.upcoming != upcoming ||
        oldDelegate.total != total ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor;
  }
}
