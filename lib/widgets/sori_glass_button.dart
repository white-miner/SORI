import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'sori_glass_surface.dart';

/// Monochrome glass CTA — white blur fill + charcoal label.
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
    final body = SoriGlassSurface(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: enabled
                ? null
                : BoxDecoration(
                    color: SoriTokens.surfaceOverlay,
                    borderRadius: radius,
                  ),
            child: Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: enabled
                      ? SoriTokens.textPrimary
                      : SoriTokens.textTertiary,
                  fontWeight: FontWeight.w800,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: enabled
                        ? SoriTokens.textPrimary
                        : SoriTokens.textTertiary,
                  ),
                  child: child,
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
