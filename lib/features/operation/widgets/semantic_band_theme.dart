import 'package:flutter/material.dart';

import '../models/skin_stress_index.dart';
import 'semantic_signal_theme.dart';

/// PRD v4.4 → v4.6 bridge — delegates to [SemanticSignalTheme].
abstract final class SemanticBandTheme {
  static const widgetRadius = SemanticSignalTheme.widgetRadius;

  static Color ssiArcColor(SsiBand band) =>
      SemanticSignalTheme.bandColor(
        SemanticSignalTheme.bandForSsiBand(band),
      );

  static List<Color> ssiAmbientGradient(SsiBand band) =>
      SemanticSignalTheme.ambientGradient(
        SemanticSignalTheme.bandForSsiBand(band),
      );

  static Color ssiBadgeBg(SsiBand band) =>
      SemanticSignalTheme.badgeBg(SemanticSignalTheme.bandForSsiBand(band));

  static Color ssiBadgeText(SsiBand band) =>
      SemanticSignalTheme.badgeText(SemanticSignalTheme.bandForSsiBand(band));

  static Color surgeChipBg(int surgePct) =>
      SemanticSignalTheme.surgeChipBg(surgePct);

  static Color surgeChipText(int surgePct) =>
      SemanticSignalTheme.surgeChipText(surgePct);

  static Color sparklineColor(SsiBand? band, {int surgePct = 0}) {
    if (band != null) {
      return SemanticSignalTheme.sparklineColor(
        band: SemanticSignalTheme.bandForSsiBand(band),
      );
    }
    return SemanticSignalTheme.sparklineColor(surgePct: surgePct);
  }
}
