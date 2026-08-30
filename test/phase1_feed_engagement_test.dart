import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/community_post.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/unified_feed_engine.dart';
import 'package:sori/widgets/post/post_view_data.dart';

void main() {
  test('shouldSkipCaseSharePost dedups hot chart ids', () {
    const post = CommunityPost(
      id: 'p1',
      shopId: 's1',
      shopName: 'Shop',
      title: '',
      body: 'share',
      postType: CommunityPostType.caseShare,
      visibility: CommunityVisibility.public,
      sourceChartId: 'chart-1',
    );
    expect(
      UnifiedFeedEngine.shouldSkipCaseSharePost(post, {'chart-1'}),
      isTrue,
    );
    expect(
      UnifiedFeedEngine.shouldSkipCaseSharePost(post, {'chart-2'}),
      isFalse,
    );
  });

  test('recommendItems and exploreGridItems share unifiedCommunityFeed SSOT',
      () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    final recommend = UnifiedFeedEngine.recommendItems(store);
    final explore = UnifiedFeedEngine.exploreGridItems(store);

    expect(recommend, isNotEmpty);
    expect(explore.length, lessThanOrEqualTo(recommend.length));
    for (final item in explore) {
      expect(recommend.any((r) => r.stableKey == item.stableKey), isTrue);
    }
  });

  test('resolveEngagementPostId maps chart to community post', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    final caseItem = store.communityHotCases.firstOrNull;
    if (caseItem == null) return;

    final chartId = caseItem.chart.id;
    final data = PostViewData.fromCaseItem(caseItem);
    final postId = store.resolveEngagementPostId(data);

    if (store.chartToCommunityPostId.containsKey(chartId)) {
      expect(postId, store.chartToCommunityPostId[chartId]);
    }
  });

  test('toggleChartLike updates local cache', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    final caseItem = store.communityHotCases.firstOrNull;
    if (caseItem == null || store.session == null) return;

    final chartId = caseItem.chart.id;
    final before = store.isChartLiked(chartId);
    final ok = await store.toggleChartLike(chartId);
    expect(ok, isTrue);
    expect(store.isChartLiked(chartId), !before);
  });
}
