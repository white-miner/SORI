import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/shop_climate_context.dart';
import 'skin_stress_gauge.dart';

/// PRD v4.2-B — 상담 탭 상단 고정 Clinical Assistant Strip.
class ClinicalAssistantStrip extends StatelessWidget {
  const ClinicalAssistantStrip({
    super.key,
    required this.climate,
    required this.tempoLevel,
    this.onTap,
  });

  final ShopClimateContext climate;
  final int tempoLevel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brief = climate.brief;
    final tempoDots = List.generate(4, (i) => i < tempoLevel);

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SkinStressGauge(
                ssi: climate.ssi,
                size: 72,
                strokeWidth: 6,
                showLabel: false,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Clinical Assistant',
                          style: VisitGlassTokens.captionCalm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: VisitGlassTokens.sage,
                          ),
                        ),
                        const Spacer(),
                        _TempoDots(filled: tempoDots, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brief.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: VisitGlassTokens.care,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${climate.tempC.toStringAsFixed(0)}°C · 습 ${climate.humidityPct}% · UV ${climate.uvIndex} · PM2.5 ${climate.pm25UgM3}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VisitGlassTokens.captionCalm.copyWith(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: VisitGlassTokens.sage.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicalAssistantStripDelegate extends SliverPersistentHeaderDelegate {
  ClinicalAssistantStripDelegate({
    required this.climate,
    required this.tempoLevel,
    this.onTap,
  });

  final ShopClimateContext climate;
  final int tempoLevel;
  final VoidCallback? onTap;

  static const stripHeight = 88.0;

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
    return ClinicalAssistantStrip(
      climate: climate,
      tempoLevel: tempoLevel,
      onTap: onTap,
    );
  }

  @override
  bool shouldRebuild(covariant ClinicalAssistantStripDelegate old) =>
      old.climate != climate || old.tempoLevel != tempoLevel;
}

class _TempoDots extends StatelessWidget {
  const _TempoDots({required this.filled, this.compact = false});

  final List<bool> filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < filled.length; i++)
          Container(
            width: compact ? 5 : 7,
            height: compact ? 5 : 7,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled[i]
                  ? VisitGlassTokens.care.withValues(
                      alpha: 0.15 + (i + 1) * 0.15,
                    )
                  : const Color(0xFFE5E5EA),
            ),
          ),
      ],
    );
  }
}

int computeTempoLevel({
  required int scheduledCount,
  required int inProgressCount,
}) {
  final load = scheduledCount + inProgressCount;
  if (load >= 8) return 4;
  if (load >= 5) return 3;
  if (load >= 3) return 2;
  return 1;
}
