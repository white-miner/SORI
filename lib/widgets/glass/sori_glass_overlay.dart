import 'dart:ui';

import 'package:flutter/material.dart';

import 'sori_glass_tokens.dart';

/// L3 blur overlay — floating tools only.
/// [enableBlur] false = color/border만 (AppBar cluster 등 · glass 예산 절약).
class SoriGlassOverlay extends StatelessWidget {
  const SoriGlassOverlay({
    super.key,
    required this.child,
    required this.borderRadius,
    this.tier = SoriGlassTier.l3Overlay,
    this.fill,
    this.enableBlur = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final SoriGlassTier tier;

  /// 지정하면 이 표면만 다른 불투명도를 쓴다. 모달 등 공용 값은 그대로 둔다.
  final Color? fill;

  /// false면 BackdropFilter 생략 (중첩 blur·AppBar 예산용).
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final sigma = SoriGlassTokens.blurSigma(tier);
    final radius = borderRadius.topLeft.x;
    final decoration = fill == null
        ? SoriGlassTokens.overlayDecoration(radius: radius)
        : SoriGlassTokens.overlayDecoration(radius: radius).copyWith(
            color: fill,
          );
    final surface = DecoratedBox(
      decoration: decoration,
      child: child,
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: enableBlur && sigma > 0
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: surface,
              ),
            )
          : surface,
    );
  }
}