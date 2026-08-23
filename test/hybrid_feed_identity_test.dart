import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/feed_expandable_caption.dart';
import 'package:sori/widgets/feed_media_carousel.dart';
import 'package:sori/widgets/home_feed_card.dart';

void main() {
  test('multi-shop member exposes nickname above shop affiliation', () {
    const item = CommunityCaseItem(
      chart: CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cust',
        visitNumber: 1,
        authorId: 'member-1',
      ),
      shop: Shop(
        id: 'shop-1',
        name: '글로우핏 강남',
        naverPlaceUrl: '',
        ownerName: '이서연',
      ),
      authorNickname: '박지성',
    );
    expect(item.displayAuthorNickname, '박지성');
    expect(item.displayShopAffiliation, '글로우핏 강남');
    expect(item.displayAuthorNickname, isNot(item.displayShopAffiliation));
  });

  test('plan A keeps nickname and shop even when identical strings', () {
    const item = CommunityCaseItem(
      chart: CustomerChart(
        id: 'c2',
        shopId: 'shop-2',
        customerId: 'cust',
        visitNumber: 1,
      ),
      shop: Shop(
        id: 'shop-2',
        name: '김원장샵',
        naverPlaceUrl: '',
        ownerName: '김원장',
      ),
      authorNickname: '김원장샵',
    );
    expect(item.displayAuthorNickname, '김원장샵');
    expect(item.displayShopAffiliation, '김원장샵');
  });

  test('feedSlidesForCase builds before then after', () {
    final slides = feedSlidesForCase(
      beforeUrl: 'https://example.com/b.jpg',
      afterUrl: 'https://example.com/a.jpg',
    );
    expect(slides, hasLength(2));
    expect(slides[0].url, contains('b.jpg'));
    expect(slides[1].url, contains('a.jpg'));
  });

  test('memory hot cases include multi-shop member identity', () async {
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();
    final member = store.communityHotCases.where(
      (e) => e.authorNickname == '박지성',
    );
    expect(member, isNotEmpty);
    final hit = member.first;
    expect(hit.displayAuthorNickname, '박지성');
    expect(hit.displayShopAffiliation, '글로우핏 강남');
  });

  testWidgets('HomeFeedCard renders Weverse two-line header', (tester) async {
    final item = CommunityCaseItem(
      chart: CustomerChart(
        id: 'chart-ui-1',
        shopId: 'shop-ui',
        customerId: 'c',
        visitNumber: 1,
        careName: '리프팅 집중 케어',
        treatmentSummary: '라인 정돈과 탄력 관리를 중심으로 진행한 케이스입니다. ' * 3,
        beforeImageUrl: 'https://picsum.photos/seed/feed-b/400/500',
        afterImageUrl: 'https://picsum.photos/seed/feed-a/400/500',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        authorId: 'member-ui',
      ),
      shop: const Shop(
        id: 'shop-ui',
        name: 'NCT DREAM 클리닉',
        naverPlaceUrl: '',
        ownerName: '원장',
      ),
      authorNickname: '박지성',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeFeedCard(
              item: item,
              liked: false,
              likeCount: 0,
              commentCount: 0,
              bookmarked: false,
              onLike: () {},
              onComment: () {},
              onBookmark: () {},
              onOpenDetail: () {},
              onBookingCta: () {},
              onShopProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('박지성'), findsOneWidget);
    expect(find.textContaining('NCT DREAM 클리닉'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(FeedMediaCarousel), findsOneWidget);
    expect(find.byType(FeedExpandableCaption), findsOneWidget);
  });

  testWidgets('더보기 expands caption inline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: FeedExpandableCaption(
              text:
                  '첫번째 줄 본문입니다.\n두번째 줄도 충분히 깁니다.\n세번째 줄은 접혀 있어야 합니다.\n네번째도 있습니다.',
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('더보기'), findsOneWidget);
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('접기'), findsOneWidget);
  });
}
