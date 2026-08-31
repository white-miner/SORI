import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';
import '../models/skin_stress_index.dart';

/// PRD v4.6 — 7-day sparkline with Stocks-style gradient fill.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    super.key,
    required this.values,
    this.width = 160,
    this.height = 52,
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
    final band = ssiBand != null
        ? SemanticSignalTheme.bandForSsiBand(ssiBand!)
        : SemanticSignalTheme.bandForSurge(surgePct);
    final color = SemanticSignalTheme.sparklineColor(
      band: band,
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

    // Baseline grid hint (Stocks)
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, size.height * 0.75),
      Offset(size.width, size.height * 0.75),
      gridPaint,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.38),
          color.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final norm = range <= 0 ? 0.5 : (values[i] - min) / range;
      final y = size.height - norm * size.height * 0.88 - size.height * 0.06;
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
