import 'package:flutter/material.dart';

import '../models/shop_trust_score.dart';
import '../theme/sori_tokens.dart';

/// 샵 프로필 신뢰 스코어 카드 (S5).
class ShopTrustScoreCard extends StatelessWidget {
  const ShopTrustScoreCard({
    super.key,
    required this.trust,
    this.compact = false,
  });

  final ShopTrustScore trust;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _scoreColor(trust.score).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: _scoreColor(trust.score).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              size: 14,
              color: _scoreColor(trust.score),
            ),
            const SizedBox(width: 4),
            Text(
              '${trust.score} · ${trust.tierLabel}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _scoreColor(trust.score),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 20,
                color: _scoreColor(trust.score),
              ),
              const SizedBox(width: 8),
              Text(
                '신뢰 스코어 ${trust.score}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                trust.tierLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(trust.score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trust.summaryLine,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
              height: 1.35,
            ),
          ),
          if (trust.seminarCount > 0 || trust.thankYouRate > 0) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (trust.seminarCount > 0) '세미나 ${trust.seminarCount}',
                if (trust.thankYouRate > 0)
                  '감사 답장 ${(trust.thankYouRate * 100).round()}%',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _scoreColor(int score) {
    if (score >= 75) return const Color(0xFF059669);
    if (score >= 45) return SoriTokens.primary;
    return SoriTokens.textSecondary;
  }
}
