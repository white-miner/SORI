import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
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

  testWidgets('PostTruncatedCaption uses blue bold TextSpan for read more', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: PostTruncatedCaption(
              key: const Key('caption'),
              text: '긴 본문입니다. '.padRight(120, '가'),
              maxLines: 2,
              onReadMore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const Key('caption')),
        matching: find.byType(RichText),
      ),
    );
    TextSpan? linkSpan;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text?.contains(kPostReadMoreLabel) == true &&
            span.recognizer != null) {
          linkSpan = span;
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    walk(rich.text);
    expect(linkSpan, isNotNull);
    expect(linkSpan!.text, contains(kPostReadMoreLabel));
    expect(linkSpan!.style?.color, kPostReadMoreBlue);
    expect(linkSpan!.style?.fontWeight, FontWeight.bold);
    expect(linkSpan!.recognizer, isA<TapGestureRecognizer>());
    expect(find.textContaining('_더 보기'), findsNothing);
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
          body: SizedBox(
            width: 320,
            child: Column(
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
      ),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    final shortCard = tester.getRect(find.byKey(const Key('short-mini')));
    final longCard = tester.getRect(find.byKey(const Key('long-mini')));
    final shortAction = tester.getRect(find.descendant(
      of: find.byKey(const Key('short-mini')),
      matching: find.byType(PostActionRow),
    ));

    expect(longCard.height, greaterThan(shortCard.height));
    expect(shortCard.bottom - shortAction.bottom, lessThan(14));
    expect(find.textContaining(kPostReadMoreLabel), findsOneWidget);
  });
}
