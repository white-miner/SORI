import 'package:flutter/material.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — 원본 Purple & Black PNG. ColorFilter 금지.
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

  @deprecated
  final Brightness? brightness;
  @deprecated
  final bool usePlatformBrightness;
  @deprecated
  final bool forceWhite;

  final double? width;
  final double? height;
  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoSori;
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

    return Image.asset(
      SoriBrandAssets.logoSori,
      width: logoW,
      height: logoH,
      fit: fit,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(
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
