import 'package:flutter/material.dart';

/// SORI brand logo assets — vector SVG SSOT.
abstract final class SoriBrandAssets {
  static const String logoSoriSvg = 'assets/images/logo_sori.svg';

  static const double logoHeightGnb = 34;
  static const double logoHeight = 48;
  static const double logoHeightHero = 52;

  static String logoForBrightness(Brightness brightness) => logoSoriSvg;
  static String logoForTheme(BuildContext context) => logoSoriSvg;
  static String logoForPlatform(BuildContext context) => logoSoriSvg;
  static String get outline => logoSoriSvg;
}
