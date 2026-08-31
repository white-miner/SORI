import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';

/// PRD v4.7 — Soft UI & Volume Glassmorphism SSOT.
abstract final class VolumeGlassTheme {
  /// PO §9 — global canvas off-white.
  static const canvasBg = Color(0xFFF4F6F9);

  /// Pure white glass card fill.
  static const cardFill = Color(0xFFFFFFFF);

  static const cardFillAlpha = 0.92;

  static const cardRadius = 24.0;

  static const cardPadding = EdgeInsets.all(20);

  static const compactPadding = EdgeInsets.all(16);

  /// PO §9 Hybrid — care/timer primary actions.
  static const vibrantCareGreen = Color(0xFF34C759);

  static const onVibrantCare = Color(0xFFFFFFFF);

  /// KPI hero numbers (32–40px).
  static const kpiFontSize = 36.0;

  static const kpiFontSizeCompact = 32.0;

  static const kpiFontSizeHero = 40.0;

  /// Secondary labels (12–14px grey).
  static const labelFontSize = 13.0;

  static const labelFontSizeCompact = 12.0;

  static Color cardFillColor({double alpha = cardFillAlpha}) =>
      cardFill.withValues(alpha: alpha);

  /// Shadow-only depth — blur 20–30, alpha 0.04–0.08, offset (0, 8).
  static List<BoxShadow> volumeShadow({Color? tint, double alpha = 0.05}) {
    final base = tint ?? Colors.black;
    return [
      BoxShadow(
        color: base.withValues(alpha: alpha.clamp(0.04, 0.08)),
        blurRadius: 26,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  static BoxDecoration cardDecoration({
    Color? fill,
    List<BoxShadow>? shadows,
    double radius = cardRadius,
    List<Color>? ambientGradient,
    double ambientAlpha = 0.12,
  }) {
    return BoxDecoration(
      color: fill ?? cardFillColor(),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadows ?? volumeShadow(),
      gradient: ambientGradient != null && ambientGradient.length >= 2
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ambientGradient
                  .map((c) => c.withValues(alpha: ambientAlpha))
                  .toList(),
            )
          : null,
    );
  }

  static TextStyle kpiTextStyle({
    double? fontSize,
    bool compact = false,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize ??
          (compact ? kpiFontSizeCompact : kpiFontSize),
      fontWeight: FontWeight.w800,
      height: 1.0,
      color: color ?? SemanticSignalTheme.heroTextColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle labelTextStyle({bool compact = false, Color? color}) {
    return TextStyle(
      fontSize: compact ? labelFontSizeCompact : labelFontSize,
      fontWeight: FontWeight.w600,
      color: color ?? SemanticSignalTheme.secondaryTextColor,
    );
  }

  static ButtonStyle carePrimaryButtonStyle({bool enabled = true}) {
    return FilledButton.styleFrom(
      backgroundColor: enabled ? vibrantCareGreen : vibrantCareGreen.withValues(alpha: 0.4),
      foregroundColor: onVibrantCare,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius * 0.58),
      ),
      elevation: 0,
      shadowColor: vibrantCareGreen.withValues(alpha: 0.25),
    );
  }
}
