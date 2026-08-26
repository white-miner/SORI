import 'dart:ui';

import 'package:flutter/material.dart';

/// SORI design tokens — YouTube/Instagram-style monochrome + glass.
/// No chromatic accent colors (mint, emerald, purple, blue, etc.).
abstract final class SoriTokens {
  /// App canvas — warm off-white
  static const Color background = Color(0xFFFAFAFA);

  /// Cards, list rows, modals (opaque surface)
  static const Color surface = Color(0xFFFFFFFF);

  /// Raised panels
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Press / inactive chip fill
  static const Color surfaceOverlay = Color(0xFFF0F0F0);

  /// CTA, active tab, loading indicator — charcoal black
  static const Color primary = Color(0xFF111111);

  static const Color primaryDark = Color(0xFF000000);

  /// Destructive / error emphasis — charcoal (no red).
  static const Color destructive = Color(0xFF111111);

  /// Glass fill — white @ ~75% (floating overlays)
  static const Color primaryGlass = Color(0xCCFFFFFF);

  /// Soft wash (~10% charcoal)
  static const Color primarySoft = Color(0x1A111111);

  /// Label on charcoal fills
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Secondary emphasis — dark gray
  static const Color primaryLight = Color(0xFF333333);

  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  static const Color accent = primary;

  /// Legacy alias — monochrome only
  static const Color indigo = primary;

  /// Tier / VIP emphasis — charcoal (no purple)
  static const Color premium = Color(0xFF333333);

  static const Color premiumSoft = Color(0x1A111111);

  static const Color outlinePurple = Color(0x14000000);

  static const Color outline = outlinePurple;

  static const Color textPrimary = Color(0xFF111111);

  static const Color textSecondary = Color(0xB3111111);

  static const Color textTertiary = Color(0x73111111);

  static const Color textQuaternary = Color(0x4D111111);

  static const Color border = Color(0x14000000);

  static const Color success = primary;

  static const Color warningBg = Color(0xFFF5F5F5);

  static const Color warningText = Color(0xFF555555);

  /// Floating glass layers
  static const Color glassFill = Color(0xCCFFFFFF);

  static const double glassBlurSigma = 10;

  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusMd = 14;
  static const double outlineWidth = 1;

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static Border get signatureBorder => Border.all(
        color: border,
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

  /// Glassmorphism surface — semi-transparent white + optional hairline.
  static BoxDecoration glassSurface({
    double radius = radiusMd,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: showBorder
          ? Border.all(color: SoriTokens.border, width: outlineWidth)
          : null,
    );
  }

  /// Legacy alias
  static BoxDecoration glassEmerald({
    double radius = radiusMd,
    bool border = true,
  }) =>
      glassSurface(radius: radius, showBorder: border);

  static ImageFilter get glassBlurFilter =>
      ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma);
}
