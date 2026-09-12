import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/features/visit/visit_session_page.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_shell_insets.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/views/shoot_hub_page.dart';
import 'package:sori/views/unified_home_feed_page.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';
import 'package:sori/widgets/explore/explore_rich_info_card.dart';
import 'package:sori/widgets/floating_pill_nav.dart';
import 'package:sori/widgets/post/sori_post_medium.dart';

const _viewPad = 34.0;
const _minClearance = 16.0;
const _phone = Size(390, 844);

Widget _shell({
  required Widget body,
  required bool isDirector,
  int tab = 0,
}) {
  return MaterialApp(
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          size: _phone,
          viewPadding: const EdgeInsets.only(bottom: _viewPad),
          padding: const EdgeInsets.only(bottom: _viewPad),
        ),
        child: child!,
      );
    },
    home: Scaffold(
      extendBody: true,
      body: SoriShellInsetScope(
        pillNavVisible: true,
        child: body,
      ),
      bottomNavigationBar: FloatingPillNav(
        currentIndex: tab,
        isDirector: isDirector,
        reviewLabel: '리뷰',
        onTap: (_) {},
      ),
    ),
  );
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    tester.takeException();
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  await _drain(tester);
}

ScrollableState? _verticalScrollable(Finder root) {
  for (final el in find
      .descendant(of: root, matching: find.byType(Scrollable))
      .evaluate()) {
    final widget = el.widget;
    if (widget is Scrollable && widget.axis == Axis.vertical) {
      return (el as StatefulElement).state as ScrollableState;
    }
  }
  return null;
}

Future<void> _jumpMax(WidgetTester tester, Finder scrollableRoot) async {
  for (var i = 0; i < 8; i++) {
    final state = _verticalScrollable(scrollableRoot);
    if (state == null) return;
    final pos = state.position;
    if (!pos.hasContentDimensions) return;
    if (pos.maxScrollExtent <= 0 ||
        (pos.pixels - pos.maxScrollExtent).abs() < 0.5) {
      return;
    }
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
    await _drain(tester);
  }
}

Rect? _bottomMost(WidgetTester tester, Finder ancestor, List<Type> types) {
  Rect? best;
  for (final type in types) {
    final finder = find.descendant(
      of: ancestor,
      matching: find.byWidgetPredicate((w) => w.runtimeType == type),
    );
    for (final el in finder.evaluate()) {
      final ro = el.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      if (ro.size.width < 1 || ro.size.height < 1) continue;
      final rect = ro.localToGlobal(Offset.zero) & ro.size;
      if (rect.top >= _phone.height || rect.bottom <= 0) continue;
      if (best == null || rect.bottom > best.bottom) best = rect;
    }
  }
  return best;
}

bool _hitsNav(WidgetTester tester, Offset global) {
  final result = tester.hitTestOnBinding(global);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    if (creator.element.findAncestorWidgetOfExactType<FloatingPillNav>() !=
        null) {
      return true;
    }
  }
  return false;
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await _drain(tester);
  await tester.pump(const Duration(milliseconds: 400));
  await _drain(tester);
}

