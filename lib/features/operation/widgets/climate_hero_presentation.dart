import 'package:flutter/material.dart';

import '../models/shop_climate_context.dart';
import 'semantic_signal_theme.dart';

/// Derived hero-line data for ENV weather widget (KMA fields + estimates).
class ClimateHeroPresentation {
  const ClimateHeroPresentation({
    required this.icon,
    required this.feelsLikeC,
    required this.weatherLabel,
    required this.windSpeedMs,
    required this.dayMinC,
    required this.dayMaxC,
  });

  final IconData icon;
  final double feelsLikeC;
  final String weatherLabel;
  final double windSpeedMs;
  final int dayMinC;
  final int dayMaxC;

  String get detailLine =>
      '체감 ${feelsLikeC.round()}° · $weatherLabel · '
      '바람 ${windSpeedMs.toStringAsFixed(1)}m/s';

  double get dayRangePosition {
    final span = (dayMaxC - dayMinC).toDouble();
    if (span <= 0) return 0.5;
    return ((feelsLikeC - dayMinC) / span).clamp(0.06, 0.94);
  }

  factory ClimateHeroPresentation.fromClimate(ShopClimateContext climate) {
    final hour = DateTime.now().hour;
    final feels = _feelsLike(climate.tempC, climate.humidityPct);
    final weather = _weatherLabel(
      tempC: climate.tempC,
      humidityPct: climate.humidityPct,
      uvIndex: climate.uvIndex,
      pm25: climate.pm25UgM3,
      hour: hour,
    );
    final wind = _estimateWind(climate.tempC, climate.humidityPct, hour);
    final icon = _iconFor(weather, hour, climate.uvIndex);
    final range = _dayTempRange(climate.tempC, hour);

    return ClimateHeroPresentation(
      icon: icon,
      feelsLikeC: feels,
      weatherLabel: weather,
      windSpeedMs: wind,
      dayMinC: range.$1,
      dayMaxC: range.$2,
    );
  }

  static String clinicalAdvisory(ShopClimateContext climate) {
    final brief = climate.brief;
    if (brief.alerts.isNotEmpty) {
      final lead = brief.alerts.first;
      final body = lead.narrative.trim();
      if (body.isEmpty) return lead.headline;
      return '${lead.headline} — $body';
    }
    if (climate.uvIndex >= 8) {
      return '자외선 지수 매우 높음 — 장벽/진정 케어 집중 권장';
    }
    if (climate.uvIndex >= 6) {
      return '자외선 주의 — 진정·보습 케어 강화 권장';
    }
    if (climate.pm25UgM3 >= 76) {
      return '미세먼지 나쁨 — 클렌징·장벽 케어 주의';
    }
    if (climate.humidityPct < 35) {
      return '건조한 환경 — 보습·수분 케어 집중 권장';
    }
    return brief.headline;
  }

  static (int, int) _dayTempRange(double tempC, int hour) {
    final swing = hour >= 10 && hour <= 16 ? 9 : 12;
    final min = (tempC - swing * 0.55).round().clamp(-5, 40);
    var max = (tempC + swing * 0.45).round().clamp(0, 45);
    if (max <= min) max = min + 8;
    return (min, max);
  }

  static double _feelsLike(double tempC, int humidityPct) {
    var feels = tempC;
    if (tempC >= 24) {
      feels += (humidityPct - 45) * 0.06;
    } else if (tempC <= 10) {
      feels -= (50 - humidityPct) * 0.04;
    }
    return feels.clamp(tempC - 4, tempC + 6);
  }

  static String _weatherLabel({
    required double tempC,
    required int humidityPct,
    required int uvIndex,
    required int pm25,
    required int hour,
  }) {
    if (pm25 >= 76) return '미세먼지 나쁨';
    if (humidityPct >= 85) return '흐림';
    if (humidityPct >= 70 && uvIndex <= 3) return '구름 많음';
    if (hour >= 6 && hour <= 18 && uvIndex >= 5) return '맑음';
    if (hour >= 6 && hour <= 18) return '구름 조금';
    if (uvIndex <= 1) return '맑음';
    return '맑음';
  }

  static double _estimateWind(double tempC, int humidityPct, int hour) {
    final diurnal = hour >= 10 && hour <= 16 ? 1.4 : 0.6;
    final base = 1.6 + (tempC - 18).abs() * 0.06 + diurnal;
    final damp = humidityPct > 75 ? -0.3 : 0.0;
    return (base + damp).clamp(0.8, 6.5);
  }

  static IconData _iconFor(String weather, int hour, int uv) {
    if (weather.contains('미세')) return Icons.blur_on_rounded;
    if (weather.contains('흐림') || weather.contains('구름')) {
      return Icons.cloud_rounded;
    }
    if (hour < 6 || hour > 19) return Icons.nightlight_round;
    if (uv >= 6) return Icons.wb_sunny_rounded;
    return Icons.wb_cloudy_rounded;
  }

  static String bandStatus(SemanticBand band) => band.label;

  static double tempProgress(double tempC, double calmTargetC) {
    final delta = (tempC - calmTargetC).abs();
    return (1 - delta / 8).clamp(0.12, 1.0);
  }

  static double uvProgress(int uv) => (uv / 11).clamp(0.08, 1.0);

  static double humidityProgress(int pct) {
    final ideal = 50;
    final delta = (pct - ideal).abs();
    return (1 - delta / 50).clamp(0.1, 1.0);
  }

  static double pm25Progress(int ug) {
    if (ug <= 15) return 0.95;
    if (ug <= 35) return 0.72;
    if (ug <= 75) return 0.45;
    return 0.2;
  }
}
