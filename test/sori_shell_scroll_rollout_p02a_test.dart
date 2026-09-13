import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/visit/visit_session_page.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_shell_insets.dart';
import 'package:sori/views/community/region_nearby_map_section.dart';
import 'package:sori/views/home_explore_tab.dart';
import 'package:sori/views/shoot_hub_page.dart';
import 'package:sori/views/unified_home_feed_page.dart';

const _viewPad = 34.0;

double _ssot({required bool pillNav}) {
  if (!pillNav) return 0;
  return 64 + 12 + _viewPad + 20;
}

Widget _shell({
  required bool pillNav,
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
          pillNavVisible: pillNav,
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

  testWidgets('mobile Visit ListView bottom is 20 + SSOT', (tester) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.pumpWidget(
      _shell(
        pillNav: true,
        child: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final list = tester.widget<ListView>(
      find.byKey(const Key('visit-phase-list')).first,
    );
    expect(
      list.padding,
      EdgeInsets.fromLTRB(20, 20, 20, 20 + _ssot(pillNav: true)),
    );
  });

  testWidgets('mobile Consent fixed CTA bottom is 16 + SSOT', (tester) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.pumpWidget(
      _shell(
        pillNav: true,
        child: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final pad = tester.widget<Padding>(
      find.byKey(
        const Key('visit-consent-action-pad'),
        skipOffstage: false,
      ),
    );
    expect(
      pad.padding,
      EdgeInsets.fromLTRB(16, 16, 16, 16 + _ssot(pillNav: true)),
    );
  });

  testWidgets('PC Visit occupancy is 0 so only 20 gutter remains', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        pillNav: false,
        size: const Size(1024, 800),
        child: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final list = tester.widget<ListView>(
      find.byKey(const Key('visit-phase-list')).first,
    );
    expect(list.padding, const EdgeInsets.fromLTRB(20, 20, 20, 20));
  });

  testWidgets('mobile recommend list bottom is breathing 8 + SSOT', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        pillNav: true,
        child: UnifiedHomeFeedPage(
          store: store,
          surface: FeedSurface.community,
        ),
      ),
    );
    await _pumpFrames(tester);

    final pad = tester.widget<SliverPadding>(
      find.byKey(
        const Key('feed-recommend-list-padding'),
        skipOffstage: false,
      ),
    );
    expect(pad.padding, EdgeInsets.fromLTRB(0, 8, 0, 8 + _ssot(pillNav: true)));
    expect(pad.padding, isNot(const EdgeInsets.fromLTRB(0, 8, 0, 110)));
    expect(
      find.descendant(
        of: find.byKey(
          const Key('feed-recommend-list-padding'),
          skipOffstage: false,
        ),
        matching: find.byType(RegionNearbyMapSection),
      ),
      findsNothing,
    );
  });

  testWidgets('explore browse padding is SSOT without 100+safe double count', (
    tester,
  ) async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        pillNav: true,
        size: const Size(390, 900),
        child: Scaffold(
          body: HomeExploreTab(
            store: store,
            scrollController: ScrollController(),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    final pad = tester.widget<SliverPadding>(
      find.byKey(
        const Key('explore-browse-list-padding'),
        skipOffstage: false,
      ),
    );
    final ssot = _ssot(pillNav: true);
    expect(pad.padding, EdgeInsets.fromLTRB(16, 4, 16, ssot));
    expect(pad.padding, isNot(EdgeInsets.fromLTRB(16, 4, 16, 100 + _viewPad)));
    expect(pad.padding, isNot(EdgeInsets.fromLTRB(16, 4, 16, 100 + ssot)));
  });

  testWidgets('ShootHub bottom is 16 gutter + SSOT, not 100+safe', (
    tester,
  ) async {
    final store = SoriStore();

    await tester.pumpWidget(
      _shell(
        pillNav: true,
        child: Scaffold(body: ShootHubPage(store: store)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await _drain(tester);

    final list = tester.widget<ListView>(
      find.byKey(const Key('shoot-hub-list')),
    );
    expect(
      list.padding,
      EdgeInsets.fromLTRB(16, 12, 16, 16 + _ssot(pillNav: true)),
    );
    expect(
      list.padding,
      isNot(EdgeInsets.fromLTRB(16, 12, 16, 100 + _viewPad)),
    );
  });

  testWidgets('PC ShootHub keeps 16 gutter and no nav occupancy', (
    tester,
  ) async {
    final store = SoriStore();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        pillNav: false,
        size: const Size(1024, 800),
        child: Scaffold(body: ShootHubPage(store: store)),
      ),
    );
    await tester.pump();
    await _drain(tester);

    final list = tester.widget<ListView>(
      find.byKey(const Key('shoot-hub-list')),
    );
    expect(list.padding, const EdgeInsets.fromLTRB(16, 12, 16, 16));
  });
}
