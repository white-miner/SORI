import 'package:flutter/material.dart';

/// SORI 브랜드 로고 반응형 에셋 매니저 (SVG).
/// 시스템/테마 [Brightness]에 따라 화이트·블랙 벡터 로고를 즉시 스위칭한다.
abstract final class SoriBrandAssets {
  static const String logoWhite = 'assets/images/logo_white.svg';
  static const String logoBlack = 'assets/images/logo_black.svg';
  static const String logoOutline = 'assets/images/logo_outline.svg';

  /// 인앱 기본 로고 높이 (비율 유지, BoxFit.contain).
  static const double logoHeight = 48;

  /// 스플래시 등 히어로 로고 높이.
  static const double logoHeightHero = 52;

  /// 어두운 배경 → 화이트 로고 / 밝은 배경 → 블랙 로고.
  static String logoForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? logoWhite : logoBlack;
  }

  /// [ThemeData.brightness] 기준 (앱 테마).
  static String logoForTheme(BuildContext context) {
    return logoForBrightness(Theme.of(context).brightness);
  }

  /// OS 시스템 밝기 기준 (스플래시 등 테마 강제와 무관할 때).
  static String logoForPlatform(BuildContext context) {
    return logoForBrightness(MediaQuery.platformBrightnessOf(context));
  }

  /// 아웃라인 변형 — 배경 대비가 애매할 때.
  static String get outline => logoOutline;
}
