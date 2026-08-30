import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/widgets/explore/explore_rich_info_card.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
  });

  Future<void> pumpExplore(WidgetTester tester, {double width = 390}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeExploreTab(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
  }

  testWidgets('browse mode renders 2-column rich info grid', (tester) async {
    await pumpExplore(tester);

    expect(find.byType(SliverGrid), findsOneWidget);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.crossAxisSpacing, 14);
    expect(delegate.mainAxisSpacing, 14);
    expect(delegate.childAspectRatio, closeTo(4 / 5, 0.001));

    expect(find.byType(ExploreRichInfoCard), findsWidgets);
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
