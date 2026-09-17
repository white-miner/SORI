import 'package:flutter/material.dart';

import '../models/skin_stress_index.dart';

/// PRD v4.6 — 4-Band semantic signal (Green / Yellow / Orange / Red).
enum SemanticBand {
  green,
  yellow,
  orange,
  red;

  String get label => switch (this) {
        SemanticBand.green => '양호',
        SemanticBand.yellow => '보통',
        SemanticBand.orange => '주의',
        SemanticBand.red => '위험',
      };
}

/// PRD v4.6 — iOS Material tier for widget surfaces.
enum WidgetMaterialTier {
  thin,
  regular,
  thick;

  double get blurSigma => switch (this) {
        WidgetMaterialTier.thin => 16,
        WidgetMaterialTier.regular => 24,
        WidgetMaterialTier.thick => 30,
      };

  double get fillAlpha => switch (this) {
        WidgetMaterialTier.thin => 0.42,
        WidgetMaterialTier.regular => 0.38,
        WidgetMaterialTier.thick => 0.32,
      };

  double get ambientAlpha => switch (this) {
        WidgetMaterialTier.thin => 0.28,
        WidgetMaterialTier.regular => 0.42,
        WidgetMaterialTier.thick => 0.58,
      };

  double get tintAlpha => switch (this) {
        WidgetMaterialTier.thin => 0.08,
        WidgetMaterialTier.regular => 0.14,
        WidgetMaterialTier.thick => 0.22,
      };
}

/// PRD v4.6 — SSOT for semantic colors, thresholds, and material tokens.
abstract final class SemanticSignalTheme {
  static const widgetRadius = 24.0;
  static const heroTextColor = Color(0xFF1C1C1E);
  static const secondaryTextColor = Color(0xFF8E8E93);

  // iOS Vibrant system colors
  static const green = Color(0xFF34C759);
  static const yellow = Color(0xFFFFCC00);
  static const yellowText = Color(0xFF9A7B00);
  static const orange = Color(0xFFFF9500);
  static const orangeText = Color(0xFFCC7700);
  static const red = Color(0xFFFF3B30);

  static Color bandColor(SemanticBand band) => switch (band) {
        SemanticBand.green => green,
        SemanticBand.yellow => const Color(0xFFFFCC00),
        SemanticBand.orange => orange,
        SemanticBand.red => red,
      };

  static Color bandTextColor(SemanticBand band) => switch (band) {
        SemanticBand.green => const Color(0xFF248A3D),
        SemanticBand.yellow => yellowText,
        SemanticBand.orange => orangeText,
        SemanticBand.red => red,
      };

  static List<Color> ambientGradient(SemanticBand band) => switch (band) {
        SemanticBand.green => [
            const Color(0xFF7FD99A),
            const Color(0xFFB8E8F5),
            const Color(0xFFE8F8EE),
          ],
        SemanticBand.yellow => [
            const Color(0xFFFFE066),
            const Color(0xFFFFF0A8),
            const Color(0xFFFFFBE6),
          ],
        SemanticBand.orange => [
            const Color(0xFFFFB347),
            const Color(0xFFFFD4A8),
            const Color(0xFFFFF0E0),
          ],
        SemanticBand.red => [
            const Color(0xFFFF6B6B),
            const Color(0xFFFFB4B0),
            const Color(0xFFFFECEC),
          ],
      };

  static Color badgeBg(SemanticBand band) =>
      bandColor(band).withValues(alpha: 0.16);

  static Color badgeText(SemanticBand band) => bandTextColor(band);

  static Color shellTint(SemanticBand band) =>
      bandColor(band).withValues(alpha: 0.40);

  static Color shellShadow(SemanticBand band) =>
      bandColor(band).withValues(alpha: 0.14);

  // --- SSI ---

  static SemanticBand bandForSsi(int score) {
    if (score >= 80) return SemanticBand.red;
    if (score >= 60) return SemanticBand.orange;
    if (score >= 30) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  static SemanticBand bandForSsiBand(SsiBand band) => switch (band) {
        SsiBand.low => SemanticBand.green,
        SsiBand.moderate => SemanticBand.yellow,
        SsiBand.high => SemanticBand.orange,
        SsiBand.critical => SemanticBand.red,
      };

  // --- Sub-metrics ---

  static SemanticBand bandForUv(int uvIndex) {
    if (uvIndex >= 8) return SemanticBand.red;
    if (uvIndex >= 6) return SemanticBand.orange;
    if (uvIndex >= 3) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  static SemanticBand bandForPm25(int ugM3) {
    if (ugM3 >= 76) return SemanticBand.red;
    if (ugM3 >= 36) return SemanticBand.orange;
    if (ugM3 >= 16) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  static SemanticBand bandForTempComfort(double tempC, double calmTargetC) {
    final delta = (tempC - calmTargetC).abs();
    if (delta > 6) return SemanticBand.red;
    if (delta > 4) return SemanticBand.orange;
    if (delta > 2) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  static SemanticBand bandForHumidity(int pct) {
    if (pct < 25 || pct > 85) return SemanticBand.red;
    if (pct < 35 || pct > 75) return SemanticBand.orange;
    if (pct < 45 || pct > 65) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  // --- CTI surge ---

  static SemanticBand bandForSurge(int surgePct) {
    if (surgePct >= 40) return SemanticBand.red;
    if (surgePct >= 30) return SemanticBand.orange;
    if (surgePct >= 15) return SemanticBand.yellow;
    return SemanticBand.green;
  }

  static Color surgeChipBg(int surgePct) {
    final band = bandForSurge(surgePct);
    if (band == SemanticBand.green) {
      return const Color(0xFFF4F6F9);
    }
    return badgeBg(band);
  }

  static Color surgeChipText(int surgePct) {
    final band = bandForSurge(surgePct);
    return bandColor(band);
  }

  static Color sparklineColor({SemanticBand? band, int surgePct = 0}) {
    final resolved = band ?? bandForSurge(surgePct);
    if (resolved == SemanticBand.green && surgePct < 15) {
      return const Color(0xFFAEAEB2);
    }
    return bandColor(resolved).withValues(alpha: 0.92);
  }

  /// PO v4.6 §8 — headline tint follows the driving metric alert.
  static SemanticBand headlineBand({
    required String headline,
    required List<String> alertKeys,
    required int ssiScore,
    double? tempC,
    double? calmTargetC,
    int? uvIndex,
    int? pm25UgM3,
    int? humidityPct,
  }) {
    if (alertKeys.isNotEmpty) {
      return switch (alertKeys.first) {
        'uv_extreme' || 'uv_high' =>
          bandForUv(uvIndex ?? 6),
        'pm25_bad' || 'pm25_mod' =>
          bandForPm25(pm25UgM3 ?? 36),
        'heat_wave' || 'high_temp' || 'heat_uv_combo' =>
          tempC != null && calmTargetC != null
              ? bandForTempComfort(tempC, calmTargetC)
              : SemanticBand.orange,
        'dry_air' =>
          bandForHumidity(humidityPct ?? 35),
        _ => bandForSsi(ssiScore),
      };
    }
    final h = headline.toLowerCase();
    if (h.contains('자외선') || h.contains('uv')) {
      return SemanticBand.orange;
    }
    if (h.contains('미세') || h.contains('pm')) {
      return SemanticBand.orange;
    }
    if (h.contains('폭염') || h.contains('고온') || h.contains('열')) {
      return SemanticBand.orange;
    }
    if (h.contains('건조') || h.contains('습도')) {
      return SemanticBand.yellow;
    }
    return bandForSsi(ssiScore);
  }
}
