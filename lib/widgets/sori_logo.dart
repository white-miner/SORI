import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — SVG + Brightness 자동 전환.
class SoriLogo extends StatelessWidget {
  const SoriLogo({
    super.key,
    this.width,
    this.height = SoriBrandAssets.logoHeight,
    this.fit = BoxFit.contain,
    this.brightness,
    this.usePlatformBrightness = false,
  });

  /// 명시적 밝기. null이면 [usePlatformBrightness] 또는 Theme 사용.
  final Brightness? brightness;

  /// true면 OS 시스템 밝기(스플래시용). false면 Theme.brightness.
  final bool usePlatformBrightness;

  final double? width;
  final double height;
  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoWhite;

  Brightness _resolveBrightness(BuildContext context) {
    if (brightness != null) return brightness!;
    if (usePlatformBrightness) {
      return MediaQuery.platformBrightnessOf(context);
    }
    return Theme.of(context).brightness;
  }

  @override
  Widget build(BuildContext context) {
    final path = SoriBrandAssets.logoForBrightness(_resolveBrightness(context));
    return SizedBox(
      width: width,
      height: height,
      child: SvgPicture.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        placeholderBuilder: (_) => SizedBox(
          width: width ?? height,
          height: height,
          child: Center(
            child: SizedBox(
              width: height * 0.35,
              height: height * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SoriTokens.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
