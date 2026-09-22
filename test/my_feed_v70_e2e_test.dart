import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/operation/widgets/care_timer_floating_bar.dart';
import 'package:sori/features/operation/widgets/care_timer_fullscreen_page.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/features/visit/widgets/home_hero_card.dart';
import 'package:sori/features/visit/widgets/home_preset_quick_pick.dart';
import 'package:sori/features/visit/widgets/home_quick_action_row.dart';
import 'package:sori/features/visit/widgets/home_scheduler_strip.dart';
import 'package:sori/features/visit/widgets/home_toolbox_row.dart';
import 'package:sori/features/visit/widgets/management_case_card.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/sori_tokens.dart';

/// 홈 셸이 마운트될 때까지 프레임을 흘린다.
/// 플립 시계가 반복 타이머를 돌리므로 pumpAndSettle은 쓸 수 없다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<SoriStore> _mountHome(WidgetTester tester) async {
  final store = SoriStore();
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
  );
  await _settle(tester);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('홈은 오늘 / 프로그램 / 타이머 3탭으로 열린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    expect(find.text('DESK'), findsOneWidget);
    expect(find.text('CHART'), findsOneWidget);
    expect(find.text('PROGRAMS'), findsOneWidget);
    expect(find.text('My Asset'), findsNothing);
    expect(find.text('FLOW'), findsOneWidget);

    // Desk 피드: 히어로·스케줄러·지금 처리할 일 제거 후 퀵액션부터 시작.
    expect(find.byType(HomeHeroCard), findsNothing);
    expect(find.byType(HomeSchedulerStrip), findsNothing);
    expect(find.text('지금 처리할 일'), findsNothing);
    expect(find.byType(HomeQuickActionRow), findsOneWidget);
    expect(find.byType(BaCaptureCarousel), findsOneWidget);
    expect(find.text('B&A 게시물'), findsOneWidget);
  });

  testWidgets('My Feed는 렌더링 붕괴(blank screen) 없이 조립된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    final quick = tester.getSize(find.byType(HomeQuickActionRow));
    expect(quick.height, greaterThan(40));
    expect(quick.width, greaterThan(200));

    final carousel = tester.getSize(find.byType(BaCaptureCarousel));
    expect(carousel.height, greaterThan(100));

    // Desk 피드에는 플립시계가 없다 (Timer 탭에만 있음).
    expect(find.byType(FlipClockDisplay), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('B/A 캐러셀에 빈 슬롯은 "B/A 촬영" 단 1개뿐이다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _mountHome(tester);

    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('촬영 대기'), findsNothing);
    expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);

    // 카메라 진입/취소를 반복해도 슬롯이 늘지 않는다.
    // (예전에는 카메라를 열기 전에 세션을 만들어 취소마다 카드가 쌓였다.)
    for (var i = 0; i < 5; i++) {
      store.reservePendingBaToken();
    }
    await tester.pump();
    await _settle(tester);

    expect(find.text('NEW'), findsOneWidget);
    expect(store.baPendingSession, isNull);
    expect(store.baSessions.where((s) => !s.hasPhoto), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('고객을 연결하면 이름 + 🔴 카드로 분리된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _mountHome(tester);
    if (store.customers.isEmpty) return;
    final customer = store.customers.first;

    final pending = await store.captureIntoPendingBaSlot(
      kind: 'before',
      imageUrl: 'https://example.com/e2e-b.webp',
    );
    await tester.pump();
    await _settle(tester);

    // 아직은 고정 슬롯에 머문다 — 카드로 분리되지 않는다.
    expect(find.text('NEW'), findsOneWidget);
    expect(store.baPendingSession?.id, pending.id);
    expect(find.text('작성 중'), findsOneWidget);

    await store.bindBaSessionToChart(
      target: pending,
      customerId: customer.id,
    );
    await tester.pump();
    await _settle(tester);

    // 이제 고객 이름 카드로 분리되고, After가 없으니 🔴다.
    expect(find.text('NEW'), findsOneWidget, reason: '고정 슬롯은 그대로 1개');
    expect(find.text(customer.name), findsWidgets);
    expect(find.byKey(ValueKey('history-${pending.id}')), findsNothing);
    expect(find.text('작성 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B/A 캐러셀에서 관리 케이스까지 끊김 없이 스크롤된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _mountHome(tester);
    final completed = store.managementCaseCharts();

    // 캐러셀은 가로로 독립 스크롤한다 (세로 제약이 새지 않는지 확인).
    await tester.drag(
      find.byType(BaCaptureCarousel),
      const Offset(-160, 0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 세로 피드를 끝까지 내린다. 좌표 hit test 대신 position을 직접 구동해
    // 화면 크기와 무관하게 결정적으로 검증한다.
    final vertical = tester.state<ScrollableState>(
      find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          )
          .first,
    );
    vertical.position.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();
    expect(vertical.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);

    if (completed.isNotEmpty) {
      expect(find.byType(ManagementCaseCard), findsWidgets);
    } else {
      expect(find.text('완성된 B/A 케이스가 아직 없습니다'), findsOneWidget);
    }
  });

  testWidgets('Q1(b) — Timer 탭 Standby에 시계·컨트롤·고객연결이 임베딩된다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    // My Feed에는 타이머 자산이 없어야 한다.
    expect(find.byType(HomeToolboxRow), findsNothing);
    expect(find.byType(HomePresetQuickPick), findsNothing);

    await tester.tap(find.byKey(const Key('sori-stage-tab-3')));
    await _settle(tester);

    expect(find.byType(HomeToolboxRow), findsOneWidget);
    expect(find.byKey(const Key('home-timer-stage')), findsOneWidget);
    expect(find.byType(FlipClockDisplay), findsWidgets);
    expect(find.byType(CareTimerFloatingBar), findsOneWidget);
    expect(find.text('케어 시작'), findsOneWidget);
    expect(find.byType(HomePresetQuickPick), findsNothing);
    expect(find.byKey(const Key('home-timer-step-clock')), findsOneWidget);
    expect(find.byKey(const Key('home-timer-customer-bind')), findsOneWidget);
    expect(find.text('고객 차트 연결'), findsOneWidget);
    expect(find.byType(CareTimerFullscreenPage), findsNothing);
    expect(find.byKey(const Key('home-timer-title-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Program 탭은 앵커만 접힌 채로 열린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    await tester.tap(find.text('PROGRAMS'));
    await _settle(tester);

    expect(find.text('윤곽 관리'), findsOneWidget);
    expect(find.text('3,000,000'), findsOneWidget);
    expect(find.text('1,500,000'), findsNothing);
    expect(find.text('1,000,000'), findsNothing);
    expect(find.textContaining('다음 스프린트'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈 상단은 텍스트 밑줄 탭이며 각 업무로 이동한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    expect(find.byType(TabBar), findsNothing);
    final filed = find.byKey(const Key('home-filed-label'));
    expect(filed, findsOneWidget);
    final fill = tester
        .widget<AnimatedContainer>(
          find.descendant(
            of: filed,
            matching: find.byKey(const Key('sori-stage-tab-fill-0')),
          ),
        )
        .decoration! as BoxDecoration;
    expect(fill.color, SoriTokens.surface);
    expect((fill.border! as Border).bottom.color, SoriTokens.textCharcoal);
    expect(
      fill.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.zero,
        topRight: Radius.zero,
      ),
    );
    expect(tester.getSize(filed).width, lessThan(430 / 3));

    await tester.tap(find.byKey(const Key('sori-stage-tab-2')));
    await _settle(tester);
    expect(find.text('윤곽 관리'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sori-stage-tab-3')));
    await _settle(tester);
    expect(find.byKey(const Key('home-timer-title-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sori-stage-tab-0')));
    await _settle(tester);
    expect(find.byType(HomeQuickActionRow), findsOneWidget);
  });

  testWidgets('관리 케이스 북마크 토글이 즐겨찾기만 남긴다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _mountHome(tester);
    final completed = store.managementCaseCharts();

    final filterOn = find.byTooltip('즐겨찾기한 케이스만 보기');
    expect(filterOn, findsOneWidget);

    await tester.ensureVisible(filterOn);
    await tester.tap(filterOn);
    await _settle(tester);

    // 즐겨찾기가 하나도 없으므로 필터 켠 직후에는 빈 상태여야 한다.
    expect(find.text('전체 보기'), findsOneWidget);
    expect(find.text('즐겨찾기한 케이스가 없습니다'), findsOneWidget);
    expect(find.byType(ManagementCaseCard), findsNothing);

    final filterOff = find.byTooltip('전체 케이스 보기');
    await tester.ensureVisible(filterOff);
    await tester.tap(filterOff);
    await _settle(tester);

    expect(find.text('즐겨찾기만'), findsNothing);
    if (completed.isNotEmpty) {
      expect(find.byType(ManagementCaseCard), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });
}
