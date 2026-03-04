import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashboardMeter extends StatelessWidget {
  const DashboardMeter({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.size = 120,
    this.valueText,
    this.minText,
    this.maxText,
    this.needleColor = const Color(0xFF3A3A3A),
    this.needleWidth = 4,
  });

  final double value;
  final double min;
  final double max;
  final double size;

  final String? valueText;
  final String? minText;
  final String? maxText;

  final Color needleColor;
  final double needleWidth;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    final t = (max - min) <= 0 ? 0.0 : ((clamped - min) / (max - min));

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        );

    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );

    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size * 0.78,
            child: CustomPaint(
              painter: _GaugePainter(
                t: t,
                needleColor: needleColor,
                needleWidth: needleWidth,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(valueText ?? _formatMoney(value), style: valueStyle),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  minText ?? _formatMoney(min),
                  style: labelStyle,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  maxText ?? _formatMoney(max),
                  style: labelStyle,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatMoney(double v) {
    return r'$' + v.toStringAsFixed(2);
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.t, required this.needleColor, required this.needleWidth});

  final double t;
  final Color needleColor;
  final double needleWidth;

  static const _trackWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - _trackWidth;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final startAngle = _degToRad(210);
    final sweepTotal = _degToRad(240);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _trackWidth
      ..color = const Color(0xFFD7D7D7);

    // Neutral (non-colored) gauge track.
    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);

    final needleAngle = startAngle + sweepTotal * t;
    final needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = needleWidth;

    final needleLen = radius * 0.72;
    final needleEnd = center + Offset(
          math.cos(needleAngle) * needleLen,
          math.sin(needleAngle) * needleLen,
        );

    canvas.drawLine(center, needleEnd, needlePaint);

    final hubPaint = Paint()..color = needleColor;
    canvas.drawCircle(center, 6.5, hubPaint);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.needleColor != needleColor || oldDelegate.needleWidth != needleWidth;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
