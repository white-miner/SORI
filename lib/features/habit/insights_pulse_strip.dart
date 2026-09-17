import 'package:flutter/material.dart';

import '../../models/session_user.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'habit_feed_engine.dart';

/// PRD v3.1 — one-line insights pulse (no tier, no streak).
class InsightsPulseStrip extends StatelessWidget {
  const InsightsPulseStrip({
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: SoriTokens.surface,
          border: Border.all(color: SoriTokens.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              size: 18,
              color: SoriTokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                snap.hasActivity
                    ? '최근 24h · ♥ ${snap.totalLikes} · 💬 ${snap.totalComments}'
                    : snap.topLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
