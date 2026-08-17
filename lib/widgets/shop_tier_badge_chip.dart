import 'package:flutter/material.dart';

import '../models/shop_tier_badge.dart';
import '../theme/sori_tokens.dart';

/// 샵 티어 뱃지 칩 (피드·프로필).
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

    final colors = switch (badge) {
      ShopTierBadge.bronze => (const Color(0xFFCD7F32), const Color(0xFFFFF4E5)),
      ShopTierBadge.silver => (const Color(0xFF64748B), const Color(0xFFF1F5F9)),
      ShopTierBadge.gold => (const Color(0xFFB45309), const Color(0xFFFFFBEB)),
      ShopTierBadge.master => (SoriTokens.primary, SoriTokens.primarySoft),
      ShopTierBadge.none => (Colors.grey, Colors.white),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.$1.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${badge.emoji} ${badge.label}',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: colors.$1,
        ),
      ),
    );
  }
}
