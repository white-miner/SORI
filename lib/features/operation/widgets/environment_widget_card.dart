import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/shop_climate_context.dart';
import 'circular_metric_ring.dart';
import 'climate_hero_presentation.dart';
import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';
import 'widget_glass_card.dart';

/// PO — iOS Weather-style ENV widget (hero temp + 4 circular ring row).
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
    final hero = ClimateHeroPresentation.fromClimate(climate);
    final calm = brief.calmTargetC;

    final tempBand = SemanticSignalTheme.bandForTempComfort(
      climate.tempC,
      calm,
    );
    final uvBand = SemanticSignalTheme.bandForUv(climate.uvIndex);
    final humidityBand = SemanticSignalTheme.bandForHumidity(climate.humidityPct);
    final pmBand = SemanticSignalTheme.bandForPm25(climate.pm25UgM3);

    return WidgetGlassCard(
      semanticBand: signal,
      ambientColors: SemanticSignalTheme.ambientGradient(signal),
      ambientShadowColor: SemanticSignalTheme.shellShadow(signal),
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  compact ? 'ENV' : 'ENV · CLINICAL ASSISTANT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: SemanticSignalTheme.secondaryTextColor,
                  ),
                ),
              ),
              WidgetTempoMicroBar(level: tempoLevel),
              const SizedBox(width: 6),
              WidgetDetailChevron(onTap: onDetail),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          _WeatherHero(
            climate: climate,
            hero: hero,
            compact: compact,
          ),
          SizedBox(height: compact ? 14 : 18),
          Row(
            children: [
              Expanded(
                child: CircularMetricRing(
                  progress: ClimateHeroPresentation.tempProgress(
                    climate.tempC,
                    calm,
                  ),
                  value: '${climate.tempC.round()}°',
                  title: '온도',
                  status: ClimateHeroPresentation.bandStatus(tempBand),
                  band: tempBand,
                  compact: compact,
                ),
              ),
              Expanded(
                child: CircularMetricRing(
                  progress: ClimateHeroPresentation.uvProgress(climate.uvIndex),
                  value: '${climate.uvIndex}',
                  title: '자외선',
                  status: ClimateHeroPresentation.bandStatus(uvBand),
                  band: uvBand,
                  compact: compact,
                ),
              ),
              Expanded(
                child: CircularMetricRing(
                  progress: ClimateHeroPresentation.humidityProgress(
                    climate.humidityPct,
                  ),
                  value: '${climate.humidityPct}%',
                  title: '습도',
                  status: ClimateHeroPresentation.bandStatus(humidityBand),
                  band: humidityBand,
                  compact: compact,
                ),
              ),
              Expanded(
                child: CircularMetricRing(
                  progress: ClimateHeroPresentation.pm25Progress(
                    climate.pm25UgM3,
                  ),
                  value: '${climate.pm25UgM3}',
                  title: '미세먼지',
                  status: ClimateHeroPresentation.bandStatus(pmBand),
                  band: pmBand,
                  compact: compact,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            brief.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: SemanticSignalTheme.bandTextColor(
                SemanticSignalTheme.headlineBand(
                  headline: brief.headline,
                  alertKeys: brief.alerts.map((a) => a.key).toList(),
                  ssiScore: climate.ssi.score,
                  tempC: climate.tempC,
                  calmTargetC: calm,
                  uvIndex: climate.uvIndex,
                  pm25UgM3: climate.pm25UgM3,
                  humidityPct: climate.humidityPct,
                ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              '진정 ${calm.toStringAsFixed(1)}°C · SSI ${climate.ssi.score} · '
              '장비 L${brief.deviceIntensityCap}',
              textAlign: TextAlign.center,
              style: VolumeGlassTheme.labelTextStyle(compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({
    required this.climate,
    required this.hero,
    required this.compact,
  });

  final ShopClimateContext climate;
  final ClimateHeroPresentation hero;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 44.0 : 56.0;
    final tempSize = compact ? 48.0 : 64.0;

    return Column(
      children: [
        Icon(
          hero.icon,
          size: iconSize,
          color: SemanticSignalTheme.orange.withValues(alpha: 0.92),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          '${climate.tempC.round()}°',
          style: GoogleFonts.nunito(
            fontSize: tempSize,
            fontWeight: FontWeight.w200,
            height: 1.0,
            color: SemanticSignalTheme.heroTextColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          hero.detailLine,
          textAlign: TextAlign.center,
          style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: SemanticSignalTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
