import 'package:flutter/material.dart';

/// SORI dark-mode design tokens — Weverse-inspired black canvas + purple outline.
abstract final class SoriTokens {
  /// Deep dark scaffold
  static const Color background = Color(0xFF0A0A0C);

  /// Module / card surface
  static const Color surface = Color(0xFF18181B);

  /// Elevated surface (sheets, pills)
  static const Color surfaceElevated = Color(0xFF121214);

  /// Signature purple (CTA / selected)
  static const Color primary = Color(0xFF7C3AED);

  /// Soft purple wash on dark
  static const Color primarySoft = Color(0x337C3AED);

  static const Color indigo = Color(0xFF8B5CF6);

  /// Outline purple (~35% alpha)
  static const Color outlinePurple = Color(0x598B5CF6);

  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);

  static const Color border = Color(0xFF27272A);
  static const Color success = Color(0xFF03C75A);
  static const Color warningBg = Color(0xFF2A2118);
  static const Color warningText = Color(0xFFFBBF24);

  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusMd = 14;
  static const double outlineWidth = 1.2;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static Border get signatureBorder => Border.all(
        color: outlinePurple,
        width: outlineWidth,
      );

  static BoxDecoration card({
    Color color = surface,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: signatureBorder,
      boxShadow: cardShadow,
    );
  }
}
