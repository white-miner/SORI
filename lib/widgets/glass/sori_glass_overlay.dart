import 'dart:ui';

import 'package:flutter/material.dart';

import 'sori_glass_tokens.dart';

/// L3 real blur overlay shell — nav bar, modals.
class SoriGlassOverlay extends StatelessWidget {
  const SoriGlassOverlay({
    super.key,
    required this.child,
    required this.borderRadius,
    this.tier = SoriGlassTier.l3Overlay,
    this.fill,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final SoriGlassTier tier;

  /// 지정하면 이 표면만 다른 불투명도를 쓴다. 모달 등 공용 값은 그대로 둔다.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final sigma = SoriGlassTokens.blurSigma(tier);
    final radius = borderRadius.topLeft.x;
    final decoration = fill == null
        ? SoriGlassTokens.overlayDecoration(radius: radius)
        : SoriGlassTokens.overlayDecoration(radius: radius).copyWith(
            color: fill,
          );
    return ClipRRect(
      borderRadius: borderRadius,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}
