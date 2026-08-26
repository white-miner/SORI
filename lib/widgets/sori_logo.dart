import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — SVG + Brightness 자동 전환.
/// 기본은 [width] 기준 스케일 (높이 강제 축소 금지).
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

  /// 가로 기준 스케일. 미지정 시 화면 폭의 45%(PC는 260).
  final double? width;

  /// 선택적 높이. 지정하지 않으면 비율만 유지하며 width에 맞춤.
  final double? height;

  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoWhite;

  /// 모바일: 화면 폭 × 0.45 / PC: 260.
  static double responsiveWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 260;
    return w * 0.45;
  }

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
    final logoW = width ?? responsiveWidth(context);
    return SizedBox(
      width: logoW,
      height: height,
      child: SvgPicture.asset(
        path,
        width: logoW,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        placeholderBuilder: (_) => SizedBox(
          width: logoW,
          height: height ?? logoW * 0.55,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
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
