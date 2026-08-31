import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/shop_climate_context.dart';
import 'semantic_band_theme.dart';
import 'skin_stress_gauge.dart';
import 'widget_glass_card.dart';

/// PRD v4.4 — SSI Environment iOS widget card (~200px phone).
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
    final band = climate.ssi.band;
    final ambient = SemanticBandTheme.ssiAmbientGradient(band);

    return WidgetGlassCard(
      ambientColors: ambient,
      ambientShadowColor: SemanticBandTheme.ssiArcColor(band).withValues(
        alpha: 0.12,
      ),
      padding: compact
          ? const EdgeInsets.all(12)
          : const EdgeInsets.all(16),
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
                    color: VisitGlassTokens.sage,
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
                            color: SemanticBandTheme.ssiBadgeBg(band),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            band.label,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w700,
                              color: SemanticBandTheme.ssiBadgeText(band),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: VisitGlassTokens.care,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '진정 ${brief.calmTargetC.toStringAsFixed(1)}°C · 장비 L${brief.deviceIntensityCap}',
              style: VisitGlassTokens.captionCalm.copyWith(fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              brief.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VisitGlassTokens.captionCalm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
    return Row(
      children: [
        Expanded(child: _MetricTile('온도', '${climate.tempC.toStringAsFixed(0)}°', compact: compact)),
        SizedBox(width: compact ? 4 : 6),
        Expanded(child: _MetricTile('습도', '${climate.humidityPct}%', compact: compact)),
        SizedBox(width: compact ? 4 : 6),
        Expanded(child: _MetricTile('UV', '${climate.uvIndex}', compact: compact)),
        SizedBox(width: compact ? 4 : 6),
        Expanded(child: _MetricTile('PM2.5', '${climate.pm25UgM3}', compact: compact)),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value, {this.compact = false});

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 4 : 6,
        horizontal: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: VisitGlassTokens.captionCalm.copyWith(
              fontSize: compact ? 8 : 9,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
