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
  });

  final Widget child;
  final BorderRadius borderRadius;
  final SoriGlassTier tier;

  @override
  Widget build(BuildContext context) {
    final sigma = SoriGlassTokens.blurSigma(tier);
    return ClipRRect(
      borderRadius: borderRadius,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: SoriGlassTokens.overlayDecoration(
              radius: borderRadius.topLeft.x,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
