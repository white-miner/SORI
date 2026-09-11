import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/unified_feed_engine.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/widgets/explore/explore_rich_info_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoriStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SoriStore(repository: MemorySoriRepository());
    await store.refreshUnifiedCommunityFeed(force: true);
    expect(UnifiedFeedEngine.exploreGridItems(store), isNotEmpty);
  });

  Future<ScrollController> pumpExplore(
    WidgetTester tester, {
    double width = 390,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeExploreTab(
            store: store,
            scrollController: scrollController,
          ),
        ),
      ),
    );
    await tester.pump();
    await store.refreshUnifiedCommunityFeed(force: true);
    for (var i = 0; i < 30; i++) {
      if (!store.unifiedFeedLoading) break;
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    while (tester.takeException() != null) {}
    return scrollController;
  }

  testWidgets('browse mode renders 2-column rich info grid', (tester) async {
    const width = 390.0;
    final scrollController = await pumpExplore(tester, width: width);

    expect(find.text('아직 탐색할 콘텐츠가 없어요'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('전체'), findsWidgets);
    expect(find.byType(CustomScrollView), findsOneWidget);
    final gridItems = UnifiedFeedEngine.exploreGridItems(store);
    expect(gridItems, isNotEmpty);
    expect(find.byType(ExploreRichInfoCard), findsWidgets);

    // Main grid sits below habit rails — jump scroll to materialize grid tiles.
    if (scrollController.hasClients) {
      final maxExtent = scrollController.position.maxScrollExtent;
      scrollController.jumpTo(maxExtent > 0 ? maxExtent * 0.35 : 800);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    while (tester.takeException() != null) {}

    const expectedGridCardWidth = (width - 32 - 14) / 2;
    final wideRects = <Rect>[];
    for (final element in find.byType(ExploreRichInfoCard).evaluate()) {
      final finder = find.byWidget(element.widget);
      if (finder.evaluate().isEmpty) continue;
      late Rect rect;
      try {
        rect = tester.getRect(finder);
      } catch (_) {
        continue;
      }
      if (rect.width > 160) wideRects.add(rect);
    }
    expect(
      wideRects.length,
      greaterThanOrEqualTo(2),
      reason: 'browse grid cards should be wider than 148px habit-rail tiles',
    );
    wideRects.sort((a, b) => a.top.compareTo(b.top));
    expect(wideRects.first.width, closeTo(expectedGridCardWidth, 12));
    expect(
      (wideRects[0].top - wideRects[1].top).abs(),
      lessThan(4),
      reason: 'first grid row should place two cards side by side',
    );
    expect(
      wideRects.first.height / wideRects.first.width,
      closeTo(5 / 4, 0.12),
    );
  });

  testWidgets('rich card keeps long title within two lines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: ExploreRichInfoCard(
                imageUrl: '',
                title: '아주 긴 제목 '.padRight(40, '가'),
                subtitle: '본문 요약 한 줄',
                authorName: '김원장',
                authorAvatarUrl: '',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(ExploreRichInfoCard),
        matching: find.textContaining('아주 긴 제목'),
      ),
    );
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('scrim overlay uses black87 gradient for readable white text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreRichInfoCard(
            imageUrl: '',
            title: '제목',
            subtitle: '요약',
            authorName: '작성자',
            authorAvatarUrl: '',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gradient = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ExploreRichInfoCard),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final decoration = gradient.decoration! as BoxDecoration;
    final grad = decoration.gradient as LinearGradient;
    expect(grad.colors.first, Colors.transparent);
    expect(grad.colors.last, Colors.black87);

    final title = tester.widget<Text>(find.text('제목'));
    expect(title.style?.color, Colors.white);
  });
}
