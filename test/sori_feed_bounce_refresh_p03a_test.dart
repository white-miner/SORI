import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/visit/visit_session_page.dart';
import 'package:sori/features/visit/widgets/home_timer_stage.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_shell_insets.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/views/unified_home_feed_page.dart';

const _viewPad = 34.0;

class _FeedRefreshSpyStore extends SoriStore {
  int refreshForceTrue = 0;
  int refreshForceFalse = 0;

  @override
  Future<void> refreshUnifiedCommunityFeed({bool force = false}) async {
    if (force) {
      refreshForceTrue++;
    } else {
      refreshForceFalse++;
    }
    await super.refreshUnifiedCommunityFeed(force: force);
  }
}

void expectNoCustomFeedPhysics(ScrollPhysics? physics) {
  expect(physics, isNot(isA<BouncingScrollPhysics>()));
}

Widget _shell({
  required Widget child,
  Size size = const Size(390, 844),
}) {
  return MaterialApp(
    builder: (context, appChild) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          size: size,
          viewPadding: const EdgeInsets.only(bottom: _viewPad),
          padding: const EdgeInsets.only(bottom: _viewPad),
        ),
        child: SoriShellInsetScope(
          pillNavVisible: true,
          child: appChild!,
        ),
      );
    },
    home: child,
  );
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    tester.takeException();
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  await _drain(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('global scroll behavior keeps dragDevices and does not force Clamping', () {
    final src = File('lib/widgets/app_scroll_behavior.dart').readAsStringSync();
    expect(src.contains('dragDevices'), isTrue);
    expect(src.contains('ClampingScrollPhysics'), isFalse);
    expect(src.contains('AlwaysScrollableScrollPhysics'), isFalse);
    expect(src.contains('getScrollPhysics'), isFalse);
    expect(File('lib/utils/sori_feed_scroll_physics.dart').existsSync(), isFalse);
  });

  testWidgets('home recommend inherits platform physics and keeps RefreshIndicator', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;
    store.refreshForceFalse = 0;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.home,
        ),
      ),
    );
    await _pumpFrames(tester);

    final scroll = tester.widget<CustomScrollView>(
      find.byKey(const Key('feed-recommend-scroll')),
    );
    expectNoCustomFeedPhysics(scroll.physics);
    expect(find.byKey(const Key('feed-recommend-refresh')), findsOneWidget);

    final pad = tester.widget<SliverPadding>(
      find.byKey(const Key('feed-recommend-list-padding'), skipOffstage: false),
    );
    expect((pad.padding as EdgeInsets).bottom, 8 + (64 + 12 + _viewPad + 20));
  });

  testWidgets('community recommend PTR calls refresh force true', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;
    store.refreshForceFalse = 0;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.community,
        ),
      ),
    );
    await _pumpFrames(tester);

    expectNoCustomFeedPhysics(
      tester
          .widget<CustomScrollView>(
            find.byKey(const Key('feed-recommend-scroll')),
          )
          .physics,
    );

    final before = store.refreshForceTrue;
    final indicator = tester.widget<RefreshIndicator>(
      find.byKey(const Key('feed-recommend-refresh')),
    );
    await indicator.onRefresh();
    await _pumpFrames(tester);
    expect(store.refreshForceTrue, before + 1);
  });

  testWidgets('bottom overscroll does not call recommend refresh', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.home,
        ),
      ),
    );
    await _pumpFrames(tester);

    final scrollFinder = find.byKey(const Key('feed-recommend-scroll'));
    final pos = tester.state<ScrollableState>(
      find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
    ).position;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();

    final before = store.refreshForceTrue;
    await tester.fling(scrollFinder, const Offset(0, -280), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _drain(tester);
    expect(store.refreshForceTrue, before);
  });

  test('local tab inherits platform physics and has no RefreshIndicator', () {
    final src = File('lib/views/unified_home_feed_page.dart').readAsStringSync();
    expect(src.contains("key: const Key('feed-local-scroll')"), isTrue);
    expect(src.contains('soriFeedScrollPhysics'), isFalse);
    expect(src.contains('SoriFeedScroll'), isFalse);
    expect(src.contains('RegionNearbyMapSection('), isTrue);
    expect('RefreshIndicator'.allMatches(src).length, 1);
    expect(src.contains("key: const Key('feed-recommend-refresh')"), isTrue);
  });

  testWidgets('explore keeps RefreshIndicator and inherits platform physics', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: Scaffold(
          body: HomeExploreTab(
            store: store,
            scrollController: ScrollController(),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expectNoCustomFeedPhysics(
      tester
          .widget<CustomScrollView>(
            find.byKey(const Key('explore-browse-scroll')),
          )
          .physics,
    );
  });

  testWidgets('VisitSession and Timer have no feed RefreshIndicator', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.pumpWidget(
      _shell(
        child: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byKey(const Key('visit-consent-action-pad'), skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(
      _shell(
        child: HomeTimerStage(
          onExpandFullscreen: () {},
          onCareStart: () {},
          onCareEnd: () {},
          onOpenPresetEditor: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
