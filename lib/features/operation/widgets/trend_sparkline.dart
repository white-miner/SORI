import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';
import '../models/skin_stress_index.dart';

/// PRD v4.6 — 7-day cubic-bezier sparkline with Stocks-style gradient fill.
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

  List<Offset> _toPoints(Size size) {
    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = max - min;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final norm = range <= 0 ? 0.5 : (values[i] - min) / range;
      final y = size.height - norm * size.height * 0.88 - size.height * 0.06;
      points.add(Offset(x, y));
    }
    return points;
  }

  void _appendSmoothCurve(Path path, List<Offset> points) {
    if (points.isEmpty) return;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return;
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i > 0 ? i - 1 : i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, size.height * 0.78),
      Offset(size.width, size.height * 0.78),
      gridPaint,
    );

    final points = _toPoints(size);
    final curve = Path();
    _appendSmoothCurve(curve, points);

    final fillPath = Path.from(curve)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.62),
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(curve, strokePaint);

    final dot = points.last;
    canvas.drawCircle(
      dot,
      3.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      dot,
      6,
      Paint()..color = color.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
