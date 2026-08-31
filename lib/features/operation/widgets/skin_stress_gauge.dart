import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/skin_stress_index.dart';
import 'semantic_signal_theme.dart';

/// PRD v4.6 — SSI semicircle gauge (hero achromatic, arc semantic).
class SkinStressGauge extends StatelessWidget {
  const SkinStressGauge({
    super.key,
    required this.ssi,
    this.size = 112,
    this.strokeWidth = 9,
    this.showLabel = true,
  });

  final SkinStressIndex ssi;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  static Color bandColor(SsiBand band) =>
      SemanticSignalTheme.bandColor(
        SemanticSignalTheme.bandForSsiBand(band),
      );

  @override
  Widget build(BuildContext context) {
    final arcH = size * 0.55;
    final signal = SemanticSignalTheme.bandForSsiBand(ssi.band);
    return SizedBox(
      width: size,
      height: arcH + (showLabel ? 22 : 0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(size, arcH),
            painter: _SemicircleGaugePainter(
              score: ssi.score,
              band: ssi.band,
              strokeWidth: strokeWidth,
            ),
          ),
          if (showLabel)
            Positioned(
              bottom: 0,
              child: Text(
                'SSI · ${ssi.band.label}',
                style: VisitGlassTokens.captionCalm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: SemanticSignalTheme.badgeText(signal),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SemicircleGaugePainter extends CustomPainter {
  _SemicircleGaugePainter({
    required this.score,
    required this.band,
    required this.strokeWidth,
  });

  final int score;
  final SsiBand band;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - strokeWidth / 2;
    const startAngle = math.pi;
    const sweepMax = math.pi;
    final accent = SkinStressGauge.bandColor(band);

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final valuePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepMax, false, trackPaint);

    final sweep = sweepMax * (score.clamp(0, 100) / 100);
    if (sweep > 0) {
      canvas.drawArc(rect, startAngle, sweep, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweep, false, valuePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SemicircleGaugePainter old) =>
      old.score != score || old.band != band;
}
