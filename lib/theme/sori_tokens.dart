import 'dart:ui';

import 'package:flutter/material.dart';

/// SORI — iOS-style White Minimal + System Accent (Red alerts, Camera Yellow).
abstract final class SoriTokens {
  /// App canvas — soft off-white
  static const Color background = Color(0xFFF8F9FA);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color surfaceOverlay = Color(0xFFF0F0F0);

  /// CTA, active tab, loading — deep charcoal / pure black
  static const Color primary = Color(0xFF18181B);

  static const Color primaryDark = Color(0xFF000000);

  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryLight = Color(0xFF27272A);

  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  static const Color accent = primary;

  static const Color indigo = primary;

  static const Color premium = primaryLight;

  static const Color premiumSoft = Color(0x1A18181B);

  /// iOS System Red — notification badges, warnings, delete ONLY.
  static const Color systemRed = Color(0xFFFF3B30);

  static const Color systemRedAlt = SoriTokens.systemRed;

  static const Color destructive = systemRed;

  /// Apple Camera Yellow — viewfinder alignment & preset dock ONLY.
  static const Color cameraYellow = Color(0xFFFFD60A);

  static const Color cameraYellowAlt = Color(0xFFFFCC00);

  /// Face ghost silhouette overlay (use with opacity ~10%).
  static const Color ghostImage = Color(0xFFFFFFFF);

  /// Viewfinder proximity feedback — cold / warm / locked.
  static const Color alignCold = Color(0xFF8E9AAF);
  static const Color alignWarm = Color(0xFFFF9F0A);
  /// Apple System-like emerald — decollete / face lock glow.
  static const Color alignEmerald = Color(0xFF00D289);

  /// Inactive camera preset icon
  static const Color inactiveGray = Color(0xFF71717A);

  static const Color outlinePurple = Color(0x14000000);

  static const Color outline = outlinePurple;

  static const Color border = Color(0x14000000);

  /// Form field outline — light gray (white mode).
  static const Color inputBorder = Color(0xFFE5E5EA);

  /// Idle chip / unselected control fill.
  static const Color chipIdleBg = Color(0xFFF1F1F1);

  /// Deep charcoal — default body text on white backgrounds
  static const Color textCharcoal = Color(0xFF111111);

  static const Color textPrimary = textCharcoal;

  static const Color textSecondary = Color(0xB3111111);

  static const Color textTertiary = Color(0x73111111);

  static const Color textQuaternary = Color(0x4D111111);

  /// Tab bar — unselected label on white canvas
  static const Color tabUnselected = Color(0xFF71717A);

  /// YouTube-style selected tab capsule background
  static const Color tabCapsuleBg = Color(0xFFF1F1F1);

  static const Color success = primary;

  static const Color warningBg = Color(0xFFF5F5F5);

  static const Color warningText = Color(0xFF52525B);

  /// Glass overlays — white @ 80%
  static const Color glassFill = Color(0xCCFFFFFF);

  static const Color primaryGlass = glassFill;

  static const Color primarySoft = Color(0x1418181B);

  static const double glassBlurSigma = 10;

  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusMd = 14;
  static const double outlineWidth = 1;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
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

  static BoxDecoration glassEmerald({
    double radius = radiusMd,
    bool border = true,
  }) =>
      glassSurface(radius: radius, showBorder: border);

  static ImageFilter get glassBlurFilter =>
      ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma);
}
