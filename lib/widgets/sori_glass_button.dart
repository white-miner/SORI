import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// 글래스모피즘 에메랄드 CTA — BackdropFilter + primaryGlass.
class SoriGlassButton extends StatelessWidget {
  const SoriGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.borderRadius = 12,
    this.expanded = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(borderRadius);
    final body = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Ink(
              decoration: enabled
                  ? SoriTokens.glassEmerald(radius: borderRadius)
                  : BoxDecoration(
                      color: SoriTokens.surfaceOverlay,
                      borderRadius: radius,
                    ),
              child: Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: enabled
                        ? SoriTokens.onPrimary
                        : SoriTokens.textTertiary,
                    fontWeight: FontWeight.w900,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: enabled
                          ? SoriTokens.onPrimary
                          : SoriTokens.textTertiary,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!expanded) return body;
    return SizedBox(width: double.infinity, child: body);
  }
}
