import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/visit/visit_session_page.dart';
import 'package:sori/features/visit/widgets/home_timer_stage.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_feed_scroll_physics.dart';
import 'package:sori/utils/sori_shell_insets.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/views/unified_home_feed_page.dart';
import 'package:sori/widgets/floating_pill_nav.dart';

const _viewPad = 34.0;
const _phone = Size(390, 844);

class _FeedRefreshSpyStore extends SoriStore {
  int refreshForceTrue = 0;

  @override
  Future<void> refreshUnifiedCommunityFeed({bool force = false}) async {
    if (force) refreshForceTrue++;
    await super.refreshUnifiedCommunityFeed(force: force);
  }
}

Widget _shell({required Widget child}) {
  return MaterialApp(
    builder: (context, appChild) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          size: _phone,
          viewPadding: const EdgeInsets.only(bottom: _viewPad),
          padding: const EdgeInsets.only(bottom: _viewPad),
        ),
        child: SoriShellInsetScope(
          pillNavVisible: true,
          child: appChild!,
        ),
      );
    },
    home: Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: FloatingPillNav(
        currentIndex: 0,
        isDirector: false,
        reviewLabel: '리뷰',
        onTap: (_) {},
      ),
    ),
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

ScrollableState _verticalScrollable(Finder root) {
  for (final el in find
      .descendant(of: root, matching: find.byType(Scrollable))
      .evaluate()) {
    final widget = el.widget;
    if (widget is Scrollable && widget.axis == Axis.vertical) {
      return (el as StatefulElement).state as ScrollableState;
    }
  }
  fail('no vertical Scrollable under $root');
}

