import 'package:flutter/material.dart';

import '../../models/session_user.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import 'habit_feed_engine.dart';

/// Director-only — "내 케이스 반응" glass digest (no streak/homework UI).
class InsightsDigestCard extends StatelessWidget {
  const InsightsDigestCard({
    super.key,
    required this.store,
  });

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final session = store.session;
    if (session?.activeMode != UserRole.director) {
      return const SizedBox.shrink();
    }

    final snap = InsightsDigestEngine.snapshot(store);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: VisitGlassCard(
        socialGlow: snap.hasActivity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: VisitGlassTokens.care.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                const Text(
                  '내 케이스 반응',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              snap.topLine,
              style: VisitGlassTokens.bodyCalm.copyWith(
                color: SoriTokens.textSecondary,
              ),
            ),
            if (snap.hasActivity) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetricChip(
                    icon: Icons.favorite_rounded,
                    label: '${snap.totalLikes}',
                    caption: '좋아요',
                  ),
                  const SizedBox(width: 10),
                  _MetricChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${snap.totalComments}',
                    caption: '댓글',
                  ),
                  const SizedBox(width: 10),
                  _MetricChip(
                    icon: Icons.article_outlined,
                    label: '${snap.postCount}',
                    caption: '발행',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: VisitGlassTokens.care.withValues(alpha: 0.08),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: VisitGlassTokens.care),
            const SizedBox(height: 4),
            Text(
              label,
              style: VisitGlassTokens.displayKpi(context).copyWith(
                fontSize: 18,
                color: SoriTokens.textPrimary,
              ),
            ),
            Text(
              caption,
              style: VisitGlassTokens.captionCalm.copyWith(
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
