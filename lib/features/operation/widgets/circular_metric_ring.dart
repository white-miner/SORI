import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// iOS Weather-style circular metric ring (270° arc).
class CircularMetricRing extends StatelessWidget {
  const CircularMetricRing({
    super.key,
    required this.progress,
    required this.value,
    required this.title,
    required this.status,
    required this.arcColor,
    required this.statusBand,
    this.arcGradient,
    this.size = 72,
    this.strokeWidth = 5,
    this.compact = false,
  });

  final double progress;
  final String value;
  final String title;
  final String status;
  final Color arcColor;
  final List<Color>? arcGradient;
  final SemanticBand statusBand;
  final double size;
  final double strokeWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ringSize = compact ? size * 0.88 : size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              arcColor: arcColor,
              arcGradient: arcGradient,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: SemanticSignalTheme.heroTextColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          title,
          style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: SemanticSignalTheme.bandTextColor(statusBand),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.arcColor,
    required this.strokeWidth,
    this.arcGradient,
  });

  final double progress;
  final Color arcColor;
  final List<Color>? arcGradient;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    const startAngle = math.pi * 0.75;
    const sweepMax = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepMax, false, trackPaint);

    final sweep = sweepMax * progress;
    if (sweep <= 0.02) return;

    final gradient = arcGradient;
    final glowColor = gradient != null && gradient.isNotEmpty
        ? gradient.last
        : arcColor;

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null && gradient.length >= 2) {
      valuePaint.shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepMax,
        colors: gradient,
        stops: List.generate(
          gradient.length,
          (i) => i / (gradient.length - 1),
        ),
      ).createShader(rect);
    } else {
      valuePaint.color = arcColor;
    }

    canvas.drawArc(rect, startAngle, sweep, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweep, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.arcGradient != arcGradient;
}
