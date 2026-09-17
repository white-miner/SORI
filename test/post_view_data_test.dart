import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/models/unified_feed_item.dart';
import 'package:sori/widgets/post/post_layout_breakpoints.dart';
import 'package:sori/widgets/post/post_view_data.dart';

void main() {
  test('PostViewData uses explicit ai_content when present', () {
    const post = CommunityPost(
      id: 'p1',
      shopId: 's1',
      shopName: 'Shop',
      title: '',
      body: '',
      postType: CommunityPostType.interior,
      visibility: CommunityVisibility.public,
      aiContent: 'AI generated summary',
    );
    final data = PostViewData.fromUnifiedFeedItem(
      UnifiedFeedItem.post(post, UnifiedFeedKind.interior),
    );
    expect(data.resolveAiSummary(), 'AI generated summary');
  });

  test('PostViewData chart fallback when body empty and linked B/A', () {
    final chart = CustomerChart(
      id: 'c1',
      shopId: 's1',
      customerId: 'cust',
      visitNumber: 1,
      concernChips: const ['홍조'],
    );
    final caseItem = CommunityCaseItem(
      chart: chart,
      shop: const Shop(id: 's1', name: 'Test Shop', naverPlaceUrl: ''),
      careTags: const ['장벽'],
    );
    final data = PostViewData.fromCaseItem(caseItem);
    expect(data.bodyText.trim().isNotEmpty, isTrue);
    final emptyBody = PostViewData(
      id: 'c1',
      kind: PostViewKind.ba,
      sortAt: DateTime.now(),
      authorName: '원장',
      affiliation: 'Shop',
      categoryLabel: 'B/A',
      bodyText: '',
      timeLabel: '1분 전',
      caseItem: caseItem,
      linkedChartId: 'c1',
    );
    expect(emptyBody.resolveAiSummary(), isNotNull);
    expect(emptyBody.resolveAiSummary()!.contains('홍조'), isTrue);
  });

  test('PostViewData hides AI block when no content and no fallback', () {
    const post = CommunityPost(
      id: 'p2',
      shopId: 's1',
      shopName: 'Shop',
      title: 'hello',
      body: 'manual body',
      postType: CommunityPostType.interior,
      visibility: CommunityVisibility.public,
    );
    final data = PostViewData.fromUnifiedFeedItem(
      UnifiedFeedItem.post(post, UnifiedFeedKind.interior),
    );
    expect(data.resolveAiSummary(), isNull);
  });

  test('PostViewData commentPostId resolves community post and B/A chart', () {
    const post = CommunityPost(
      id: 'p-comment',
      shopId: 's1',
      shopName: 'Shop',
      title: 't',
      body: 'b',
      postType: CommunityPostType.interior,
      visibility: CommunityVisibility.public,
    );
    final fromPost = PostViewData.fromUnifiedFeedItem(
      UnifiedFeedItem.post(post, UnifiedFeedKind.interior),
    );
    expect(fromPost.commentPostId, 'p-comment');

    final chart = CustomerChart(
      id: 'chart-comment',
      shopId: 's1',
      customerId: 'cust',
      visitNumber: 1,
    );
    final caseItem = CommunityCaseItem(
      chart: chart,
      shop: const Shop(id: 's1', name: 'Test Shop', naverPlaceUrl: ''),
      careTags: const [],
    );
    final fromBa = PostViewData.fromCaseItem(caseItem);
    expect(fromBa.commentPostId, 'chart-comment');
  });

  test('PostLayoutBreakpoints desktop at 1024px', () {
    expect(PostLayoutBreakpoints.isDesktopLayout(1023), isFalse);
    expect(PostLayoutBreakpoints.isDesktopLayout(1024), isTrue);
    expect(PostLayoutBreakpoints.contentMaxWidth, 720);
    expect(PostLayoutBreakpoints.sidebarWidth, greaterThanOrEqualTo(350));
    expect(PostLayoutBreakpoints.sidebarWidth, lessThanOrEqualTo(400));
  });
}
