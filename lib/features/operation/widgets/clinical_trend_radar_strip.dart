import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/clinical_trend_snapshot.dart';

/// PRD v4.3-B — Top3 무채색 미니 칩 스트립 (Z2 pinned, 44px).
class ClinicalTrendRadarStrip extends StatelessWidget {
  const ClinicalTrendRadarStrip({
    super.key,
    required this.snapshot,
    this.onTap,
    this.onChipTap,
  });

  final ClinicalTrendSnapshot snapshot;
  final VoidCallback? onTap;
  final void Function(ClinicalTrendItem item)? onChipTap;

  @override
  Widget build(BuildContext context) {
    final top3 = snapshot.top3;

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: ClinicalTrendRadarStripDelegate.stripHeight,
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              Text(
                'TREND',
                style: VisitGlassTokens.captionCalm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: VisitGlassTokens.sage,
                ),
              ),
              const SizedBox(width: 8),
              if (top3.isEmpty)
                Expanded(
                  child: Text(
                    '오늘 뚜렷한 급등 키워드 없음',
                    style: VisitGlassTokens.captionCalm.copyWith(fontSize: 11),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < top3.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _TrendChip(
                            item: top3[i],
                            onTap: onChipTap == null
                                ? null
                                : () => onChipTap!(top3[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: VisitGlassTokens.sage.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.item, this.onTap});

  final ClinicalTrendItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.surgePct > 0
        ? '${item.keyword} +${item.surgePct}%'
        : item.keyword;

    return Material(
      color: const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: VisitGlassTokens.care,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class ClinicalTrendRadarStripDelegate extends SliverPersistentHeaderDelegate {
  ClinicalTrendRadarStripDelegate({
    required this.snapshot,
    this.onTap,
    this.onChipTap,
  });

  final ClinicalTrendSnapshot snapshot;
  final VoidCallback? onTap;
  final void Function(ClinicalTrendItem item)? onChipTap;

  static const stripHeight = 44.0;

  @override
  double get minExtent => stripHeight;

  @override
  double get maxExtent => stripHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClinicalTrendRadarStrip(
      snapshot: snapshot,
      onTap: onTap,
      onChipTap: onChipTap,
    );
  }

  @override
  bool shouldRebuild(covariant ClinicalTrendRadarStripDelegate old) =>
      old.snapshot != snapshot;
}

/// PRD v4.3 — 7일 sparkline (CDG single stroke).
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    super.key,
    required this.values,
    this.width = 160,
    this.height = 40,
  });

  final List<int> values;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(values: values),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = max - min;
    final paint = Paint()
      ..color = const Color(0xFFAEAEB2)
      ..strokeWidth = 1.5
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values;
}
