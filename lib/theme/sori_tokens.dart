import 'package:flutter/material.dart';

/// SORI App-like design tokens (Intopet-inspired card UI).
abstract final class SoriTokens {
  static const Color primary = Color(0xFF5B4CDB);
  static const Color primarySoft = Color(0xFFEEECFB);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF03C75A);
  static const Color warningBg = Color(0xFFFFF4E5);
  static const Color warningText = Color(0xFFB7791F);

  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusMd = 14;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static BoxDecoration card({
    Color color = surface,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: cardShadow,
    );
  }
}
