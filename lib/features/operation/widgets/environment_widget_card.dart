import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/shop_climate_context.dart';
import 'metric_inset_block.dart';
import 'semantic_signal_theme.dart';
import 'skin_stress_gauge.dart';
import 'widget_glass_card.dart';

/// PRD v4.6 — SSI Environment iOS Weather widget card.
class EnvironmentWidgetCard extends StatelessWidget {
  const EnvironmentWidgetCard({
    super.key,
    required this.climate,
    required this.tempoLevel,
    required this.onDetail,
    this.compact = false,
  });

  final ShopClimateContext climate;
  final int tempoLevel;
  final VoidCallback onDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brief = climate.brief;
    final signal = SemanticSignalTheme.bandForSsiBand(climate.ssi.band);
    final headlineBand = SemanticSignalTheme.headlineBand(
      headline: brief.headline,
      alertKeys: brief.alerts.map((a) => a.key).toList(),
      ssiScore: climate.ssi.score,
      tempC: climate.tempC,
      calmTargetC: brief.calmTargetC,
      uvIndex: climate.uvIndex,
      pm25UgM3: climate.pm25UgM3,
      humidityPct: climate.humidityPct,
    );

    return WidgetGlassCard(
      semanticBand: signal,
      ambientColors: SemanticSignalTheme.ambientGradient(signal),
      ambientShadowColor: SemanticSignalTheme.shellShadow(signal),
      padding: compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  compact ? 'ENV' : 'ENV · CLINICAL ASSISTANT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: SemanticSignalTheme.secondaryTextColor,
                  ),
                ),
              ),
              WidgetTempoMicroBar(level: tempoLevel),
              const SizedBox(width: 6),
              WidgetDetailChevron(onTap: onDetail),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkinStressGauge(
                ssi: climate.ssi,
                size: compact ? 80 : 108,
                strokeWidth: compact ? 7 : 9,
                showLabel: false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${climate.ssi.score}',
                          style: TextStyle(
                            fontSize: compact ? 28 : 34,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: SemanticSignalTheme.heroTextColor,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 8,
                            vertical: compact ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: SemanticSignalTheme.badgeBg(signal),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            climate.ssi.band.label,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w700,
                              color: SemanticSignalTheme.badgeText(signal),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    _MetricGrid(climate: climate, compact: compact),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(
              brief.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SemanticSignalTheme.bandTextColor(headlineBand),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '진정 ${brief.calmTargetC.toStringAsFixed(1)}°C · 장비 L${brief.deviceIntensityCap}',
              style: VisitGlassTokens.captionCalm.copyWith(
                fontSize: 11,
                color: SemanticSignalTheme.secondaryTextColor,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              brief.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SemanticSignalTheme.bandTextColor(headlineBand),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.climate, this.compact = false});

  final ShopClimateContext climate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final calm = climate.brief.calmTargetC;
    return Row(
      children: [
        Expanded(
          child: MetricInsetBlock(
            label: '온도',
            value: '${climate.tempC.toStringAsFixed(0)}°',
            band: SemanticSignalTheme.bandForTempComfort(
              climate.tempC,
              calm,
            ),
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 4 : 6),
        Expanded(
          child: MetricInsetBlock(
            label: '습도',
            value: '${climate.humidityPct}%',
            band: SemanticSignalTheme.bandForHumidity(climate.humidityPct),
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 4 : 6),
        Expanded(
          child: MetricInsetBlock(
            label: 'UV',
            value: '${climate.uvIndex}',
            band: SemanticSignalTheme.bandForUv(climate.uvIndex),
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 4 : 6),
        Expanded(
          child: MetricInsetBlock(
            label: 'PM2.5',
            value: '${climate.pm25UgM3}',
            band: SemanticSignalTheme.bandForPm25(climate.pm25UgM3),
            compact: compact,
          ),
        ),
      ],
    );
  }
}
