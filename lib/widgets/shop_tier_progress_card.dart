import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../theme/sori_tokens.dart';
import 'shop_tier_badge_chip.dart';

/// 마이페이지 — 소셜/비즈니스 트랙 다음 등급 잔여 조건.
class ShopTierProgressCard extends StatelessWidget {
  const ShopTierProgressCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '티어 프로그레스',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const Spacer(),
              ShopTierBadgeChip(badge: shop.tierBadge, compact: true),
            ],
          ),
          const SizedBox(height: 14),
          _TrackBlock(
            title: '소셜 트랙',
            hint: snap.socialHint,
            ratio: snap.socialRatio,
            color: const Color(0xFF0EA5E9),
            activityScore: shop.communityActivityScore,
          ),
          const SizedBox(height: 12),
          _TrackBlock(
            title: '비즈니스 트랙',
            hint: snap.businessHint,
            ratio: snap.businessRatio,
            color: SoriTokens.primary,
          ),
        ],
      ),
    );
  }
}

class _TrackBlock extends StatelessWidget {
  const _TrackBlock({
    required this.title,
    required this.hint,
    required this.ratio,
    required this.color,
    this.activityScore = 0,
  });

  final String title;
  final String hint;
  final double ratio;
  final Color color;
  final int activityScore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.04, 1),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        if (activityScore > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Community 활동 +$activityScore',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}
