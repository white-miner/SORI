import 'package:flutter/material.dart';

import '../../models/subscription.dart';
import '../../models/post_engagement_bindings.dart';
import '../../models/unified_feed_item.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/post_navigation.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../widgets/explore/explore_rich_info_card.dart';
import '../../widgets/post/post_view_data.dart';
import '../../services/unified_feed_engine.dart';
import 'habit_feed_engine.dart';

/// Explore tab — 맞춤 추천 / 부스트 / 같은 고민 / 멘토링 Live rails.
class ExploreHabitRails extends StatelessWidget {
  const ExploreHabitRails({
    super.key,
    required this.store,
  });

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final rails = HabitRailKind.values;
    final hasAny = rails.any(
      (r) => HabitFeedEngine.railItems(store, r, limit: 1).isNotEmpty,
    );
    if (!hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rail in rails) ...[
          _HabitRailStrip(store: store, rail: rail),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _HabitRailStrip extends StatelessWidget {
  const _HabitRailStrip({
    required this.store,
    required this.rail,
  });

  final SoriStore store;
  final HabitRailKind rail;

  @override
  Widget build(BuildContext context) {
    final items = HabitFeedEngine.railItems(store, rail, limit: 8);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rail.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              Text(
                rail.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VisitGlassTokens.care.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = UnifiedFeedEngine.gridImageUrl(item);
              return SizedBox(
                width: 148,
                child: ExploreRichInfoCard(
                  imageUrl: imageUrl,
                  title: UnifiedFeedEngine.gridTitle(item),
                  subtitle: UnifiedFeedEngine.gridSubtitle(item),
                  authorName: UnifiedFeedEngine.gridAuthorName(item),
                  authorAvatarUrl: UnifiedFeedEngine.gridAuthorAvatar(item),
                  categoryLabel: _railCategoryLabel(item, rail),
                  textOnly: imageUrl.isEmpty,
                  onTap: () => openUnifiedPostOriginal(
                    context,
                    item: item,
                    store: store,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _railCategoryLabel(UnifiedFeedItem item, HabitRailKind rail) {
    if (rail == HabitRailKind.mentoringLive) return '멘토링';
    if (rail == HabitRailKind.sameStruggle) return '공감';
    return UnifiedFeedEngine.gridCategoryLabel(item);
  }
}

/// Mentoring Loop — Q→A→Boost→Follow nudge after engagement (Phase 3).
abstract final class MentoringLoopService {
  static Future<void> maybeShowFollowUp({
    required BuildContext context,
    required SoriStore store,
    required UnifiedFeedItem item,
    required PostEngagementBindings bindings,
    required MentoringLoopTrigger trigger,
  }) async {
    if (!HabitFeedEngine.isMentoringAsk(item)) return;
    if (!context.mounted) return;

    final data = PostViewData.fromUnifiedFeedItem(item);
    final shopId = item.caseItem?.shop.id.trim() ?? item.post?.shopId.trim();
    if (shopId == null || shopId.isEmpty) return;
    if (store.shop.id.trim() == shopId) return;

    final following = store.isFollowingShop(shopId);
    final author = data.authorName;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trigger == MentoringLoopTrigger.comment
                    ? '조언을 남겼어요'
                    : '멘토링 케이스에 반응했어요',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$author 원장님의 케이스 — Boost로 더 많은 원장에게 노출할 수 있어요.',
                style: const TextStyle(
                  color: SoriTokens.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (bindings.boostEnabled)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    bindings.onBoost();
                  },
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Boost 후원'),
                ),
              if (!following) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    DiscoverDirector? director;
                    for (final d in store.discoverDirectors) {
                      if (d.shopId == shopId) {
                        director = d;
                        break;
                      }
                    }
                    if (director != null) {
                      await store.toggleDiscoverFollow(director);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text('$author 팔로우'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum MentoringLoopTrigger { comment, like }
