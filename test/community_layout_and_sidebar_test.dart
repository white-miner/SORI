import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/community_page.dart';
import 'package:sori/widgets/post/post_action_row.dart';
import 'package:sori/widgets/post/post_interaction_sidebar.dart';
import 'package:sori/widgets/post/post_view_data.dart';
import 'package:sori/widgets/post/sori_post_mini.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
  });

  testWidgets('community tab orders recent posts before community headline',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPage(store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    while (tester.takeException() != null) {}

    expect(find.text('최근 게시물'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);

    final recentY = tester.getTopLeft(find.text('최근 게시물')).dy;
    final communityY = tester.getTopLeft(find.text('커뮤니티')).dy;
    expect(recentY, lessThan(communityY));
  });

  testWidgets('community filter chips show full labels without clipping',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPage(store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    while (tester.takeException() != null) {}

    for (final label in [
      '전체',
      '세미나',
      '기기리뷰',
      '샵 인테리어',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('community_filter_mentoring')), findsOneWidget);
    final mentoringChip = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('community_filter_mentoring')),
        matching: find.text('멘토링'),
      ),
    );
    expect(mentoringChip.overflow, TextOverflow.visible);
    expect(mentoringChip.softWrap, isFalse);
  });

  testWidgets('horizontal mini carousel cards share height and action baseline',
      (tester) async {
    PostViewData data(String body) => PostViewData(
          id: 'c-$body',
          kind: PostViewKind.whisper,
          sortAt: DateTime(2026, 1, 1),
          authorName: '원장',
          affiliation: 'SORI',
          categoryLabel: 'Whisper',
          bodyText: body,
          timeLabel: '1분 전',
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoriPostMini.horizontalStrip(
            children: [
              SoriPostMini(
                key: const Key('carousel-a'),
                data: data('짧'),
                store: store,
                horizontal: true,
              ),
              SoriPostMini(
                key: const Key('carousel-b'),
                data: data('긴 본문입니다. '.padRight(100, '가')),
                store: store,
                horizontal: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    final cardA = tester.getRect(find.byKey(const Key('carousel-a')));
    final cardB = tester.getRect(find.byKey(const Key('carousel-b')));
    final actionA = tester.getRect(find.descendant(
      of: find.byKey(const Key('carousel-a')),
      matching: find.byType(PostActionRow),
    ));
    final actionB = tester.getRect(find.descendant(
      of: find.byKey(const Key('carousel-b')),
      matching: find.byType(PostActionRow),
    ));

    expect(cardA.height, closeTo(SoriPostMini.carouselHeight, 1));
    expect(cardB.height, closeTo(SoriPostMini.carouselHeight, 1));
    expect(cardA.height, closeTo(cardB.height, 1));
    expect(actionA.bottom, closeTo(actionB.bottom, 1));
  });

  testWidgets('desktop comment sidebar uses glass panel and send icon',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostInteractionSidebar(
            data: PostViewData(
              id: 'p1',
              kind: PostViewKind.whisper,
              sortAt: DateTime(2026, 1, 1),
              authorName: '원장',
              affiliation: 'SORI',
              categoryLabel: 'Whisper',
              bodyText: '본문',
              timeLabel: '1분 전',
            ),
            store: store,
            postId: 'post-test',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PostInteractionSidebar), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.text('댓글을 입력하세요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
