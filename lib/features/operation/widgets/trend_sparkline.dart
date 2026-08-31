import 'package:flutter/material.dart';

import 'semantic_band_theme.dart';
import '../models/skin_stress_index.dart';

/// PRD v4.4 — 7일 sparkline with semantic stroke.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    super.key,
    required this.values,
    this.width = 160,
    this.height = 40,
    this.ssiBand,
    this.surgePct = 0,
  });

  final List<int> values;
  final double width;
  final double height;
  final SsiBand? ssiBand;
  final int surgePct;

  @override
  Widget build(BuildContext context) {
    final color = SemanticBandTheme.sparklineColor(
      ssiBand,
      surgePct: surgePct,
    );
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(values: values, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = max - min;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final norm = range <= 0 ? 0.5 : (values[i] - min) / range;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
