import 'package:flutter/material.dart';

import '../models/customer_review.dart';
import '../theme/sori_tokens.dart';

/// B/A 케이스 카드용 — 고객 후기 + 원장 답글 인라인 블록.
class CaseReviewInlineBlock extends StatelessWidget {
  const CaseReviewInlineBlock({
    super.key,
    required this.review,
    this.compact = false,
  });

  final CustomerReview review;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = review.displayText.trim();
    if (body.isEmpty) return const SizedBox.shrink();
    final reply = review.directorReply?.trim() ?? '';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: compact ? 8 : 10),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💬 고객 리얼 후기: $body',
            style: TextStyle(
              fontSize: compact ? 12.5 : 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '↳ 👑 원장님 답글: $reply',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: SoriTokens.primary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 실제 후기 인증 뱃지.
class VerifiedReviewBadge extends StatelessWidget {
  const VerifiedReviewBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A95), Color(0xFFC44DFF)],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(
        '실제 후기 인증',
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
