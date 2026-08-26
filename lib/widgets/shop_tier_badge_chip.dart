import 'package:flutter/material.dart';

import '../models/shop_tier_badge.dart';
import '../theme/sori_tokens.dart';

/// 10등급 통합 티어 뱃지 칩.
class ShopTierBadgeChip extends StatelessWidget {
  const ShopTierBadgeChip({
    super.key,
    required this.badge,
    this.compact = false,
    this.animateGlow = false,
  });

  final ShopTierBadge badge;
  final bool compact;
  final bool animateGlow;

  @override
  Widget build(BuildContext context) {
    if (!badge.isVisible) return const SizedBox.shrink();

    final chip = _BadgeCore(badge: badge, compact: compact);
    if (!animateGlow) return chip;
    return _GlowingBadge(child: chip);
  }
}

class _GlowingBadge extends StatefulWidget {
  const _GlowingBadge({required this.child});
  final Widget child;

  @override
  State<_GlowingBadge> createState() => _GlowingBadgeState();
}

class _GlowingBadgeState extends State<_GlowingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: SoriTokens.textQuaternary.withValues(alpha: 0.25 + 0.35 * t),
                blurRadius: 6 + 10 * t,
                spreadRadius: 0.5 + t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _BadgeCore extends StatelessWidget {
  const _BadgeCore({required this.badge, required this.compact});

  final ShopTierBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _TierVisual.of(badge);
    final padH = compact ? 8.0 : 10.0;
    final padV = compact ? 3.0 : 5.0;
    final fontSize = compact ? 10.0 : 11.5;

    final child = Text(
      '${badge.emoji} ${badge.label}',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: style.foreground,
        letterSpacing: -0.2,
        shadows: style.sparkle
            ? [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        gradient: style.gradient,
        color: style.gradient == null ? style.background : null,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: style.border.withValues(alpha: style.sparkle ? 0.65 : 0.4),
          width: style.sparkle ? 1.4 : 1,
        ),
        boxShadow: style.sparkle
            ? [
                BoxShadow(
                  color: style.border.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _TierVisual {
  const _TierVisual({
    required this.foreground,
    required this.background,
    required this.border,
    this.gradient,
    this.sparkle = false,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final Gradient? gradient;
  final bool sparkle;

  static _TierVisual of(ShopTierBadge badge) {
    return switch (badge) {
      ShopTierBadge.iron => const _TierVisual(
          foreground: SoriTokens.textSecondary,
          background: SoriTokens.surfaceOverlay,
          border: SoriTokens.border,
        ),
      ShopTierBadge.bronze => const _TierVisual(
          foreground: SoriTokens.textSecondary,
          background: SoriTokens.primarySoft,
          border: SoriTokens.border,
        ),
      ShopTierBadge.silver => const _TierVisual(
          foreground: SoriTokens.textPrimary,
          background: SoriTokens.surfaceOverlay,
          border: SoriTokens.border,
        ),
      ShopTierBadge.gold => const _TierVisual(
          foreground: SoriTokens.textPrimary,
          background: SoriTokens.primarySoft,
          border: SoriTokens.primaryLight,
          sparkle: true,
        ),
      ShopTierBadge.platinum => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primaryLight,
          border: SoriTokens.primary,
          sparkle: true,
        ),
      ShopTierBadge.diamond => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primaryDark,
          border: SoriTokens.primaryLight,
          sparkle: true,
        ),
      ShopTierBadge.mentor => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primary,
          border: SoriTokens.primaryDark,
        ),
      ShopTierBadge.master => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primaryDark,
          border: SoriTokens.primary,
          sparkle: true,
        ),
      ShopTierBadge.grandMaster => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primaryDark,
          border: SoriTokens.primaryLight,
          sparkle: true,
        ),
      ShopTierBadge.grandDirector => const _TierVisual(
          foreground: SoriTokens.onPrimary,
          background: SoriTokens.primaryDark,
          border: SoriTokens.primary,
          sparkle: true,
        ),
      ShopTierBadge.none => const _TierVisual(
          foreground: SoriTokens.textSecondary,
          background: SoriTokens.surface,
          border: SoriTokens.border,
        ),
    };
  }
}
