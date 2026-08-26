import 'package:flutter/material.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — 테마 Brightness에 따라 화이트/블랙 에셋 자동 전환.
class SoriLogo extends StatelessWidget {
  const SoriLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.brightness,
    this.usePlatformBrightness = false,
  });

  /// 명시적 밝기. null이면 [usePlatformBrightness] 또는 Theme 사용.
  final Brightness? brightness;

  /// true면 OS 시스템 밝기(스플래시용). false면 Theme.brightness.
  final bool usePlatformBrightness;

  final double? width;
  final double? height;
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
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width ?? height ?? 48,
          height: height ?? width ?? 48,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
