import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/features/visit/widgets/home_hero_card.dart';
import 'package:sori/features/visit/widgets/home_preset_quick_pick.dart';
import 'package:sori/features/visit/widgets/home_quick_action_row.dart';
import 'package:sori/features/visit/widgets/home_scheduler_strip.dart';
import 'package:sori/features/visit/widgets/home_toolbox_row.dart';
import 'package:sori/features/visit/widgets/management_case_card.dart';
import 'package:sori/services/sori_store.dart';

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

  testWidgets('홈은 My Feed / My Asset / Timer 3탭으로 열린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    expect(find.text('My Feed'), findsOneWidget);
    expect(find.text('My Asset'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);

    // 기본 선택은 My Feed — 4대 컴포넌트가 한 화면에 조립된다.
    expect(find.byType(HomeHeroCard), findsOneWidget);
    expect(find.byType(HomeSchedulerStrip), findsOneWidget);
    expect(find.byType(HomeQuickActionRow), findsOneWidget);
    expect(find.byType(BaCaptureCarousel), findsOneWidget);
    expect(find.text('관리 케이스'), findsOneWidget);
  });

  testWidgets('My Feed는 렌더링 붕괴(blank screen) 없이 조립된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    // v5.4 blank screen 사고의 재발 감시 — Hero가 실제 면적을 차지해야 한다.
    final hero = tester.getSize(find.byType(HomeHeroCard));
    expect(hero.height, greaterThan(200));
    expect(hero.width, greaterThan(300));

    final carousel = tester.getSize(find.byType(BaCaptureCarousel));
    expect(carousel.height, greaterThan(100));
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

  testWidgets('Q1(b) — Timer 탭에 v5.4 자산 3종이 그대로 살아 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    // My Feed에는 타이머 자산이 없어야 한다.
    expect(find.byType(HomeToolboxRow), findsNothing);
    expect(find.byType(HomePresetQuickPick), findsNothing);

    await tester.tap(find.text('Timer'));
    await _settle(tester);

    expect(find.byType(HomeToolboxRow), findsOneWidget);
    expect(find.text('케어 시작'), findsOneWidget);
    expect(find.byType(HomePresetQuickPick), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Asset 탭은 뼈대만 노출한다 (Q7)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);

    await tester.tap(find.text('My Asset'));
    await _settle(tester);

    expect(find.textContaining('다음 스프린트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
