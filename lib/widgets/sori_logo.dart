import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';

/// SORI 브랜드 로고 — `logo_sori.svg` 원본 컬러 그대로.
/// color / colorFilter 절대 주입 금지. 부모 IconTheme 영향 차단.
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

  @Deprecated('SVG renders original colors; brightness ignored')
  final Brightness? brightness;
  @Deprecated('SVG renders original colors; brightness ignored')
  final bool usePlatformBrightness;
  @Deprecated('SVG renders original colors; forceWhite ignored')
  final bool forceWhite;

  final double? width;
  final double? height;
  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoSoriSvg;
  static const double gnbHeight = 28;

  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.45).clamp(150.0, 200.0);
  }

  static double loginWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.40).clamp(140.0, 160.0);
  }

  static double splashWidthRaw(BuildContext context) => splashWidth(context);
  static double responsiveWidth(BuildContext context) => loginWidth(context);

  @override
  Widget build(BuildContext context) {
    final logoW = width;
    final logoH = height ?? (width == null ? gnbHeight : null);

    // IconTheme/AppBar tint가 SVG에 전파되지 않도록 격리
    return IconTheme(
      data: const IconThemeData(),
      child: SvgPicture.asset(
        SoriBrandAssets.logoSoriSvg,
        width: logoW,
        height: logoH,
        fit: fit,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: true,
        placeholderBuilder: (context) => SizedBox(
          width: logoW ?? (logoH != null ? logoH * 2.4 : 72),
          height: logoH ?? (logoW != null ? logoW * 0.42 : gnbHeight),
        ),
        errorBuilder: (context, error, stackTrace) {
          // SVG 파싱 실패 시에만 PNG 폴백 — ColorFilter 없음
          return Image.asset(
            SoriBrandAssets.logoSoriPng,
            width: logoW,
            height: logoH,
            fit: fit,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}
