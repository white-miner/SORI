import 'package:flutter/material.dart';

import '../models/boost_contribution_report.dart';
import '../theme/sori_tokens.dart';

/// 원장 — 30일 후원 기여 요약 카드 (E5-lite).
class SponsorshipImpactSummaryCard extends StatelessWidget {
  const SponsorshipImpactSummaryCard({
    super.key,
    required this.impact,
  });

  final ShopSponsorshipImpact impact;

  @override
  Widget build(BuildContext context) {
    if (impact.giftCount == 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SoriTokens.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SoriTokens.border),
        ),
        child: const Text(
          '최근 30일 후원이 없어요.\n팔로워가 케이스를 응원하면 여기에 기여가 집계됩니다.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SoriTokens.textSecondary,
            height: 1.35,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 ${impact.periodDays}일 후원 기여',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricChip(
                label: '후원',
                value: '${impact.giftCount}건',
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Echo',
                value: '${impact.echoTotal}E',
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: '저장',
                value: '${impact.bookmarksReceived}건',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricChip(
                label: '노출 추정',
                value: '${impact.estimatedTotalReach}회',
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: '감사 위스퍼',
                value: '${impact.thankYousSent}건',
              ),
              if (impact.pendingThanks > 0) ...[
                const SizedBox(width: 8),
                _MetricChip(
                  label: '답장 대기',
                  value: '${impact.pendingThanks}',
                  highlight: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? SoriTokens.primary.withValues(alpha: 0.08)
              : SoriTokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight ? SoriTokens.primary.withValues(alpha: 0.35) : SoriTokens.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: highlight ? SoriTokens.primary : SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: highlight ? SoriTokens.primary : SoriTokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
