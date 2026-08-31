import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/shop_climate_context.dart';
import 'circular_metric_ring.dart';
import 'climate_hero_presentation.dart';
import 'env_metric_category_theme.dart';
import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// PO — Pure white glass ENV weather widget (hero + range bar + framed rings).
class EnvironmentWidgetCard extends StatelessWidget {
  const EnvironmentWidgetCard({
    super.key,
    required this.climate,
    this.onDetail,
    this.compact = false,
  });

  final ShopClimateContext climate;
  final VoidCallback? onDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brief = climate.brief;
    final hero = ClimateHeroPresentation.fromClimate(climate);
    final calm = brief.calmTargetC;
    final advisory = ClimateHeroPresentation.clinicalAdvisory(climate);
    final advisoryBand = SemanticSignalTheme.headlineBand(
      headline: brief.headline,
      alertKeys: brief.alerts.map((a) => a.key).toList(),
      ssiScore: climate.ssi.score,
      tempC: climate.tempC,
      calmTargetC: calm,
      uvIndex: climate.uvIndex,
      pm25UgM3: climate.pm25UgM3,
      humidityPct: climate.humidityPct,
    );

    final tempBand =
        SemanticSignalTheme.bandForTempComfort(climate.tempC, calm);
    final uvBand = SemanticSignalTheme.bandForUv(climate.uvIndex);
    final humidityBand =
        SemanticSignalTheme.bandForHumidity(climate.humidityPct);
    final pmBand = SemanticSignalTheme.bandForPm25(climate.pm25UgM3);

    final padding = compact
        ? VolumeGlassTheme.compactPadding
        : VolumeGlassTheme.cardPadding;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Material(
            color: Colors.white.withValues(alpha: 0.72),
            elevation: 0,
            child: InkWell(
              onTap: onDetail,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(VolumeGlassTheme.cardRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WeatherHero(
                        climate: climate,
                        hero: hero,
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 12 : 16),
                      _DayTempRangeBar(
                        minC: hero.dayMinC,
                        maxC: hero.dayMaxC,
                        currentC: climate.tempC.round(),
                        position: hero.dayRangePosition,
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Text(
                        advisory,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: SemanticSignalTheme.bandTextColor(
                            advisoryBand,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricFrame(
                              compact: compact,
                              child: CircularMetricRing(
                                progress:
                                    ClimateHeroPresentation.tempProgress(
                                  climate.tempC,
                                  calm,
                                ),
                                value: '${climate.tempC.round()}°',
                                title: '온도',
                                status: ClimateHeroPresentation.bandStatus(
                                  tempBand,
                                ),
                                arcColor: EnvMetricCategoryTheme.arcColor(
                                  EnvMetricCategory.temperature,
                                ),
                                arcGradient: EnvMetricCategoryTheme
                                    .arcGradient(
                                  EnvMetricCategory.temperature,
                                ),
                                statusBand: tempBand,
                                compact: true,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Expanded(
                            child: _MetricFrame(
                              compact: compact,
                              child: CircularMetricRing(
                                progress: ClimateHeroPresentation.uvProgress(
                                  climate.uvIndex,
                                ),
                                value: '${climate.uvIndex}',
                                title: '자외선',
                                status: ClimateHeroPresentation.bandStatus(
                                  uvBand,
                                ),
                                arcColor: EnvMetricCategoryTheme.arcColor(
                                  EnvMetricCategory.uv,
                                ),
                                statusBand: uvBand,
                                compact: true,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Expanded(
                            child: _MetricFrame(
                              compact: compact,
                              child: CircularMetricRing(
                                progress:
                                    ClimateHeroPresentation.humidityProgress(
                                  climate.humidityPct,
                                ),
                                value: '${climate.humidityPct}%',
                                title: '습도',
                                status: ClimateHeroPresentation.bandStatus(
                                  humidityBand,
                                ),
                                arcColor: EnvMetricCategoryTheme.arcColor(
                                  EnvMetricCategory.humidity,
                                ),
                                statusBand: humidityBand,
                                compact: true,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Expanded(
                            child: _MetricFrame(
                              compact: compact,
                              child: CircularMetricRing(
                                progress:
                                    ClimateHeroPresentation.pm25Progress(
                                  climate.pm25UgM3,
                                ),
                                value: '${climate.pm25UgM3}',
                                title: '미세먼지',
                                status: ClimateHeroPresentation.bandStatus(
                                  pmBand,
                                ),
                                arcColor: EnvMetricCategoryTheme.arcColor(
                                  EnvMetricCategory.pm25,
                                ),
                                statusBand: pmBand,
                                compact: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
    final iconSize = compact ? 44.0 : 52.0;
    final tempSize = compact ? 48.0 : 60.0;

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
          ),
        ),
      ],
    );
  }
}

class _DayTempRangeBar extends StatelessWidget {
  const _DayTempRangeBar({
    required this.minC,
    required this.maxC,
    required this.currentC,
    required this.position,
    required this.compact,
  });

  final int minC;
  final int maxC;
  final int currentC;
  final double position;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '최저 $minC°',
              style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5AC8FA),
              ),
            ),
            Text(
              '최고 $maxC°',
              style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
                fontWeight: FontWeight.w700,
                color: SemanticSignalTheme.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final markerX = w * position;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: compact ? 8 : 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF5AC8FA),
                        Color(0xFFFFCC00),
                        Color(0xFFFF9500),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (markerX - 7).clamp(0.0, w - 14),
                  top: compact ? -3 : -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SemanticSignalTheme.heroTextColor,
                        width: 2,
                      ),
                      boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.06),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          '현재 $currentC°',
          style: VolumeGlassTheme.labelTextStyle(compact: true),
        ),
      ],
    );
  }
}

class _MetricFrame extends StatelessWidget {
  const _MetricFrame({
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 12,
        horizontal: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
