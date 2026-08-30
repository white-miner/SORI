import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../../crm_kernel/theme/crm_calm_glass_tokens.dart';

/// CDG card shell — Calm Data Glass surface.
class CrmCalmGlassCard extends StatelessWidget {
  const CrmCalmGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.radius = CrmCalmGlassTokens.radiusLg,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: CrmCalmGlassTokens.calmMotion,
      curve: CrmCalmGlassTokens.calmCurve,
      decoration: CrmCalmGlassTokens.cardDecoration(tint: tint, radius: radius),
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

/// Apple Activity-style progress ring.
class CrmProgressRing extends StatelessWidget {
  const CrmProgressRing({
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
              backgroundColor: CrmCalmGlassTokens.care.withValues(alpha: 0.15),
              color: CrmCalmGlassTokens.care,
            ),
          ),
          Text(
            label ?? '$pct%',
            style: CrmCalmGlassTokens.displayKpi(context).copyWith(
              fontSize: size * 0.26,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
