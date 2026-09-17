import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/category_presentation_map.dart';
import 'package:sori/views/unified_home_feed_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home surface shows 추천 글 and 게시물 보기 chrome', (tester) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.home,
          onSelectTab: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(CategoryPresentationMap.recommendFeed), findsWidgets);
    expect(find.text(CategoryPresentationMap.viewPost), findsWidgets);
    expect(find.text('탐색'), findsNothing);
    expect(find.text('우리 지역'), findsNothing);
  });
}
