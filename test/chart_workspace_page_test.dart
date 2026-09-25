import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/chart_workspace/chart_empty_desk.dart';
import 'package:sori/views/chart_workspace/chart_index_palette.dart';
import 'package:sori/views/chart_workspace/chart_visit_workspace.dart';
import 'package:sori/views/chart_workspace/chart_workspace_page.dart';
import 'package:sori/views/chart_workspace/chart_workspace_state.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _pumpPage(WidgetTester tester, SoriStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ChartWorkspacePage(store: store)),
    ),
  );
  await tester.pump();
}

Customer _recentFirst(SoriStore store) {
  final recent = List.of(store.customers)
    ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
  return recent.first;
}

Future<void> _openRecent(WidgetTester tester, String customerId) async {
  await tester.tap(find.byKey(Key('chart-empty-desk-recent-$customerId')));
  await _settle(tester);
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

String? _summary(WidgetTester tester, String id) {
  return tester
      .widget<Text>(find.byKey(Key('chart-visit-section-$id-summary')))
      .data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChartIndexPaletteStore.instance.debugResetForTest();
    ChartVisitPreviewStore.instance.debugResetForTest();
  });

  testWidgets('CHART tab defaults to empty desk without No.N file rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    expect(store.customers, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisitLauncherPage(store: store)),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('CHART'));
    await _settle(tester);

    expect(find.byType(ChartWorkspacePage), findsOneWidget);
    expect(find.byType(ChartEmptyDesk), findsOneWidget);
    expect(find.byKey(const Key('chart-empty-desk')), findsOneWidget);
    expect(find.byKey(const Key('chart-empty-desk-search')), findsOneWidget);
    expect(find.byKey(const Key('chart-empty-desk-new-start')), findsOneWidget);
    expect(find.text('신규로 시작'), findsOneWidget);
    expect(find.text('이전 서랍 보기'), findsNothing);
    expect(find.byKey(const Key('chart-empty-desk-legacy-toggle')), findsNothing);

    expect(find.byKey(const Key('chart-drawer-rail')), findsNothing);
    expect(find.byKey(const Key('chart-file-rail')), findsNothing);
    expect(find.text('No.1'), findsNothing);
    expect(find.byType(ChartVisitHomePage), findsNothing);
    expect(find.byKey(const Key('chart-visit-start')), findsNothing);
  });

  testWidgets(
    'desk recent select opens today-visit workspace with accordion sections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      final customer = _recentFirst(store);
      final chartsBefore = store.chartsForCustomer(customer.id).length;

      await _pumpPage(tester, store);
      expect(find.byType(ChartEmptyDesk), findsOneWidget);
      await _openRecent(tester, customer.id);

      expect(find.byType(ChartEmptyDesk), findsNothing);
      expect(find.byType(ChartVisitWorkspace), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-workspace')), findsOneWidget);
      // 이력 홈 게이트 없이 바로 작성 데스크.
      expect(find.byType(ChartVisitHomePage), findsNothing);
      expect(find.byKey(const Key('chart-visit-start')), findsNothing);
      expect(find.byKey(const Key('chart-visit-workspace-name')), findsOneWidget);
      expect(find.text(customer.name), findsWidgets);
      expect(find.text('오늘 방문'), findsOneWidget);
      expect(
        find.byKey(const Key('chart-visit-workspace-history')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chart-desk-back')), findsOneWidget);
      expect(find.byKey(const Key('chart-drawer-rail')), findsNothing);
      expect(find.byKey(const Key('chart-file-rail')), findsNothing);

      for (final id in const [
        'safety',
        'concern',
        'care',
        'reaction',
        'photo',
        'aftercare',
      ]) {
        expect(find.byKey(Key('chart-visit-section-$id')), findsOneWidget);
        expect(
          find.byKey(Key('chart-visit-section-$id-summary')),
          findsOneWidget,
        );
      }
      expect(_summary(tester, 'concern'), '미입력');
      expect(_summary(tester, 'photo'), '미입력');
      expect(_summary(tester, 'reaction'), '없음');
      // 안전확인만 기본으로 펼쳐져 있다.
      expect(find.byKey(const Key('chart-visit-section-safety-body')),
          findsOneWidget);
      expect(find.byKey(const Key('chart-visit-section-concern-body')),
          findsNothing);

      expect(
        find.byKey(const Key('chart-visit-workspace-save-draft')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chart-visit-workspace-complete')),
        findsOneWidget,
      );
      expect(find.text('임시저장'), findsOneWidget);
      expect(find.text('방문 완료'), findsOneWidget);
      // 열어 보기만 해서는 차트 행을 만들지 않는다.
      expect(store.chartsForCustomer(customer.id).length, chartsBefore);

      await tester.tap(find.byKey(const Key('chart-desk-back')));
      await _settle(tester);
      expect(find.byType(ChartEmptyDesk), findsOneWidget);
      expect(store.chartsForCustomer(customer.id).length, chartsBefore);
    },
  );

  testWidgets('방문 완료 saves via chart visit gateway and returns to desk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);

    await _tapVisible(tester, const Key('chart-visit-section-concern-header'));
    await _tapVisible(tester, const Key('chart-visit-workspace-concern-건조'));
    await _tapVisible(tester, const Key('chart-visit-workspace-goal-진정'));
    expect(_summary(tester, 'concern'), '고민 1 · 목표 1');

    await tester.tap(find.byKey(const Key('chart-visit-workspace-complete')));
    await _settle(tester);

    expect(find.byType(ChartVisitWorkspace), findsNothing);
    expect(find.byType(ChartEmptyDesk), findsOneWidget);
    expect(find.text('${customer.name} 방문 기록을 저장했어요'), findsOneWidget);

    final completed = store
        .chartsForCustomer(customer.id)
        .where((c) => c.visitRecord.flowStatus == 'completed')
        .toList();
    expect(completed, hasLength(1));
    expect(completed.single.visitRecord.concerns, ['건조']);
    expect(completed.single.visitRecord.careGoals, ['진정']);
    expect(store.chartVisitDraftsFor(customer.id), isEmpty);
    expect(ChartVisitPreviewStore.instance.active, isNull);
  });

  testWidgets('임시저장 draft reopens pre-filled as 이어서 작성', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    expect(
      find.byKey(const Key('chart-visit-workspace-resumed')),
      findsNothing,
    );

    await _tapVisible(tester, const Key('chart-visit-section-concern-header'));
    await _tapVisible(tester, const Key('chart-visit-workspace-concern-모공'));
    await tester.tap(find.byKey(const Key('chart-visit-workspace-save-draft')));
    await _settle(tester);
    expect(find.text('임시저장했어요'), findsOneWidget);

    final drafts = store.chartVisitDraftsFor(customer.id);
    expect(drafts, hasLength(1));
    expect(drafts.single.visitRecord.concerns, ['모공']);

    await tester.tap(find.byKey(const Key('chart-desk-back')));
    await _settle(tester);
    expect(find.byType(ChartEmptyDesk), findsOneWidget);

    await _openRecent(tester, customer.id);
    expect(find.byType(ChartVisitWorkspace), findsOneWidget);
    expect(
      find.byKey(const Key('chart-visit-workspace-resumed')),
      findsOneWidget,
    );
    expect(_summary(tester, 'concern'), '고민 1');
    // 같은 draft 행을 다시 연다(새 행을 만들지 않는다).
    expect(store.chartVisitDraftsFor(customer.id), hasLength(1));
  });

  testWidgets('leaving the workspace after edits keeps a draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await _tapVisible(tester, const Key('chart-visit-section-concern-header'));
    await _tapVisible(tester, const Key('chart-visit-workspace-concern-색소'));

    await tester.tap(find.byKey(const Key('chart-desk-back')));
    await _settle(tester);

    expect(find.byType(ChartEmptyDesk), findsOneWidget);
    final drafts = store.chartVisitDraftsFor(customer.id);
    expect(drafts, hasLength(1));
    expect(drafts.single.visitRecord.concerns, ['색소']);
  });

  testWidgets('이력 link opens existing ChartVisitHomePage', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await tester.tap(find.byKey(const Key('chart-visit-workspace-history')));
    await _settle(tester);

    expect(find.byType(ChartVisitHomePage), findsOneWidget);
    expect(find.byKey(const Key('chart-visit-start')), findsOneWidget);

    await tester.pageBack();
    await _settle(tester);
    expect(find.byType(ChartVisitHomePage), findsNothing);
    expect(find.byType(ChartVisitWorkspace), findsOneWidget);
  });

  testWidgets('workspace fits a 360px phone without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    for (final id in const ['concern', 'care', 'reaction', 'photo', 'aftercare']) {
      await _tapVisible(tester, Key('chart-visit-section-$id-header'));
    }
    await _tapVisible(tester, const Key('chart-visit-workspace-safety-edit'));
    expect(tester.takeException(), isNull);
    expect(find.byType(ChartVisitWorkspace), findsOneWidget);
  });

  testWidgets('empty desk today and recent use horizontal carousel keys', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final recent = List.of(store.customers)
      ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    final recentCustomer = recent.first;
    final todayMatches = store.customers
        .where((c) => todayChartForCustomer(store, c.id) != null)
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChartWorkspacePage(store: store)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(Key('chart-empty-desk-recent-${recentCustomer.id}')),
      findsOneWidget,
    );
    if (todayMatches.isNotEmpty) {
      expect(
        find.byKey(Key('chart-empty-desk-today-${todayMatches.first.id}')),
        findsOneWidget,
      );
    }
  });

  test('visit rail hides duplicate today visit number', () {
    final store = SoriStore();
    final customer = store.customers.first;
    final today = todayChartForCustomer(store, customer.id);
    final items = buildVisitRailItems(store, customer.id);
    if (today == null) {
      expect(items.first.kind, VisitRailKind.newDraft);
      expect(items.where((e) => e.kind == VisitRailKind.today), isEmpty);
    } else {
      expect(items.first.kind, VisitRailKind.today);
      expect(items.where((e) => e.chart?.id == today.id).length, 1);
      expect(items.where((e) => e.label == 'v${today.visitNumber}'), isEmpty);
    }
  });
}
