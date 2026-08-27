import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — `logo_sori.svg` 원본 컬러 그대로 렌더링.
/// [color] / [ColorFilter] 를 절대 주입하지 않는다.
class SoriLogo extends StatelessWidget {
  const SoriLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.brightness,
    this.usePlatformBrightness = false,
    this.forceWhite = false,
  });

  /// @deprecated 무시됨 — SVG 원본 컬러 고정.
  final Brightness? brightness;

  /// @deprecated 무시됨 — SVG 원본 컬러 고정.
  final bool usePlatformBrightness;

  /// @deprecated 무시됨 — 화이트 틴트 금지.
  final bool forceWhite;

  /// 가로 기준 스케일.
  final double? width;

  /// 높이 기준 스케일 (GNB 24~28px).
  final double? height;

  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoSori;

  /// GNB / 셸 헤더 표준 높이.
  static const double gnbHeight = 28;

  /// 스플래시: 화면 너비의 ~45% (150~200px).
  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.45).clamp(150.0, 200.0);
  }

  /// 로그인: 스플래시와 유사, 약 150px.
  static double loginWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.40).clamp(140.0, 160.0);
  }

  /// @deprecated [splashWidth] 사용.
  static double splashWidthRaw(BuildContext context) => splashWidth(context);

  /// 인앱 기본 반응형 (로그인 등).
  static double responsiveWidth(BuildContext context) => loginWidth(context);

  @override
  Widget build(BuildContext context) {
    final logoW = width;
    final logoH = height ?? (width == null ? gnbHeight : null);

    return SvgPicture.asset(
      SoriBrandAssets.logoSori,
      width: logoW,
      height: logoH,
      fit: fit,
      alignment: Alignment.center,
      // 원본 Purple & Black 유지 — color / colorFilter 금지
      placeholderBuilder: (context) => SizedBox(
        width: logoW ?? (logoH != null ? logoH * 2.4 : 72),
        height: logoH ?? (logoW != null ? logoW * 0.42 : gnbHeight),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 18,
            color: SoriTokens.primary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
