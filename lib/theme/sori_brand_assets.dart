import 'package:flutter/material.dart';

/// SORI 브랜드 로고 에셋 매니저.
/// 투명 PNG — 다크 배경은 화이트, 라이트 배경은 블랙.
abstract final class SoriBrandAssets {
  static const String logoWhite = 'assets/images/logo_white.png';
  static const String logoBlack = 'assets/images/logo_black.png';
  static const String logoOutline = 'assets/images/logo_outline.png';

  /// GNB 표준 높이 (26~30px 규격).
  static const double logoHeightGnb = 28;

  /// 인앱 기본 로고 높이.
  static const double logoHeight = 48;

  /// 스플래시 등 히어로 로고 높이 힌트.
  static const double logoHeightHero = 52;

  /// 어두운 배경 → 화이트 로고 / 밝은 배경 → 블랙 로고.
  static String logoForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? logoWhite : logoBlack;
  }

  /// [ThemeData.brightness] 기준 (앱 테마).
  static String logoForTheme(BuildContext context) {
    return logoForBrightness(Theme.of(context).brightness);
  }

  /// OS 시스템 밝기 기준.
  static String logoForPlatform(BuildContext context) {
    return logoForBrightness(MediaQuery.platformBrightnessOf(context));
  }

  /// 아웃라인 변형 — 다크 표면용 화이트와 동일.
  static String get outline => logoOutline;
}
