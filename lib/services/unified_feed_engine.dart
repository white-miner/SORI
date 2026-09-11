import '../models/recommend_feed_category.dart';
import '../models/community_post.dart';
import '../models/feed_query_config.dart';
import '../models/unified_feed_item.dart';
import '../utils/category_presentation_map.dart';
import '../widgets/post/post_view_data.dart';
import 'sori_store.dart';

/// SSOT helpers for home / explore / community feed slices.
abstract final class UnifiedFeedEngine {
  /// Recommend tab — interleaved unified feed (boost slots applied in store).
  /// [config] slices without mutating store cache (R2-1).
  static List<UnifiedFeedItem> recommendItems(
    SoriStore store, {
    FeedQueryConfig config = FeedQueryConfig.community,
  }) {
    var items = store.unifiedCommunityFeed
        .where(store.isUnifiedFeedItemVisible)
        .toList(growable: true);

    if (!config.boostAllowed) {
      items = items.where((e) => !e.isBoosted).toList(growable: true);
    }

    final max = config.maxRecommendItems;
    if (max != null && items.length > max) {
      items = items.take(max).toList(growable: false);
    } else {
      items = List<UnifiedFeedItem>.unmodifiable(items);
    }
    return items;
  }

  /// Explore 2-column grid — all unified types with grid-safe presentation.
  static List<UnifiedFeedItem> exploreGridItems(SoriStore store) {
    return store.unifiedCommunityFeed
        .where(store.isUnifiedFeedItemVisible)
        .where(_isGridEligible)
        .toList(growable: false);
  }

  static bool _isGridEligible(UnifiedFeedItem item) {
    return switch (item.kind) {
      UnifiedFeedKind.ba => _baImage(item).isNotEmpty,
      UnifiedFeedKind.seminar => true,
      UnifiedFeedKind.whisper ||
      UnifiedFeedKind.interior ||
      UnifiedFeedKind.deviceReview ||
      UnifiedFeedKind.marketplace =>
        _postImage(item).isNotEmpty ||
            (item.post?.body.trim().isNotEmpty ?? false) ||
            (item.post?.title.trim().isNotEmpty ?? false),
    };
  }

  static String gridImageUrl(UnifiedFeedItem item) {
    final img = switch (item.kind) {
      UnifiedFeedKind.ba => _baImage(item),
      _ => _postImage(item),
    };
    return img;
  }

  static String gridTitle(UnifiedFeedItem item) {
    return switch (item.kind) {
      UnifiedFeedKind.ba =>
        item.caseItem!.chart.careName.trim().isEmpty
            ? 'B/A'
            : item.caseItem!.chart.careName.trim(),
      UnifiedFeedKind.seminar => item.seminar!.title.trim().isEmpty
          ? '세미나'
          : item.seminar!.title.trim(),
      UnifiedFeedKind.whisper =>
        CategoryPresentationMap.labelOf('whisper', fallback: '조용한 이야기'),
      UnifiedFeedKind.interior => '샵 인테리어',
      UnifiedFeedKind.deviceReview =>
        item.post!.title.trim().isEmpty ? '기기리뷰' : item.post!.title.trim(),
      UnifiedFeedKind.marketplace =>
        item.post!.listing?.deviceName.trim().isNotEmpty == true
            ? item.post!.listing!.deviceName.trim()
            : (item.post!.title.trim().isEmpty
                ? '중고거래'
                : item.post!.title.trim()),
    };
  }

  static String gridSubtitle(UnifiedFeedItem item) {
    final data = PostViewData.fromUnifiedFeedItem(item);
    return switch (item.kind) {
      UnifiedFeedKind.ba => data.bodyText.trim(),
      UnifiedFeedKind.seminar => item.seminar!.description.trim(),
      _ => item.post?.body.trim() ?? '',
    };
  }

  static String gridAuthorName(UnifiedFeedItem item) {
    return PostViewData.fromUnifiedFeedItem(item).authorName;
  }

  static String gridAuthorAvatar(UnifiedFeedItem item) {
    final data = PostViewData.fromUnifiedFeedItem(item);
    return data.avatarUrl?.trim() ?? '';
  }

  static String gridCategoryLabel(UnifiedFeedItem item) {
    return RecommendFeedCategory.fromUnified(item).label;
  }

  static String _baImage(UnifiedFeedItem item) {
    final chart = item.caseItem!.chart;
    return (chart.afterImageUrl ?? chart.beforeImageUrl ?? '').trim();
  }

  static String _postImage(UnifiedFeedItem item) {
    return item.post?.primaryImageUrl?.trim() ?? '';
  }

  /// Skip case_share posts when the same chart is already in hot cases.
  static bool shouldSkipCaseSharePost(
    CommunityPost post,
    Set<String> hotChartIds,
  ) {
    if (post.postType != CommunityPostType.caseShare) return false;
    final cid = post.sourceChartId?.trim() ?? '';
    if (cid.isEmpty) return false;
    return hotChartIds.contains(cid);
  }
}
