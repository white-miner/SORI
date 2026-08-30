import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/sori_tokens.dart';
import 'package:sori/widgets/glass/sori_glass_action_dock.dart';
import 'package:sori/widgets/glass/sori_glass_chip.dart';
import 'package:sori/widgets/glass/sori_glass_fab.dart';
import 'package:sori/widgets/glass/sori_glass_tokens.dart';
import 'package:sori/widgets/post/post_action_row.dart';
import 'package:sori/widgets/post/post_read_more_link.dart';
import 'package:sori/widgets/post/post_view_data.dart';
import 'package:sori/widgets/post/sori_post_mini.dart';

void main() {
  testWidgets('SoriGlassActionDock renders semantic chips with min touch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoriGlassActionDock(
            likeCount: 3,
            commentCount: 2,
            liked: true,
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

    expect(find.byType(SoriGlassChip), findsWidgets);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

    final chips = tester.widgetList<SoriGlassChip>(find.byType(SoriGlassChip));
    for (final chip in chips) {
      expect(chip.size, greaterThanOrEqualTo(SoriGlassTokens.chipSm));
    }
  });

  testWidgets('PostActionRow delegates to glass dock without black filled buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostActionRow(
            likeCount: 1,
            commentCount: 0,
            liked: false,
            bookmarked: false,
            onLike: () {},
            onComment: () {},
            onBookmark: () {},
            onMentoring: () {},
            onBoost: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SoriGlassActionDock), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byWidgetPredicate(
      (w) => w is Material && w.color == SoriTokens.primary,
    ), findsNothing);
  });

  testWidgets('SoriGlassFab uses accent send chip not solid black', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoriGlassFab(onPressed: () {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
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
    expect(linkSpan!.style?.color, kPostReadMoreBlue);
    expect(linkSpan!.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('SoriPostMini glass dock fits 320px without overflow', (tester) async {
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

    for (final width in [320.0, 1920.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: SoriPostMini(
                data: data('긴 본문 '.padRight(80, '가')),
                store: store,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
