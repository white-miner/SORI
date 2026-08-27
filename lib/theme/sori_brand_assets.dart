import 'package:flutter/material.dart';

/// SORI 브랜드 로고 에셋 매니저.
/// 신규 브랜드 SVG(`logo_sori.svg`)는 Purple & Black 원본 컬러를 유지한다.
/// ColorFilter / color 틴트를 적용하지 말 것.
abstract final class SoriBrandAssets {
  /// 확정 브랜드 로고 (원본 컬러).
  static const String logoSori = 'assets/images/logo_sori.svg';

  /// @deprecated 레거시 PNG — [logoSori] 사용.
  static const String logoWhite = 'assets/images/logo_white.png';

  /// @deprecated 레거시 PNG — [logoSori] 사용.
  static const String logoBlack = 'assets/images/logo_black.png';

  /// @deprecated 레거시 PNG — [logoSori] 사용.
  static const String logoOutline = 'assets/images/logo_outline.png';

  /// GNB 표준 높이 (24~28px).
  static const double logoHeightGnb = 28;

  /// 인앱 기본 로고 높이.
  static const double logoHeight = 48;

  /// 스플래시 등 히어로 로고 높이 힌트.
  static const double logoHeightHero = 52;

  /// 항상 신규 브랜드 SVG.
  static String logoForBrightness(Brightness brightness) => logoSori;

  static String logoForTheme(BuildContext context) => logoSori;

  static String logoForPlatform(BuildContext context) => logoSori;

  static String get outline => logoSori;
}
