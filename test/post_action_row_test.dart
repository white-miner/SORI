import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/widgets/post/post_action_row.dart';
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

  test('horizontal strip height is at least 240px per PO', () {
    expect(SoriPostMini.horizontalStripHeight, greaterThanOrEqualTo(240));
  });
}
