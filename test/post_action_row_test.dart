import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/sori_tokens.dart';
import 'package:sori/widgets/post/post_action_row.dart';
import 'package:sori/widgets/post/post_read_more_link.dart';
import 'package:sori/widgets/post/post_view_data.dart';
import 'package:sori/widgets/post/sori_post_mini.dart';

void main() {
  testWidgets('PostActionRow shows like comment mentoring boost icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostActionRow(
            likeCount: 3,
            commentCount: 2,
            liked: false,
            bookmarked: false,
            mentoringActive: true,
            isBoosted: true,
            onLike: () {},
            onComment: () {},
            onBookmark: () {},
            onMentoring: () {},
            onBoost: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });

  testWidgets('SoriPostMini wraps content with tight bottom spacing', (tester) async {
    final store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());

    PostViewData data(String body) => PostViewData(
          id: 'p-$body',
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
          body: Column(
            children: [
              SoriPostMini(
                key: const Key('short-mini'),
                data: data('짧은 본문'),
                store: store,
              ),
              SoriPostMini(
                key: const Key('long-mini'),
                data: data(
                  '긴 본문입니다. '.padRight(120, '가'),
                ),
                store: store,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final shortCard = tester.getRect(find.byKey(const Key('short-mini')));
    final longCard = tester.getRect(find.byKey(const Key('long-mini')));
    final shortAction = tester.getRect(find.descendant(
      of: find.byKey(const Key('short-mini')),
      matching: find.byType(PostActionRow),
    ));

    expect(longCard.height, greaterThan(shortCard.height));
    expect(shortCard.bottom - shortAction.bottom, lessThan(14));
    expect(find.text('더 보기'), findsOneWidget);
    expect(find.textContaining('_더 보기'), findsNothing);
  });

  test('PostReadMoreLink uses accent link color', () {
    expect(SoriTokens.accentLink, const Color(0xFF007AFF));
  });
}
