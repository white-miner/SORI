import 'package:flutter/material.dart';

import '../models/skin_stress_index.dart';

/// PRD v4.4 — Zone C semantic tint (iOS system colors, widget interior only).
abstract final class SemanticBandTheme {
  static const widgetRadius = 22.0;

  static Color ssiArcColor(SsiBand band) => switch (band) {
        SsiBand.low => const Color(0xFF34C759),
        SsiBand.moderate => const Color(0xFFFF9500),
        SsiBand.high => const Color(0xFFFF6B4A),
        SsiBand.critical => const Color(0xFFFF3B30),
      };

  static List<Color> ssiAmbientGradient(SsiBand band) => switch (band) {
        SsiBand.low => [
            const Color(0xFFE8F4FD),
            Colors.white.withValues(alpha: 0.0),
          ],
        SsiBand.moderate => [
            const Color(0xFFFFF8E7),
            Colors.white.withValues(alpha: 0.0),
          ],
        SsiBand.high => [
            const Color(0xFFFFF0EB),
            Colors.white.withValues(alpha: 0.0),
          ],
        SsiBand.critical => [
            const Color(0xFFFFEBEA),
            Colors.white.withValues(alpha: 0.0),
          ],
      };

  static Color ssiBadgeBg(SsiBand band) =>
      ssiArcColor(band).withValues(alpha: 0.14);

  static Color ssiBadgeText(SsiBand band) => ssiArcColor(band);

  static Color surgeChipBg(int surgePct) {
    if (surgePct >= 30) {
      return const Color(0xFFFF9500).withValues(alpha: 0.15);
    }
    if (surgePct >= 15) {
      return const Color(0xFFFFD60A).withValues(alpha: 0.12);
    }
    return const Color(0xFFF2F2F7);
  }

  static Color surgeChipText(int surgePct) {
    if (surgePct >= 30) return const Color(0xFFCC7700);
    if (surgePct >= 15) return const Color(0xFF9A7B00);
    return const Color(0xFF18181B);
  }

  static Color sparklineColor(SsiBand? band, {int surgePct = 0}) {
    if (band != null) return ssiArcColor(band).withValues(alpha: 0.85);
    if (surgePct >= 30) return const Color(0xFFFF9500);
    if (surgePct >= 15) return const Color(0xFFFFD60A);
    return const Color(0xFFAEAEB2);
  }
}
