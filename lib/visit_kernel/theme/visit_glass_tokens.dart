import 'package:flutter/material.dart';

/// Calm Data Glass + Social Glass — Visit OS (PO v3.0 확정).
abstract final class VisitGlassTokens {
  static const double glassOpacity = 0.08;
  static const double glassOpacityPressed = 0.12;
  static const double edgeGlowMin = 0.15;
  static const double edgeGlowMax = 0.20;

  static const Color care = Color(0xFFB8A9C9);
  static const Color careSoft = Color(0xFF2A2438);
  static const Color sage = Color(0xFF9CAF88);
  static const Color alert = Color(0xFFE8A0A0);

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
    );
  }

  static TextStyle bodyCalm = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle captionCalm = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static BoxDecoration cardDecoration({
    Color? tint,
    double radius = radiusLg,
    bool pressed = false,
    bool socialGlow = false,
  }) {
    final base = tint ?? care;
    final glowAlpha = (edgeGlowMin + edgeGlowMax) / 2;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: base.withValues(alpha: pressed ? glassOpacityPressed : glassOpacity),
      border: Border.all(
        color: socialGlow
            ? base.withValues(alpha: glowAlpha)
            : base.withValues(alpha: 0.22),
        width: socialGlow ? 1.0 : 0.5,
      ),
      boxShadow: socialGlow
          ? [
              BoxShadow(
                color: base.withValues(alpha: glowAlpha * 0.6),
                blurRadius: 18,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  static BoxDecoration heroDecoration({double radius = radiusXl}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          care.withValues(alpha: 0.14),
          careSoft.withValues(alpha: 0.35),
        ],
      ),
      border: Border.all(
        color: care.withValues(alpha: edgeGlowMin),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: care.withValues(alpha: edgeGlowMin * 0.5),
          blurRadius: 24,
        ),
      ],
    );
  }
}
