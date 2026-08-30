import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../theme/visit_glass_tokens.dart';

class VisitGlassCard extends StatelessWidget {
  const VisitGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.radius = VisitGlassTokens.radiusLg,
    this.socialGlow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;
  final bool socialGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: VisitGlassTokens.calmMotion,
      curve: VisitGlassTokens.calmCurve,
      decoration: VisitGlassTokens.cardDecoration(
        tint: tint,
        radius: radius,
        socialGlow: socialGlow,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class VisitProgressRing extends StatelessWidget {
  const VisitProgressRing({
    super.key,
    required this.ratio,
    this.size = 56,
    this.stroke = 5,
    this.label,
  });

  final double ratio;
  final double size;
  final double stroke;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: ratio.clamp(0, 1),
              strokeWidth: stroke,
              backgroundColor: VisitGlassTokens.care.withValues(alpha: 0.15),
              color: VisitGlassTokens.care,
            ),
          ),
          Text(
            label ?? '$pct%',
            style: VisitGlassTokens.displayKpi(context).copyWith(
              fontSize: size * 0.26,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
