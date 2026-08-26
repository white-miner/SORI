import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Semi-transparent white + backdrop blur (sigma 10).
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
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: SoriTokens.glassBlurFilter,
          child: DecoratedBox(
            decoration: SoriTokens.glassSurface(
              radius: 20,
              showBorder: border,
            ),
            child: padding != null ? Padding(padding: padding!, child: child) : child,
          ),
        ),
      ),
    );
  }
}

/// Glass-wrapped dialog — use instead of raw [AlertDialog] chrome.
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SoriGlassSurface(
          borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
          child: builder(ctx),
        ),
      );
    },
  );
}
