import 'package:flutter/material.dart';

/// Calm Data Glass (CDG) — CRM 전용 GIS 서브시스템 (PO 확정 파라미터).
abstract final class CrmCalmGlassTokens {
  static const double glassOpacity = 0.08;
  static const double glassOpacityPressed = 0.12;
  static const double disabledOpacity = 0.45;

  static const Color care = Color(0xFFB8A9C9);
  static const Color careSoft = Color(0xFF2A2438);
  static const Color revenue = Color(0xFF9CAF88);
  static const Color alert = Color(0xFFE8A0A0);
  static const Color lead = Color(0xFF9BB5CE);

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
  }) {
    final base = tint ?? care;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: base.withValues(alpha: pressed ? glassOpacityPressed : glassOpacity),
      border: Border.all(
        color: base.withValues(alpha: 0.22),
        width: 0.5,
      ),
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
        color: care.withValues(alpha: 0.18),
        width: 0.5,
      ),
    );
  }
}
