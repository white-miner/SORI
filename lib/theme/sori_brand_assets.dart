import 'package:flutter/material.dart';

/// SORI brand logo assets — PNG primary (mobile-safe), SVG fallback.
abstract final class SoriBrandAssets {
  /// Raster wordmark (Purple mark + Black SORI). Preferred on all platforms.
  static const String logoSoriPng = 'assets/images/logo_sori.png';

  /// SVG wrapper (embedded raster). Mobile WebKit may paint empty — use PNG.
  static const String logoSoriSvg = 'assets/images/logo_sori.svg';

  static const double logoHeightGnb = 26;
  static const double logoHeight = 48;
  static const double logoHeightHero = 52;

  static String logoForBrightness(Brightness brightness) => logoSoriPng;
  static String logoForTheme(BuildContext context) => logoSoriPng;
  static String logoForPlatform(BuildContext context) => logoSoriPng;
  static String get outline => logoSoriPng;
}
