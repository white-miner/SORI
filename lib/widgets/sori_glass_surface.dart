import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'glass/sori_glass_tokens.dart';

/// Semi-transparent L1 surface + backdrop blur.
class SoriGlassSurface extends StatelessWidget {
  const SoriGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(SoriTokens.radiusLg);
    final sigma = SoriGlassTokens.blurSigma(SoriGlassTier.l1Surface);
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SoriGlassTokens.fillColor(SoriGlassTier.l1Surface),
                borderRadius: radius,
                border: border
                    ? Border.all(color: SoriTokens.border, width: 1)
                    : null,
                boxShadow: SoriTokens.cardShadow,
              ),
              child: padding != null
                  ? Padding(padding: padding!, child: child)
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opaque white dialog — readable on any backdrop.
Future<T?> showSoriGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      return Dialog(
        backgroundColor: SoriTokens.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
        ),
        child: builder(ctx),
      );
    },
  );
}
