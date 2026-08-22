import 'package:flutter/material.dart';

import '../models/shop_tier_badge.dart';
import '../theme/sori_tokens.dart';

/// 10등급 통합 티어 뱃지 칩.
class ShopTierBadgeChip extends StatelessWidget {
  const ShopTierBadgeChip({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final ShopTierBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!badge.isVisible) return const SizedBox.shrink();

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
          foreground: Color(0xFFE5E7EB),
          background: Color(0xFF1F2937),
          border: Color(0xFF4B5563),
        ),
      ShopTierBadge.bronze => const _TierVisual(
          foreground: Color(0xFFFDBA74),
          background: Color(0xFF2A2118),
          border: Color(0xFFCD7F32),
        ),
      ShopTierBadge.silver => const _TierVisual(
          foreground: Color(0xFFE2E8F0),
          background: Color(0xFF1E293B),
          border: Color(0xFF94A3B8),
        ),
      ShopTierBadge.gold => const _TierVisual(
          foreground: Color(0xFFFDE68A),
          background: Color(0xFF2A2410),
          border: Color(0xFFEAB308),
          sparkle: true,
          gradient: LinearGradient(
            colors: [Color(0xFF3F2E0A), Color(0xFF854D0E), Color(0xFF2A2410)],
          ),
        ),
      ShopTierBadge.platinum => const _TierVisual(
          foreground: Color(0xFFE0F2FE),
          background: Color(0xFF083344),
          border: Color(0xFF67E8F9),
          sparkle: true,
          gradient: LinearGradient(
            colors: [Color(0xFF164E63), Color(0xFF0E7490), Color(0xFF1E293B)],
          ),
        ),
      ShopTierBadge.diamond => const _TierVisual(
          foreground: Color(0xFFA5F3FC),
          background: Color(0xFF0F172A),
          border: Color(0xFF22D3EE),
          sparkle: true,
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF164E63),
              Color(0xFF1E1B4B),
            ],
          ),
        ),
      ShopTierBadge.mentor => const _TierVisual(
          foreground: Color(0xFFC7D2FE),
          background: Color(0xFF1E1B4B),
          border: Color(0xFF6366F1),
        ),
      ShopTierBadge.master => const _TierVisual(
          foreground: Color(0xFFE9D5FF),
          background: Color(0xFF2E1065),
          border: SoriTokens.primary,
          sparkle: true,
          gradient: LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF5B21B6), Color(0xFF1E1B4B)],
          ),
        ),
      ShopTierBadge.grandMaster => const _TierVisual(
          foreground: Color(0xFFFFF7ED),
          background: Color(0xFF1E1B4B),
          border: Color(0xFFFBBF24),
          sparkle: true,
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF78350F)],
          ),
        ),
      ShopTierBadge.grandDirector => const _TierVisual(
          foreground: Color(0xFFF5D0FE),
          background: Color(0xFF2E1065),
          border: Color(0xFFA855F7),
          sparkle: true,
          gradient: LinearGradient(
            colors: [
              Color(0xFF2E1065),
              Color(0xFF164E63),
              Color(0xFF4A044E),
              Color(0xFF14532D),
            ],
          ),
        ),
      ShopTierBadge.none => const _TierVisual(
          foreground: SoriTokens.textSecondary,
          background: SoriTokens.surface,
          border: SoriTokens.border,
        ),
    };
  }
}
