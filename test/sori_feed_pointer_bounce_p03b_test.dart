import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feed and explore lists do not use custom scroll position or physics', () {
    expect(File('lib/utils/sori_feed_scroll_physics.dart').existsSync(), isFalse);

    final feed = File('lib/views/unified_home_feed_page.dart').readAsStringSync();
    expect(feed.contains('SoriFeedScrollPosition'), isFalse);
    expect(feed.contains('SoriFeedScrollController'), isFalse);
    expect(feed.contains('soriFeedScrollPhysics'), isFalse);
    expect(feed.contains("key: const Key('feed-recommend-refresh')"), isTrue);

    final explore = File('lib/views/home_explore_tab.dart').readAsStringSync();
    expect(explore.contains('SoriFeedScroll'), isFalse);
    expect(explore.contains('soriFeedScrollPhysics'), isFalse);
    expect(explore.contains('RefreshIndicator'), isTrue);
    expect(explore.contains('HomeExploreSearch'), isTrue);
    expect(explore.contains('ChoiceChip('), isTrue);
    expect(explore.contains('bool get wantKeepAlive => true'), isTrue);
  });

  test('Visit, Timer, Consent, Map sources have no custom feed scroll', () {
    for (final path in [
      'lib/features/visit/visit_session_page.dart',
      'lib/features/visit/widgets/home_timer_stage.dart',
      'lib/views/community/region_nearby_map_section.dart',
      'lib/views/community/region_map_explore_sheet.dart',
      'lib/main.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('SoriFeedScroll'), isFalse, reason: path);
      expect(src.contains('soriFeedScrollPhysics'), isFalse, reason: path);
    }
  });

  test('FlutterMap tile source and gestures are unchanged', () {
    final map = File(
      'lib/views/community/region_nearby_map_section.dart',
    ).readAsStringSync();
    expect(map.contains('FlutterMap('), isTrue);
    expect(map.contains('interactionOptions: const InteractionOptions('), isTrue);
    expect(map.contains('urlTemplate:'), isTrue);
    expect(map.contains('RefreshIndicator'), isFalse);

    final global = File('lib/widgets/app_scroll_behavior.dart').readAsStringSync();
    expect(global.contains('dragDevices'), isTrue);
    expect(global.contains('ClampingScrollPhysics'), isFalse);
    expect(global.contains('AlwaysScrollableScrollPhysics'), isFalse);
    expect(global.contains('getScrollPhysics'), isFalse);
  });

  test('SoriStore.refreshUnifiedCommunityFeed still accepts force', () {
    final src = File('lib/services/sori_store.dart').readAsStringSync();
    expect(src.contains('refreshUnifiedCommunityFeed({bool force = false})'), isTrue);
  });
}
