import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/shop_weather_context.dart';
import 'sori_narrative_block.dart';

/// PRD v4.0 Module 1 — 투데이 환경 역학 & 매장 템포 보드.
class OperationEnvironmentBoard extends StatelessWidget {
  const OperationEnvironmentBoard({
    super.key,
    required this.weather,
    required this.tempoLevel,
    this.scheduledCount = 0,
    this.inProgressCount = 0,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final ShopWeatherContext weather;
  final int tempoLevel;
  final int scheduledCount;
  final int inProgressCount;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final tempoDots = List.generate(4, (i) => i < tempoLevel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: collapsed
                ? _CollapsedStrip(
                    weather: weather,
                    tempoLevel: tempoLevel,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '환경 · 템포',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: VisitGlassTokens.sage,
                            ),
                          ),
                          const Spacer(),
                          _TempoDots(filled: tempoDots),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${weather.tempC.toStringAsFixed(0)}°C · 습 ${weather.humidityPct}% · UV ${weather.uvIndex}',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SoriNarrativeBlock(
                        headline: weather.headline,
                        narrative: weather.narrative,
                        icon: Icons.thermostat_rounded,
                        compact: true,
                      ),
                      if (tempoLevel >= 4) ...[
                        const SizedBox(height: 10),
                        const SoriNarrativeBlock(
                          headline: '과밀 스케줄',
                          narrative:
                              '워크인은 15분 이상 공백 슬롯에서만 권장합니다.',
                          icon: Icons.schedule_rounded,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedStrip extends StatelessWidget {
  const _CollapsedStrip({
    required this.weather,
    required this.tempoLevel,
  });

  final ShopWeatherContext weather;
  final int tempoLevel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${weather.tempC.toStringAsFixed(0)}°C · 진정 ${weather.calmTargetC.toStringAsFixed(1)}°C',
          style: VisitGlassTokens.captionCalm.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _TempoDots(
          filled: List.generate(4, (i) => i < tempoLevel),
          compact: true,
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more_rounded, size: 18, color: VisitGlassTokens.sage),
      ],
    );
  }
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
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled[i]
                  ? VisitGlassTokens.care.withValues(
                      alpha: 0.25 + (i + 1) * 0.18,
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
