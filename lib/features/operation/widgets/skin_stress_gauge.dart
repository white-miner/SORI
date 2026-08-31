import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import 'semantic_band_theme.dart';
import '../models/skin_stress_index.dart';

/// PRD v4.4 — SSI 반원 게이지 (Zone C semantic tint).
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

  static Color bandColor(SsiBand band) => SemanticBandTheme.ssiArcColor(band);

  @override
  Widget build(BuildContext context) {
    final arcH = size * 0.55;
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
          Positioned(
            bottom: showLabel ? 18 : 4,
            child: Text(
              '${ssi.score}',
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w600,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: SemanticBandTheme.ssiArcColor(ssi.band),
              ),
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

    final trackPaint = Paint()
      ..color = const Color(0xFFF2F2F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = SkinStressGauge.bandColor(band)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepMax, false, trackPaint);

    final sweep = sweepMax * (score.clamp(0, 100) / 100);
    if (sweep > 0) {
      canvas.drawArc(rect, startAngle, sweep, false, valuePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SemicircleGaugePainter old) =>
      old.score != score || old.band != band;
}
