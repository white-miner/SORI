import 'package:flutter/material.dart';

/// SORI 브랜드 로고 에셋.
/// Web 호환: `logo_sori.png`(SVG 임베디드 래스터 추출본)를 기본 사용.
abstract final class SoriBrandAssets {
  /// Web-safe brand logo (Purple & Black, original colors).
  static const String logoSori = 'assets/images/logo_sori.png';

  /// Source SVG — flutter_svg 미지원 필터/래스터 포함.
  static const String logoSoriSvg = 'assets/images/logo_sori.svg';

  static const double logoHeightGnb = 28;
  static const double logoHeight = 48;
  static const double logoHeightHero = 52;

  static String logoForBrightness(Brightness brightness) => logoSori;
  static String logoForTheme(BuildContext context) => logoSori;
  static String logoForPlatform(BuildContext context) => logoSori;
  static String get outline => logoSori;
}
