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
  /// AppBar / GNB wordmark height (purple mark + black SORI).
  static const double gnbHeight = 32;

  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.52).clamp(180.0, 240.0);
  }

  static double loginWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.48).clamp(168.0, 220.0);
  }

  static double splashWidthRaw(BuildContext context) => splashWidth(context);
  static double responsiveWidth(BuildContext context) => loginWidth(context);

  @override
  Widget build(BuildContext context) {
    final logoW = width;
    final logoH = height ?? (width == null ? gnbHeight : null);

    // IconTheme/AppBar tint가 SVG에 전파되지 않도록 격리.
    // 원본 컬러(Purple mark + Black SORI) — ColorFilter 절대 금지.
    return IconTheme(
      data: const IconThemeData(),
      child: SvgPicture.asset(
        SoriBrandAssets.logoSoriSvg,
        width: logoW,
        height: logoH,
        fit: fit,
        alignment: Alignment.centerLeft,
        allowDrawingOutsideViewBox: false,
        placeholderBuilder: (context) => Image.asset(
          SoriBrandAssets.logoSoriPng,
          width: logoW,
          height: logoH,
          fit: fit,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            SoriBrandAssets.logoSoriPng,
            width: logoW,
            height: logoH,
            fit: fit,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}
