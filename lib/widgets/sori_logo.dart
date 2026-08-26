import 'package:flutter/material.dart';

import '../theme/sori_brand_assets.dart';
import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 — PNG + Brightness 자동 전환.
/// 스플래시/GNB는 [width] 또는 [height] 기준 스케일 (BoxFit.contain).
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

  /// 명시적 밝기. null이면 [usePlatformBrightness] 또는 Theme 사용.
  final Brightness? brightness;

  /// true면 OS 시스템 밝기. false면 Theme.brightness.
  final bool usePlatformBrightness;

  /// true면 테마와 무관하게 [logo_white] 고정 (다크 럭셔리 스플래시).
  final bool forceWhite;

  /// 가로 기준 스케일.
  final double? width;

  /// 높이 기준 스케일 (GNB 26~30px).
  final double? height;

  final BoxFit fit;

  static String get assetPath => SoriBrandAssets.logoWhite;

  /// GNB / 셸 헤더 표준 높이.
  static const double gnbHeight = 28;

  /// 스플래시: 모바일 폭×0.65 / PC·태블릿 min(720, 60vw).
  static double splashWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) {
      final capped = w * 0.60;
      return capped < 720 ? capped : 720;
    }
    return w * 0.65;
  }

  /// 인앱 기본 반응형 (로그인 등). 스플래시가 아니면 splashWidth와 동일 규칙.
  static double responsiveWidth(BuildContext context) => splashWidth(context);

  Brightness _resolveBrightness(BuildContext context) {
    if (forceWhite) return Brightness.dark;
    if (brightness != null) return brightness!;
    if (usePlatformBrightness) {
      return MediaQuery.platformBrightnessOf(context);
    }
    return Theme.of(context).brightness;
  }

  @override
  Widget build(BuildContext context) {
    final path = forceWhite
        ? SoriBrandAssets.logoWhite
        : SoriBrandAssets.logoForBrightness(_resolveBrightness(context));

    final logoW = width;
    final logoH = height ?? (width == null ? gnbHeight : null);

    return Image.asset(
      path,
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
            Icons.broken_image_outlined,
            size: 18,
            color: SoriTokens.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
