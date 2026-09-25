import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/models/chart_visit_record.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/customer_chart.dart';
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

/// draft 저장 횟수·동시 실행을 세고, 필요하면 저장을 붙잡거나 실패시킨다.
class _SaveProbeStore extends SoriStore {
  int draftSaves = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  bool fail = false;
  Completer<void>? hold;

  @override
  Future<CustomerChart> saveChartVisitDraft({
    required String chartId,
    required ChartVisitRecord record,
  }) async {
    if (record.flowStatus == 'draft') draftSaves++;
    inFlight++;
    maxInFlight = math.max(maxInFlight, inFlight);
    try {
      final gate = hold;
      if (gate != null) await gate.future;
      if (fail) throw StateError('offline');
      return await super.saveChartVisitDraft(chartId: chartId, record: record);
    } finally {
      inFlight--;
    }
  }
}

String? _saveStatus(WidgetTester tester) {
  final finder = find.byKey(const Key('chart-visit-workspace-save-status'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

Future<void> _editConcern(WidgetTester tester, String label) async {
  if (find.byKey(const Key('chart-visit-section-concern-body')).evaluate().isEmpty) {
    await _tapVisible(tester, const Key('chart-visit-section-concern-header'));
  }
  await _tapVisible(tester, Key('chart-visit-workspace-concern-$label'));
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

  Future<void> openCare(WidgetTester tester, SoriStore store) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, store);
    await _openRecent(tester, _recentFirst(store).id);
    await _tapVisible(tester, const Key('chart-visit-section-care-header'));
  }

  Future<void> tapDelete(WidgetTester tester, int index) async {
    await _tapVisible(tester, Key('chart-ws-care-step-delete-$index'));
    await _settle(tester);
  }

  testWidgets('care step delete removes an empty step immediately', (
    tester,
  ) async {
    final store = SoriStore();
    await openCare(tester, store);
    expect(_summary(tester, 'care'), '5단계');
    expect(find.text('클렌징'), findsOneWidget);
    expect(find.byTooltip('시술 삭제'), findsNWidgets(5));

    await tapDelete(tester, 0);

    expect(find.byKey(const Key('chart-ws-care-step-delete-confirm')),
        findsNothing);
    expect(find.text('클렌징'), findsNothing);
    expect(_summary(tester, 'care'), '4단계');
    expect(find.byKey(const Key('chart-ws-care-step-delete-4')), findsNothing);
    // 번호가 다시 매겨진다: 첫 줄이 01 효소 각질관리.
    final first = find.byKey(const ValueKey<String>('chart-visit-workspace-step-0'));
    expect(
      find.descendant(of: first, matching: find.text('효소 각질관리')),
      findsOneWidget,
    );
    expect(find.descendant(of: first, matching: find.text('01')), findsOneWidget);
  });

  testWidgets('care step delete asks before removing a filled step', (
    tester,
  ) async {
    final store = SoriStore();
    await openCare(tester, store);

    await tester.tap(find.text('클렌징'));
    await tester.pump();
    final first = find.byKey(const ValueKey<String>('chart-visit-workspace-step-0'));
    await tester.enterText(
      find.descendant(of: first, matching: find.byType(TextField)).first,
      '딥 클렌징',
    );
    await tester.pump();
    expect(_summary(tester, 'care'), '5단계 · 기록 1');

    await tapDelete(tester, 0);
    expect(find.byKey(const Key('chart-ws-care-step-delete-confirm')),
        findsOneWidget);
    expect(find.text('이 시술을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await _settle(tester);
    expect(find.byKey(const Key('chart-ws-care-step-delete-confirm')),
        findsNothing);
    expect(find.text('클렌징'), findsOneWidget);
    expect(_summary(tester, 'care'), '5단계 · 기록 1');

    await tapDelete(tester, 0);
    await tester.tap(find.text('삭제'));
    await _settle(tester);
    expect(find.text('클렌징'), findsNothing);
    expect(find.text('딥 클렌징'), findsNothing);
    expect(_summary(tester, 'care'), '4단계');
  });

  testWidgets('임시저장 after care step delete saves the reduced step list', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = _recentFirst(store);
    await openCare(tester, store);

    await tapDelete(tester, 1);
    expect(_summary(tester, 'care'), '4단계');
    await tester.tap(find.byKey(const Key('chart-visit-workspace-save-draft')));
    await _settle(tester);

    final drafts = store.chartVisitDraftsFor(customer.id);
    expect(drafts, hasLength(1));
    final steps = drafts.single.visitRecord.treatmentSteps;
    expect(
      steps.map((s) => s['title']).toList(),
      ['클렌징', '진정 앰플', '초음파', '진정팩'],
    );
    expect(steps.map((s) => s['sort']).toList(), [1, 2, 3, 4]);
  });

  testWidgets('deleting every care step saves an empty step list', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = _recentFirst(store);
    await openCare(tester, store);

    for (var i = 0; i < 5; i++) {
      await tapDelete(tester, 0);
    }
    expect(_summary(tester, 'care'), '미입력');
    await tester.tap(find.byKey(const Key('chart-visit-workspace-save-draft')));
    await _settle(tester);

    final drafts = store.chartVisitDraftsFor(customer.id);
    expect(drafts, hasLength(1));
    expect(drafts.single.visitRecord.treatmentSteps, isEmpty);
    expect(_summary(tester, 'care'), '미입력');
  });

  testWidgets('autosave writes one draft ~2.5s after an edit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await _editConcern(tester, '건조');
    expect(_saveStatus(tester), isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(store.draftSaves, 0);
    expect(store.chartVisitDraftsFor(customer.id), isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(store.draftSaves, 1);
    final drafts = store.chartVisitDraftsFor(customer.id);
    expect(drafts, hasLength(1));
    expect(drafts.single.visitRecord.concerns, ['건조']);
    expect(_saveStatus(tester), '저장됨');

    await tester.pump(const Duration(seconds: 5));
    expect(store.draftSaves, 1);
  });

  testWidgets('rapid edits are debounced into a single autosave', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await _editConcern(tester, '건조');
    await tester.pump(const Duration(seconds: 1));
    await _editConcern(tester, '모공');
    await tester.pump(const Duration(seconds: 1));
    await _tapVisible(tester, const Key('chart-visit-workspace-goal-진정'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.draftSaves, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(store.draftSaves, 1);
    final record = store.chartVisitDraftsFor(customer.id).single.visitRecord;
    expect(record.concerns, ['건조', '모공']);
    expect(record.careGoals, ['진정']);
  });

  testWidgets('no autosave when nothing changed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);
    final chartsBefore = store.chartsForCustomer(customer.id).length;

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    // 섹션을 펼치고 접기만 하는 건 편집이 아니다.
    await _tapVisible(tester, const Key('chart-visit-section-concern-header'));
    await _tapVisible(tester, const Key('chart-visit-section-care-header'));
    await tester.pump(const Duration(seconds: 6));

    expect(store.draftSaves, 0);
    expect(store.chartsForCustomer(customer.id).length, chartsBefore);
    expect(_saveStatus(tester), isNull);
  });

  testWidgets('no autosave after 방문 완료', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await _editConcern(tester, '건조');
    await tester.tap(find.byKey(const Key('chart-visit-workspace-complete')));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));

    expect(store.draftSaves, 0);
    expect(store.chartVisitDraftsFor(customer.id), isEmpty);
    final completed = store
        .chartsForCustomer(customer.id)
        .where((c) => c.visitRecord.flowStatus == 'completed')
        .toList();
    expect(completed, hasLength(1));
    expect(completed.single.visitRecord.concerns, ['건조']);
  });

  testWidgets('방문 완료 waits for an in-flight autosave and never overlaps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    store.hold = Completer<void>();
    await _editConcern(tester, '건조');
    await tester.pump(const Duration(seconds: 3));
    expect(store.draftSaves, 1);
    expect(store.inFlight, 1);

    await tester.tap(find.byKey(const Key('chart-visit-workspace-complete')));
    await tester.pump();
    expect(
      store
          .chartsForCustomer(customer.id)
          .where((c) => c.visitRecord.flowStatus == 'completed'),
      isEmpty,
    );

    store.hold!.complete();
    store.hold = null;
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));

    expect(store.maxInFlight, 1);
    expect(store.draftSaves, 1);
    expect(store.chartVisitDraftsFor(customer.id), isEmpty);
    final completed = store
        .chartsForCustomer(customer.id)
        .where((c) => c.visitRecord.flowStatus == 'completed')
        .toList();
    expect(completed, hasLength(1));
    expect(find.byType(ChartEmptyDesk), findsOneWidget);
  });

  testWidgets('edits during an in-flight save queue exactly one more save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore();
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    store.hold = Completer<void>();
    await _editConcern(tester, '건조');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(store.draftSaves, 1);
    expect(_saveStatus(tester), '저장 중…');

    await _editConcern(tester, '모공');
    await tester.pump(const Duration(seconds: 3));
    // 첫 저장이 끝나기 전에는 두 번째 저장을 시작하지 않는다.
    expect(store.draftSaves, 1);

    store.hold!.complete();
    store.hold = null;
    await _settle(tester);

    expect(store.draftSaves, 2);
    expect(store.maxInFlight, 1);
    expect(store.chartVisitDraftsFor(customer.id), hasLength(1));
    expect(
      store.chartVisitDraftsFor(customer.id).single.visitRecord.concerns,
      ['건조', '모공'],
    );
    expect(_saveStatus(tester), '저장됨');
    await tester.pump(const Duration(seconds: 6));
    expect(store.draftSaves, 2);
  });

  testWidgets('autosave failure shows retry and tapping it saves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _SaveProbeStore()..fail = true;
    final customer = _recentFirst(store);

    await _pumpPage(tester, store);
    await _openRecent(tester, customer.id);
    await _editConcern(tester, '건조');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(_saveStatus(tester), '저장 실패 · 다시 시도');
    expect(tester.takeException(), isNull);

    store.fail = false;
    await tester.tap(find.byKey(const Key('chart-visit-workspace-save-retry')));
    await _settle(tester);
    expect(_saveStatus(tester), '저장됨');
    expect(
      store.chartVisitDraftsFor(customer.id).single.visitRecord.concerns,
      ['건조'],
    );
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
