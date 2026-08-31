import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// Calm Data Glass — achromatic only (Sprint 3.2 lavender sterilized).
abstract final class VisitGlassTokens {
  static const double glassOpacity = 0.08;
  static const double glassOpacityPressed = 0.12;
  static const double edgeGlowMin = 0.08;
  static const double edgeGlowMax = 0.12;

  /// Semantic ink — charcoal (not purple).
  static const Color care = Color(0xFF18181B);
  static const Color careSoft = Color(0xFF3A3A3C);
  static const Color sage = Color(0xFF71717A);
  static const Color alert = Color(0xFFFF3B30);

  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const Duration calmMotion = Duration(milliseconds: 280);
  static const Curve calmCurve = Curves.easeOutCubic;

  static TextStyle displayKpi(BuildContext context) {
    return const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
      height: 1.1,
      color: SoriTokens.textPrimary,
    );
  }

  static TextStyle bodyCalm = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: SoriTokens.textPrimary,
  );

  static TextStyle captionCalm = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: SoriTokens.textSecondary,
  );

  static BoxDecoration cardDecoration({
    Color? tint,
    double radius = radiusLg,
    bool pressed = false,
    bool socialGlow = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: SoriTokens.glassFill.withValues(
        alpha: pressed ? 0.92 : 0.82,
      ),
      border: Border.all(
        color: Colors.black.withValues(
          alpha: socialGlow ? edgeGlowMax : edgeGlowMin,
        ),
        width: 0.5,
      ),
      boxShadow: socialGlow ? SoriTokens.cardShadow : null,
    );
  }

  static BoxDecoration heroDecoration({double radius = radiusXl}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: SoriTokens.background,
      border: Border.all(
        color: Colors.black.withValues(alpha: edgeGlowMin),
        width: 0.5,
      ),
    );
  }
}
