import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';

/// SORI 브랜드 로고 — 보라 심볼 + 블랙 워드마크 원본 컬러.
///
/// 모바일(특히 WebKit)에서 `logo_sori.svg`의 임베디드 PNG `<image>`가
/// 파싱은 되지만 픽셀이 비어 그려지는 이슈가 있어, **래스터 PNG를 1차**로
/// 렌더링한다. SVG는 PNG 로드 실패 시에만 폴백한다.
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

  /// Intrinsic wordmark aspect (logo_sori.png = 448×220).
  static const double aspectRatio = 448 / 220;

  static String get assetPath => SoriBrandAssets.logoSoriPng;

  /// AppBar / GNB — compact mobile-friendly height.
  static const double gnbHeight = 26;

  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.55).clamp(160.0, 240.0);
  }

  static double loginWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // ~40% of viewport, clamped for phones / tablets.
    return (w * 0.40).clamp(140.0, 220.0);
  }

  static double splashWidthRaw(BuildContext context) => splashWidth(context);
  static double responsiveWidth(BuildContext context) => loginWidth(context);

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

    // Explicit box — prevents 0×0 collapse when SVG/image fails to report size.
    return IconTheme(
      data: const IconThemeData(),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Image.asset(
          SoriBrandAssets.logoSoriPng,
          width: size.width,
          height: size.height,
          fit: fit,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return SvgPicture.asset(
              SoriBrandAssets.logoSoriSvg,
              width: size.width,
              height: size.height,
              fit: fit,
              alignment: Alignment.centerLeft,
              allowDrawingOutsideViewBox: false,
            );
          },
        ),
      ),
    );
  }
}