Future<void> _sendPointerScroll(
  WidgetTester tester, {
  required Offset location,
  required double dy,
}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(location));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'pointer path at max exceeds extent, caps at +80, then ballistically returns',
    (tester) async {
      final controller = SoriFeedScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 400,
            child: SoriFeedScrollSurface(
              controller: controller,
              child: ListView(
                controller: controller,
                physics: soriFeedScrollPhysics,
                children: [
                  for (var i = 0; i < 24; i++)
                    SizedBox(
                      height: 80,
                      child: Text('row-$i', key: Key('row-$i')),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final pos = controller.position;
      expect(pos, isA<SoriFeedScrollPosition>());
      expect(pos.maxScrollExtent, greaterThan(0));
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
      final max = pos.maxScrollExtent;

      await _sendPointerScroll(
        tester,
        location: tester.getCenter(find.byType(ListView)),
        dy: 50,
      );
      expect(pos.pixels, greaterThan(max));
      expect(pos.pixels, lessThanOrEqualTo(max + kSoriFeedMaxOvershoot));

      await _sendPointerScroll(
        tester,
        location: tester.getCenter(find.byType(ListView)),
        dy: 200,
      );
      expect(pos.pixels, closeTo(max + kSoriFeedMaxOvershoot, 0.01));

      await tester.pump(kSoriFeedPointerSettle);
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect((pos.pixels - max).abs(), lessThan(1.0));
    },
  );

  testWidgets('pointer path at min overshoots by at most 80 then returns', (
    tester,
  ) async {
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 400,
          child: SoriFeedScrollSurface(
            controller: controller,
            child: ListView(
              controller: controller,
              physics: soriFeedScrollPhysics,
              children: [
                for (var i = 0; i < 24; i++)
                  SizedBox(height: 80, child: Text('row-$i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pos = controller.position;
    pos.jumpTo(pos.minScrollExtent);
    await tester.pump();
    final min = pos.minScrollExtent;

    await _sendPointerScroll(
      tester,
      location: tester.getCenter(find.byType(ListView)),
      dy: -200,
    );
    expect(pos.pixels, lessThan(min));
    expect(pos.pixels, greaterThanOrEqualTo(min - kSoriFeedMaxOvershoot));

    pos.pointerScroll(0);
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect((pos.pixels - min).abs(), lessThan(1.0));
  });

  testWidgets(
    'last keyed card global Y moves farther from bottom nav then returns',
    (tester) async {
      final controller = SoriFeedScrollController();
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 400,
            child: Stack(
              children: [
                SoriFeedScrollSurface(
                  controller: controller,
                  child: ListView(
                    controller: controller,
                    physics: soriFeedScrollPhysics,
                    children: [
                      for (var i = 0; i < 16; i++)
                        SizedBox(
                          height: 80,
                          child: Text(
                            'row-$i',
                            key: i == 15 ? const Key('last-card') : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    key: Key('fake-pill-nav'),
                    height: 64,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final pos = controller.position;
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();

      final nav = tester.getRect(find.byKey(const Key('fake-pill-nav')));
      final rest = tester.getRect(find.byKey(const Key('last-card')));
      final restGap = nav.top - rest.bottom;
      final restMax = pos.maxScrollExtent;

      pos.pointerScroll(60);
      await tester.pump();

      expect(pos.pixels, greaterThan(restMax));
      expect(pos.pixels, lessThanOrEqualTo(restMax + kSoriFeedMaxOvershoot));
      final bounced = tester.getRect(find.byKey(const Key('last-card')));
      expect(nav.top - bounced.bottom, greaterThan(restGap));
      expect(bounced.bottom, lessThan(rest.bottom));

      pos.pointerScroll(0);
      await tester.pump();
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect((pos.pixels - pos.maxScrollExtent).abs(), lessThan(1.0));
    },
  );

  testWidgets('home recommend uses feed position and bottom overshoot does not refresh', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;

    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: UnifiedHomeFeedPage(store: store, surface: FeedSurface.home),
      ),
    );
    await _pumpFrames(tester);

    final scrollRoot = find.byKey(const Key('feed-recommend-scroll'));
    final pos = _verticalScrollable(scrollRoot).position;
    expect(pos, isA<SoriFeedScrollPosition>());
    expect(find.byKey(const Key('feed-recommend-refresh')), findsOneWidget);

    if (pos.maxScrollExtent > 0) {
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
    }
    await tester.fling(scrollRoot, const Offset(0, -280), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _drain(tester);
    expect(store.refreshForceTrue, 0);
  });

  testWidgets('top drag on feed physics RefreshIndicator fires once', (
    tester,
  ) async {
    var calls = 0;
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 400,
            child: RefreshIndicator(
              onRefresh: () async {
                calls++;
              },
              child: SoriFeedScrollSurface(
                controller: controller,
                child: ListView(
                  controller: controller,
                  physics: soriFeedScrollPhysics,
                  children: [
                    for (var i = 0; i < 12; i++)
                      SizedBox(height: 80, child: Text('row-$i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
  });

  testWidgets('top drag calls refresh force true once; bottom drag does not', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;

    await tester.binding.setSurfaceSize(_phone);
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

    final scrollRoot = find.byKey(const Key('feed-recommend-scroll'));
    final pos = _verticalScrollable(scrollRoot).position;
    pos.jumpTo(0);
    await tester.pump();

    final refresh = find.byKey(const Key('feed-recommend-refresh'));
    expect(refresh, findsOneWidget);
    await tester.widget<RefreshIndicator>(refresh).onRefresh();
    await _pumpFrames(tester);
    expect(store.refreshForceTrue, 1);

    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
    await tester.fling(scrollRoot, const Offset(0, -280), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _drain(tester);
    expect(store.refreshForceTrue, 1);
  });

  testWidgets('explore keeps PTR, query, category chips, KeepAlive, bounce', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        child: HomeExploreTab(store: store, scrollController: controller),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester
          .widget<CustomScrollView>(
            find.byKey(const Key('explore-browse-scroll')),
          )
          .physics,
      isA<BouncingScrollPhysics>(),
    );
    expect(controller.position, isA<SoriFeedScrollPosition>());

    final src = File('lib/views/home_explore_tab.dart').readAsStringSync();
    expect(src.contains('AutomaticKeepAliveClientMixin'), isTrue);
    expect(src.contains('bool get wantKeepAlive => true'), isTrue);
    expect(src.contains('HomeExploreSearch'), isTrue);
    expect(
      src.contains('store.refreshUnifiedCommunityFeed(force: true)'),
      isTrue,
    );
  });

  test('local list has bounce SSOT and no RefreshIndicator', () {
    final src = File('lib/views/unified_home_feed_page.dart').readAsStringSync();
    expect(src.contains("key: const Key('feed-local-scroll')"), isTrue);
    expect(src.contains('soriFeedScrollPhysics'), isTrue);
    expect(src.contains('SoriFeedScrollSurface'), isTrue);
    expect(src.contains('RegionNearbyMapSection('), isTrue);
    expect('RefreshIndicator'.allMatches(src).length, 1);
  });

  testWidgets('VisitSession, Consent, Timer have no feed bounce or PTR', (
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
    expect(find.byType(SoriFeedScrollSurface), findsNothing);
    expect(
      find.byKey(const Key('visit-consent-action-pad'), skipOffstage: false),
      findsOneWidget,
    );

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
    expect(find.byType(SoriFeedScrollSurface), findsNothing);

    for (final path in [
      'lib/features/visit/visit_session_page.dart',
      'lib/features/visit/widgets/home_timer_stage.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('SoriFeedScrollBehavior'), isFalse, reason: path);
      expect(src.contains('SoriFeedScrollSurface'), isFalse, reason: path);
      expect(src.contains('RefreshIndicator'), isFalse, reason: path);
    }
  });

  test('FlutterMap tile source, constraints, and gestures are unchanged', () {
    final map = File(
      'lib/views/community/region_nearby_map_section.dart',
    ).readAsStringSync();
    expect(map.contains('SoriFeedScroll'), isFalse);
    expect(map.contains('RefreshIndicator'), isFalse);
    expect(map.contains('FlutterMap('), isTrue);
    expect(map.contains('interactionOptions: const InteractionOptions('), isTrue);
    expect(map.contains('urlTemplate:'), isTrue);

    final sheet = File(
      'lib/views/community/region_map_explore_sheet.dart',
    ).readAsStringSync();
    expect(sheet.contains('SoriFeedScroll'), isFalse);

    final tiles = File(
      'lib/views/community/region_map_tile_candidates.dart',
    ).readAsStringSync();
    expect(tiles.contains('SoriFeedScroll'), isFalse);

    final global = File('lib/widgets/app_scroll_behavior.dart').readAsStringSync();
    expect(global.contains('SoriFeedScrollBehavior'), isFalse);
    expect(global.contains('ClampingScrollPhysics'), isTrue);

    final mainSrc = File('lib/main.dart').readAsStringSync();
    expect(mainSrc.contains('SoriFeedScroll'), isFalse);
  });

  test('feed overscroll indicator returns child; no stretch/glow widgets', () {
    final physics = File(
      'lib/utils/sori_feed_scroll_physics.dart',
    ).readAsStringSync();
    expect(physics.contains('StretchingOverscrollIndicator'), isFalse);
    expect(physics.contains('GlowingOverscrollIndicator'), isFalse);
    expect(
      physics.contains('Widget buildOverscrollIndicator'),
      isTrue,
    );
    expect(RegExp(r'return child;').hasMatch(physics), isTrue);
  });
}
