import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';

/// SORI 브랜드 로고 — 보라 심볼 + 블랙 워드마크 (벡터 SVG 원본 컬러).
/// ColorFilter / 부모 IconTheme tint 절대 금지.
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

  @Deprecated('Original colors only; brightness ignored')
  final Brightness? brightness;
  @Deprecated('Original colors only; usePlatformBrightness ignored')
  final bool usePlatformBrightness;
  @Deprecated('Original colors only; forceWhite ignored')
  final bool forceWhite;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// Intrinsic wordmark aspect (logo_sori.svg viewBox 2500×938).
  static const double aspectRatio = 2500 / 938;

  static String get assetPath => SoriBrandAssets.logoSoriSvg;

  /// AppBar / GNB — mobile-friendly height (32–36px band).
  static const double gnbHeight = 34;

  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.55).clamp(160.0, 280.0);
  }

  static double loginWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.55).clamp(160.0, 280.0);
  }

  static double splashWidthRaw(BuildContext context) => splashWidth(context);
  static double responsiveWidth(BuildContext context) => loginWidth(context);

  /// Warm SVG cache before first paint (splash / login).
  static Future<void> precache(BuildContext context) async {
    final loader = SvgAssetLoader(SoriBrandAssets.logoSoriSvg);
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  }

  Size _resolveSize() {
    if (width != null && height != null) {
      return Size(width!, height!);
    }
    if (width != null) {
      return Size(width!, width! / aspectRatio);
    }
    if (height != null) {
      return Size(height! * aspectRatio, height!);
    }
    return const Size(gnbHeight * aspectRatio, gnbHeight);
  }

  @override
  Widget build(BuildContext context) {
    final size = _resolveSize();

    return IconTheme(
      data: const IconThemeData(),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: SvgPicture.asset(
          SoriBrandAssets.logoSoriSvg,
          width: size.width,
          height: size.height,
          fit: fit,
          alignment: Alignment.centerLeft,
          allowDrawingOutsideViewBox: false,
        ),
      ),
    );
  }
}
