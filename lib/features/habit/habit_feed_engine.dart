import '../../models/community_post.dart';
import '../../models/unified_feed_item.dart';
import '../../services/sori_store.dart';

/// Phase 3 — Story Rail & Explore habit rails (PRD v3.0 The Habit).
enum HabitRailKind {
  forYou,
  boostSpotlight,
  sameStruggle,
  mentoringLive;

  String get label => switch (this) {
        HabitRailKind.forYou => 'For You',
        HabitRailKind.boostSpotlight => 'Boost',
        HabitRailKind.sameStruggle => 'Same Struggle',
        HabitRailKind.mentoringLive => 'Mentoring Live',
      };

  String get subtitle => switch (this) {
        HabitRailKind.forYou => '팔로우·티어 기반 추천',
        HabitRailKind.boostSpotlight => '부스터 케이스',
        HabitRailKind.sameStruggle => 'Whisper 공감',
        HabitRailKind.mentoringLive => '조언 구하는 케이스',
      };
}

abstract final class HabitFeedEngine {
  static const _mentoringTags = {'멘토링', '조언구함', 'mentoring'};
  static const _empathyTags = {'감성', '비식별', '공감', 'whisper'};

  static List<UnifiedFeedItem> _visible(SoriStore store) {
    return store.unifiedCommunityFeed
        .where(store.isUnifiedFeedItemVisible)
        .toList(growable: false);
  }

  /// TikTok-style vertical snap — B/A & visual-first ranking.
  static List<UnifiedFeedItem> storyRailItems(
    SoriStore store, {
    int limit = 12,
  }) {
    final items = _visible(store);
    final ranked = List<UnifiedFeedItem>.from(items)
      ..sort((a, b) => _storyScore(store, b).compareTo(_storyScore(store, a)));
    return ranked.take(limit).toList(growable: false);
  }

  static int _storyScore(SoriStore store, UnifiedFeedItem item) {
    var score = item.sortAt.millisecondsSinceEpoch ~/ 1000;
    if (item.isBoosted || item.caseItem?.isBoosted == true) score += 5000;
    if (isMentoringAsk(item)) score += 1200;
    if (item.kind == UnifiedFeedKind.ba) score += 800;
    final shopId = _shopId(item);
    if (shopId != null && store.isFollowingShop(shopId)) score += 3000;
    return score;
  }

  static List<UnifiedFeedItem> railItems(
    SoriStore store,
    HabitRailKind rail, {
    int limit = 10,
  }) {
    final items = switch (rail) {
      HabitRailKind.forYou => forYouItems(store, limit: limit),
      HabitRailKind.boostSpotlight => boostSpotlightItems(store, limit: limit),
      HabitRailKind.sameStruggle => sameStruggleItems(store, limit: limit),
      HabitRailKind.mentoringLive => mentoringLiveItems(store, limit: limit),
    };
    return items;
  }

  static List<UnifiedFeedItem> forYouItems(
    SoriStore store, {
    int limit = 10,
  }) {
    final items = _visible(store);
    final ranked = List<UnifiedFeedItem>.from(items)
      ..sort((a, b) => _forYouScore(store, b).compareTo(_forYouScore(store, a)));
    return ranked.take(limit).toList(growable: false);
  }

  static int _forYouScore(SoriStore store, UnifiedFeedItem item) {
    var score = item.sortAt.millisecondsSinceEpoch ~/ 1000;
    final shopId = _shopId(item);
    if (shopId != null && store.isFollowingShop(shopId)) score += 4000;
    final tier = item.caseItem?.shop.tierBadge.index ?? 0;
    score += tier * 200;
    if (item.kind == UnifiedFeedKind.ba) score += 600;
    return score;
  }

  static List<UnifiedFeedItem> boostSpotlightItems(
    SoriStore store, {
    int limit = 10,
  }) {
    return _visible(store)
        .where(
          (e) => e.isBoosted || (e.caseItem?.isBoosted ?? false),
        )
        .take(limit)
        .toList(growable: false);
  }

  static List<UnifiedFeedItem> sameStruggleItems(
    SoriStore store, {
    int limit = 10,
  }) {
    return _visible(store).where(isSameStruggle).take(limit).toList(growable: false);
  }

  static List<UnifiedFeedItem> mentoringLiveItems(
    SoriStore store, {
    int limit = 10,
  }) {
    return _visible(store).where(isMentoringAsk).take(limit).toList(growable: false);
  }

  static bool isMentoringAsk(UnifiedFeedItem item) {
    if (item.caseItem?.hasActiveMentoring ?? false) return true;
    final tags = _styleTags(item);
    if (tags.any((t) => _mentoringTags.contains(t.trim()))) return true;
    if (item.kind == UnifiedFeedKind.ba &&
        item.post?.postType == CommunityPostType.caseShare &&
        tags.any((t) => t.contains('멘토링') || t.contains('조언'))) {
      return true;
    }
    return false;
  }

  static bool isSameStruggle(UnifiedFeedItem item) {
    if (item.kind == UnifiedFeedKind.whisper) return true;
    final tags = _styleTags(item);
    return tags.any((t) => _empathyTags.contains(t.trim()));
  }

  static List<String> _styleTags(UnifiedFeedItem item) {
    return item.post?.styleTags ?? const [];
  }

  static String? _shopId(UnifiedFeedItem item) {
    final fromCase = item.caseItem?.shop.id.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    final fromPost = item.post?.shopId.trim();
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;
    return null;
  }
}

/// Own-shop publish reactions for Insights Digest (last 24h).
class InsightsDigestSnapshot {
  const InsightsDigestSnapshot({
    required this.totalLikes,
    required this.totalComments,
    required this.postCount,
    required this.topLine,
  });

  final int totalLikes;
  final int totalComments;
  final int postCount;
  final String topLine;

  bool get hasActivity => postCount > 0 && (totalLikes > 0 || totalComments > 0);
}

abstract final class InsightsDigestEngine {
  static InsightsDigestSnapshot snapshot(SoriStore store) {
    final shopId = store.shop.id.trim();
    if (shopId.isEmpty) {
      return const InsightsDigestSnapshot(
        totalLikes: 0,
        totalComments: 0,
        postCount: 0,
        topLine: '발행한 케이스 반응을 모아 보여드려요',
      );
    }

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    var likes = 0;
    var comments = 0;
    var count = 0;

    for (final post in store.communityPosts) {
      if (post.shopId.trim() != shopId) continue;
      final created = post.createdAt;
      if (created != null && created.isBefore(cutoff)) continue;
      count++;
      likes += post.likeCount;
      comments += post.commentCount;

      final chartId = post.sourceChartId?.trim();
      if (chartId != null && chartId.isNotEmpty) {
        likes += store.chartLikeCount(chartId, fallback: 0);
      }
    }

    for (final item in store.communityHotCases) {
      if (item.shop.id.trim() != shopId) continue;
      final posted = item.chart.feedPostedAt;
      if (posted != null && posted.isBefore(cutoff)) continue;
      count++;
      likes += store.chartLikeCount(item.chart.id, fallback: 0);
    }

    final topLine = count == 0
        ? '최근 24시간 발행이 없어요 — Visit 후 Publish Rail로 시작해 보세요'
        : '최근 24시간 · $count건 · ♥ $likes · 💬 $comments';

    return InsightsDigestSnapshot(
      totalLikes: likes,
      totalComments: comments,
      postCount: count,
      topLine: topLine,
    );
  }
}
