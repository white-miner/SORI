import 'dart:io';

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
import 'package:sori/widgets/app_scroll_behavior.dart';

class _FeedRefreshSpyStore extends SoriStore {
  int refreshForceTrue = 0;

  @override
  Future<void> refreshUnifiedCommunityFeed({bool force = false}) async {
    if (force) refreshForceTrue++;
    await super.refreshUnifiedCommunityFeed(force: force);
  }
}

Widget _app({required Widget child}) {
  return MaterialApp(
    scrollBehavior: const SoriScrollBehavior(),
    home: SoriShellInsetScope(
      pillNavVisible: true,
      child: child,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pointerScroll can pass max extent but not beyond +80', (
    tester,
  ) async {
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        child: ScrollConfiguration(
          behavior: const SoriFeedScrollBehavior(),
          child: CustomScrollView(
            controller: controller,
            physics: soriFeedScrollPhysics,
            slivers: [
              SliverList.builder(
                itemCount: 20,
                itemBuilder: (_, i) => SizedBox(
                  height: 90,
                  child: Text('row-$i', key: i == 19 ? const Key('last-card') : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final pos = controller.position as SoriFeedScrollPosition;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
    final restY = tester.getTopLeft(find.byKey(const Key('last-card'))).dy;

    pos.pointerScroll(120);
    await tester.pump();

    expect(pos.pixels, greaterThan(pos.maxScrollExtent));
    expect(pos.pixels, lessThanOrEqualTo(pos.maxScrollExtent + kSoriFeedMaxOvershoot));
    expect(
      tester.getTopLeft(find.byKey(const Key('last-card'))).dy,
      lessThan(restY),
    );

    await tester.pumpAndSettle();
    expect(pos.pixels, closeTo(pos.maxScrollExtent, 0.5));
  });

  testWidgets('pointerScroll top overshoot is capped at 80 and ballistics back', (
    tester,
  ) async {
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        child: ScrollConfiguration(
          behavior: const SoriFeedScrollBehavior(),
          child: CustomScrollView(
            controller: controller,
            physics: soriFeedScrollPhysics,
            slivers: [
              SliverList.builder(
                itemCount: 20,
                itemBuilder: (_, i) => SizedBox(height: 90, child: Text('row-$i')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final pos = controller.position as SoriFeedScrollPosition;
    pos.pointerScroll(-120);
    await tester.pump();
    expect(pos.pixels, lessThan(pos.minScrollExtent));
    expect(pos.pixels, greaterThanOrEqualTo(pos.minScrollExtent - kSoriFeedMaxOvershoot));
    await tester.pumpAndSettle();
    expect(pos.pixels, closeTo(pos.minScrollExtent, 0.5));
  });

  testWidgets('recommend PTR is top-only; bottom pointerScroll does not refresh', (
    tester,
  ) async {
    final store = _FeedRefreshSpyStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    store.refreshForceTrue = 0;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        child: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.home,
        ),
      ),
    );
    await _pumpFrames(tester);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('feed-recommend-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position, isA<SoriFeedScrollPosition>());
    final pos = scrollable.position as SoriFeedScrollPosition;

    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
    final beforeBottom = store.refreshForceTrue;
    pos.pointerScroll(80);
    await tester.pump();
    expect(store.refreshForceTrue, beforeBottom);
    expect(pos.pixels, greaterThan(pos.maxScrollExtent));
    expect(
      pos.pixels,
      lessThanOrEqualTo(pos.maxScrollExtent + kSoriFeedMaxOvershoot),
    );
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();

    final beforeTop = store.refreshForceTrue;
    final indicator = tester.widget<RefreshIndicator>(
      find.byKey(const Key('feed-recommend-refresh')),
    );
    await indicator.onRefresh();
    await _pumpFrames(tester);
    expect(store.refreshForceTrue, beforeTop + 1);
  });

  test('local tab has bounce controller path and no RefreshIndicator', () {
    final src = File('lib/views/unified_home_feed_page.dart').readAsStringSync();
    expect(src.contains('SoriFeedScrollController'), isTrue);
    expect(src.contains('SoriFeedScrollBehavior'), isTrue);
    expect(src.contains("key: const Key('feed-local-scroll')"), isTrue);
    expect('RefreshIndicator'.allMatches(src).length, 1);
    expect(src.contains('RegionNearbyMapSection('), isTrue);
  });

  testWidgets('explore keeps PTR and uses feed controller when provided', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    final controller = SoriFeedScrollController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        child: Scaffold(
          body: HomeExploreTab(
            store: store,
            scrollController: controller,
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(controller.position, isA<SoriFeedScrollPosition>());
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('VisitSession and Timer have no feed position or PTR', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.pumpWidget(
      _app(
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
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ScrollConfiguration && w.behavior is SoriFeedScrollBehavior,
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      _app(
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
