import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_tokens.dart';
import 'package:sori/widgets/feed_expandable_caption.dart';
import 'package:sori/widgets/floating_pill_nav.dart';
import 'package:sori/widgets/home_feed_card.dart';
import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';

void main() {
  test('Phase 9 tokens: pure black canvas and mint accent', () {
    expect(SoriTokens.background, const Color(0xFF000000));
    expect(SoriTokens.surface, const Color(0xFF1A1A1A));
    expect(SoriTokens.surfaceElevated, const Color(0xFF222222));
    expect(SoriTokens.primary, const Color(0xFF3EE0C5));
    expect(SoriTokens.textPrimary, const Color(0xFFFFFFFF));
    expect(SoriTokens.textSecondary.a, closeTo(0xB3 / 255, 0.01));
    expect(SoriTokens.textTertiary.a, closeTo(0x73 / 255, 0.01));
  });

  test('card decoration has no border or shadow', () {
    final d = SoriTokens.card();
    expect(d.border, isNull);
    expect(d.boxShadow == null || d.boxShadow!.isEmpty, isTrue);
    expect(d.color, SoriTokens.surface);
  });

  testWidgets('FloatingPillNav uses white active icons not mint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: FloatingPillNav(
            currentIndex: 0,
            isDirector: true,
            reviewLabel: '리뷰',
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    expect(icon.color, SoriTokens.textPrimary);
  });

  testWidgets('더보기 link uses mint accent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: FeedExpandableCaption(
              text: 'line1\nline2\nline3\nline4 overflow body text here',
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final more = tester.widget<Text>(find.text('더보기'));
    expect(more.style?.color, SoriTokens.primary);
  });

  testWidgets('HomeFeedCard paints surface without purple outline',
      (tester) async {
    final item = CommunityCaseItem(
      chart: CustomerChart(
        id: 't1',
        shopId: 's1',
        customerId: 'c',
        visitNumber: 1,
        careName: '테스트 케어',
        beforeImageUrl: 'https://picsum.photos/seed/theme-b/200/200',
        afterImageUrl: 'https://picsum.photos/seed/theme-a/200/200',
        createdAt: DateTime.now(),
      ),
      shop: const Shop(
        id: 's1',
        name: '테스트샵',
        naverPlaceUrl: '',
        ownerName: '원장',
      ),
      authorNickname: '닉네임',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: SoriTokens.background,
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

    expect(find.text('닉네임'), findsOneWidget);
    expect(find.textContaining('테스트샵'), findsOneWidget);

    var foundSurface = false;
    for (final el in find.byType(Container).evaluate()) {
      final w = el.widget;
      if (w is! Container) continue;
      final d = w.decoration;
      if (d is BoxDecoration && d.color == SoriTokens.surface) {
        foundSurface = true;
        expect(d.border, isNull);
        expect(d.boxShadow == null || d.boxShadow!.isEmpty, isTrue);
        break;
      }
    }
    expect(foundSurface, isTrue);
  });
}
