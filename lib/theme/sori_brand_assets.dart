import 'package:flutter/material.dart';

/// SORI brand logo assets — SVG primary, PNG web fallback.
abstract final class SoriBrandAssets {
  /// Primary brand logo (Purple & Black, original SVG colors).
  static const String logoSoriSvg = 'assets/images/logo_sori.svg';

  /// PNG extracted from SVG — used only when flutter_svg fails on web.
  static const String logoSoriPng = 'assets/images/logo_sori.png';

  static const double logoHeightGnb = 28;
  static const double logoHeight = 48;
  static const double logoHeightHero = 52;

  static String logoForBrightness(Brightness brightness) => logoSoriSvg;
  static String logoForTheme(BuildContext context) => logoSoriSvg;
  static String logoForPlatform(BuildContext context) => logoSoriSvg;
  static String get outline => logoSoriSvg;
}