Future<void> _expectReachable({
  required String name,
  required Rect last,
  required Rect nav,
  required WidgetTester tester,
}) async {
  final gap = nav.top - last.bottom;
  final probe = Offset(last.center.dx, last.bottom - 4);
  final stolen = _hitsNav(tester, probe);
  debugPrint(
    'REACH $name last.bottom=${last.bottom.toStringAsFixed(1)} '
    'nav.top=${nav.top.toStringAsFixed(1)} gap=${gap.toStringAsFixed(1)} '
    'hitNav=$stolen → ${gap >= _minClearance && !stolen ? "PASS" : "FAIL"}',
  );
  expect(gap, greaterThanOrEqualTo(_minClearance), reason: '$name clearance');
  expect(stolen, isFalse, reason: '$name nav must not steal last-element taps');
  await _finish(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppShell body SSOT keeps 16dp+ clearance over pill nav height', (
    tester,
  ) async {
    late double inset;
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(
        isDirector: false,
        body: SoriShellInsetScope(
          pillNavVisible: true,
          child: Builder(
            builder: (context) {
              inset = SoriShellInsets.scrollBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final nav = tester.getRect(find.byType(FloatingPillNav));
    expect(inset, nav.size.height + SoriShellInsets.contentClearance);
    expect(_phone.height - inset, lessThanOrEqualTo(nav.top - _minClearance));
  });

  test('PR #7 custom ScrollPosition is gone; PR #6 PTR keys remain', () {
    final physics = File(
      'lib/utils/sori_feed_scroll_physics.dart',
    ).readAsStringSync();
    expect(physics.contains('SoriFeedScrollPosition'), isFalse);
    expect(physics.contains('SoriFeedScrollController'), isFalse);
    expect(physics.contains('kSoriFeedMaxOvershoot'), isFalse);
    expect(physics.contains('void pointerScroll'), isFalse);
    expect(physics.contains('soriFeedScrollPhysics'), isTrue);

    final feed = File('lib/views/unified_home_feed_page.dart').readAsStringSync();
    expect(feed.contains('SoriFeedScrollController'), isFalse);
    expect(feed.contains('SoriFeedScrollBehavior'), isFalse);
    expect(feed.contains("key: const Key('feed-recommend-refresh')"), isTrue);
    expect('RefreshIndicator'.allMatches(feed).length, 1);
    expect('padding: _feedListPadding(context)'.allMatches(feed).length, 2);

    final explore = File('lib/views/home_explore_tab.dart').readAsStringSync();
    expect(explore.contains('SoriFeedScrollBehavior'), isFalse);
    expect(explore.contains('RefreshIndicator'), isTrue);
  });

  testWidgets('customer home recommend last card clears pill nav', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: false,
        body: UnifiedHomeFeedPage(store: store, surface: FeedSurface.home),
      ),
    );
    await _pumpFrames(tester);
    await _jumpMax(tester, find.byKey(const Key('feed-recommend-scroll')));

    final last = _bottomMost(tester, find.byType(UnifiedHomeFeedPage), [
      SoriPostMedium,
    ]);
    expect(last, isNotNull, reason: 'home recommend has a card');
    await _expectReachable(
      name: 'customer-home-recommend',
      last: last!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });

  testWidgets('community recommend last card clears pill nav', (tester) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: false,
        tab: 3,
        body: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.community,
        ),
      ),
    );
    await _pumpFrames(tester);
    await _jumpMax(tester, find.byKey(const Key('feed-recommend-scroll')));

    final last = _bottomMost(tester, find.byType(UnifiedHomeFeedPage), [
      SoriPostMedium,
    ]);
    expect(last, isNotNull, reason: 'community recommend has a card');
    await _expectReachable(
      name: 'community-recommend',
      last: last!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });

  testWidgets('explore grid last card clears pill nav', (tester) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: false,
        tab: 3,
        body: HomeExploreTab(
          store: store,
          scrollController: ScrollController(),
        ),
      ),
    );
    await _pumpFrames(tester);
    await _jumpMax(tester, find.byKey(const Key('explore-browse-scroll')));

    final last = _bottomMost(tester, find.byType(HomeExploreTab), [
      ExploreRichInfoCard,
    ]);
    expect(last, isNotNull, reason: 'explore grid has a card');
    await _expectReachable(
      name: 'explore-grid',
      last: last!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });

  testWidgets('ShootHub last control clears pill nav', (tester) async {
    final store = SoriStore();
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(isDirector: true, tab: 2, body: ShootHubPage(store: store)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await _drain(tester);
    await _jumpMax(tester, find.byKey(const Key('shoot-hub-list')));

    final last = _bottomMost(tester, find.byKey(const Key('shoot-hub-list')), [
      FilledButton,
      InkWell,
    ]);
    expect(last, isNotNull, reason: 'ShootHub has a control');
    await _expectReachable(
      name: 'shoot-hub',
      last: last!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });

  testWidgets('Visit Shoot/Consult/Plan last CTAs clear pill nav', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: true,
        tab: 2,
        body: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    Future<void> checkPhase(VisitPhase phase, String name) async {
      await store.visit.setPhase(session.id, phase);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final list = find.byKey(const Key('visit-phase-list'));
      expect(list, findsWidgets);
      await _jumpMax(tester, list.first);
      final last = _bottomMost(tester, list.first, [FilledButton]);
      expect(last, isNotNull, reason: '$name has a CTA');
      await _expectReachable(
        name: name,
        last: last!,
        nav: tester.getRect(find.byType(FloatingPillNav)),
        tester: tester,
      );
    }

    await checkPhase(VisitPhase.shoot, 'visit-shoot');
    await checkPhase(VisitPhase.consult, 'visit-consult');
    await checkPhase(VisitPhase.plan, 'visit-plan');
  });

  testWidgets('Consent and Hold fixed CTAs clear pill nav', (tester) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: true,
        tab: 2,
        body: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await store.visit.setPhase(session.id, VisitPhase.consent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final consentBtn = _bottomMost(
      tester,
      find.byKey(const Key('visit-consent-action-pad')),
      [FilledButton],
    );
    expect(consentBtn, isNotNull);
    await _expectReachable(
      name: 'visit-consent-cta',
      last: consentBtn!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );

    await store.visit.setPhase(session.id, VisitPhase.hold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final holdBtn = _bottomMost(
      tester,
      find.byKey(const Key('visit-hold-action-pad')),
      [FilledButton, TextButton],
    );
    expect(holdBtn, isNotNull);
    await _expectReachable(
      name: 'visit-hold-cta',
      last: holdBtn!,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });

  testWidgets('Timer customer-bind control clears pill nav', (tester) async {
    final store = SoriStore();
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        isDirector: true,
        body: VisitLauncherPage(store: store),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.tap(find.text('타이머').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      if (find.byKey(const Key('home-timer-stage')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('home-timer-stage')), findsOneWidget);

    final bindCtx = tester.element(
      find.byKey(const Key('home-timer-customer-bind')),
    );
    final timerPos = Scrollable.of(bindCtx).position;
    if (timerPos.maxScrollExtent > 0) {
      timerPos.jumpTo(timerPos.maxScrollExtent);
      await tester.pump();
    }
    final bind = find.byKey(const Key('home-timer-customer-bind'));
    expect(bind, findsOneWidget);
    final last = tester.getRect(bind);
    await _expectReachable(
      name: 'timer-customer-bind',
      last: last,
      nav: tester.getRect(find.byType(FloatingPillNav)),
      tester: tester,
    );
  });
}
