import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/chart_visit/chart_visit_flow_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/features/chart_visit/visit_record_context.dart';
import 'package:sori/models/chart_visit_record.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/chart_workspace/chart_workspace_page.dart';

Future<void> tap(WidgetTester t, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String hint, String value) async {
  final field = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );
  await t.ensureVisible(field);
  await t.pumpAndSettle();
  await t.enterText(field, value);
  await t.pumpAndSettle();
}

void main() {
  final preview = ChartVisitPreviewStore.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preview.debugResetForTest();
  });

  for (final size in [const Size(360, 800), const Size(1024, 900)]) {
    testWidgets('home customer intake consult care and reopening at $size', (
      t,
    ) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      final store = SoriStore();
      final customers = List.of(store.customers)
        ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
      final customer = customers.first;
      final draft = await store.createChartVisitDraft(
        customerId: customer.id,
        record: ChartVisitRecord(
          visitDate: DateTime.now(),
          concerns: const ['등 불편'],
          desiredChange: '등과 하체가 편안했으면',
          scores: const {'redness': 4},
          treatmentSteps: const [
            {'sort': 1, 'title': '등 이완 관리', 'area': '등', 'memo': '강도를 낮춰 시행'},
          ],
          reactionTypes: const ['열감'],
          reactionNone: false,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(body: ChartWorkspacePage(store: store)),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'chart-empty-desk-recent-${customer.id}');
      await tap(t, 'chart-visit-section-care-header');
      expect(find.text('상담 기록 없음'), findsOneWidget);
      await tap(t, 'care-open-consult');
      expect(find.text('고민: 등 불편'), findsOneWidget);
      expect(find.text('원하는 변화: 등과 하체가 편안했으면'), findsOneWidget);
      await tap(t, 'workspace-consult-start');
      await enter(t, '관리 부위·방향·주의사항', '등·하체를 낮은 강도로 관리하기로 함');
      await tap(t, 'workspace-consult-apply');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      var record = store.findChartById(draft.id)!.visitRecord;
      expect(record.consultApplied, isTrue);
      expect(
        record.consultApproved['director_assessment'],
        '등·하체를 낮은 강도로 관리하기로 함',
      );
      expect(find.text('관리사 판단: 등·하체를 낮은 강도로 관리하기로 함'), findsOneWidget);
      expect(record.treatmentSteps.single['title'], '등 이완 관리');
      await tap(t, 'chart-visit-section-aftercare-header');
      expect(find.text('1. 등 이완 관리 · 등'), findsOneWidget);
      expect(find.text('관리 중 특이 반응: 열감'), findsOneWidget);
      await tap(t, 'workspace-add-change');
      expect(find.text('오늘 문진 · 관리 전 4/5'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('visit-change-save')))
            .onPressed,
        isNull,
      );
      await tap(t, 'visit-change-after-2');
      await tap(t, 'visit-change-save');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(store.findChartById(draft.id)!.visitRecord.scoreChanges.single, (
        axis: 'redness',
        from: 4,
        to: 2,
      ));
      await tap(t, 'result-open-care');
      expect(
        find.byKey(const Key('chart-visit-section-care-body')),
        findsOneWidget,
      );

      // The true home entry saves and then reconstructs the same visit.
      await tap(t, 'chart-desk-back');
      await tap(t, 'chart-empty-desk-recent-${customer.id}');
      await tap(t, 'chart-visit-section-care-header');
      expect(find.text('관리사 판단: 등·하체를 낮은 강도로 관리하기로 함'), findsOneWidget);
      await tap(t, 'care-open-consult');
      await tap(t, 'consult-intake-edit');
      await enter(t, '한 문장으로', '오늘은 등만 관리하고 싶어요');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      record = store.findChartById(draft.id)!.visitRecord;
      expect(record.consultApplied, isFalse);
      expect(
        record.consultGenerated['director_assessment'],
        '등·하체를 낮은 강도로 관리하기로 함',
      );
      expect(record.treatmentSteps.single['area'], '등');
      expect(find.text('상담 내용 확인·적용 필요'), findsOneWidget);
      expect(find.text('관리사 판단: 등·하체를 낮은 강도로 관리하기로 함'), findsNothing);
      expect(store.chartVisitDraftsFor(customer.id).length, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
  }

  testWidgets(
    'wizard shows actual care instead of goals in result and report',
    (t) async {
      final s =
          ChartVisitSession.fresh(
              id: 'visit',
              startedAt: DateTime(2026, 9, 30),
              safety: const SafetySnapshot(),
            )
            ..consult = ConsultPhase.summarized
            ..consultApplied = true
            ..summaryJudgement = '하체의 불편을 확인하고 강도 조절';
      s.steps
        ..clear()
        ..add(CareStepDraft(title: '수기 관리', area: '하체'));
      s.goals.add('탄력');
      s.reactions.add('따가움');
      preview.active = s;
      await t.pumpWidget(const MaterialApp(home: ChartVisitFlowPage()));
      await t.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tap(t, 'chart-visit-next');
      }
      expect(find.text('관리사 판단: 하체의 불편을 확인하고 강도 조절'), findsOneWidget);
      await tap(t, 'chart-visit-next');
      expect(find.text('1. 수기 관리 · 하체'), findsOneWidget);
      expect(find.text('관리 중 특이 반응: 따가움'), findsOneWidget);
      await tap(t, 'result-open-care');
      expect(find.byKey(const Key('care-consult-context')), findsOneWidget);
      await tap(t, 'chart-visit-next');
      await tap(t, 'chart-visit-next');
      expect(find.text('수기 관리 · 하체'), findsOneWidget);
      expect(find.text('탄력'), findsNothing);
      expect(s.steps.single.title, '수기 관리');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('unapproved text and absent care cannot become treatment facts', (
    t,
  ) async {
    final s =
        ChartVisitSession.fresh(
            id: 'empty',
            startedAt: DateTime.now(),
            safety: const SafetySnapshot(allergy: ''),
          )
          ..summaryJudgement = '아직 확인하지 않은 판단'
          ..consult = ConsultPhase.summarized;
    s.steps.clear();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ConsultationCareContext(session: s, onEdit: () {}),
                PerformedCareContext(session: s, onEdit: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('아직 확인하지 않은 판단'), findsNothing);
    expect(find.text('상담 내용 확인·적용 필요'), findsOneWidget);
    expect(find.text('관리 내용 기록 없음'), findsOneWidget);
    expect(find.text('관리 중 특이 반응: 특이 반응 기록 없음'), findsOneWidget);
    expect(s.steps, isEmpty);
    expect(s.changes, isEmpty);
  });

  testWidgets(
    'comparison has no invented baseline and preserves conflicting result until saved',
    (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final s = ChartVisitSession.fresh(
        id: 'scores',
        startedAt: DateTime.now(),
        safety: const SafetySnapshot(),
      );
      preview.active = s;
      await t.pumpWidget(const MaterialApp(home: ChartVisitFlowPage()));
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tap(t, 'chart-visit-next');
      }
      await tap(t, 'chart-visit-add-change');
      expect(find.text('관리 전 점수 기록 없음'), findsOneWidget);
      await tap(t, 'visit-change-after-2');
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('visit-change-save')))
            .onPressed,
        isNull,
      );
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(s.changes, isEmpty);

      s.scores['redness'] = 5;
      await tap(t, 'chart-visit-add-change');
      expect(find.text('오늘 문진 · 관리 전 5/5'), findsOneWidget);
      await tap(t, 'visit-change-after-3');
      await tap(t, 'visit-change-save');
      expect(s.changes.single.from, 5);
      expect(s.changes.single.to, 3);
      s.scores['redness'] = 4;
      preview.touch();
      await t.pumpAndSettle();
      expect(find.text('관리 전 기준 변경됨 · 변화 재확인'), findsOneWidget);
      expect(s.changes.single.from, 5);
      await tap(t, 'visit-change-edit-홍조');
      expect(find.text('오늘 문진 · 관리 전 4/5'), findsOneWidget);
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(s.changes.single.from, 5);
      await tap(t, 'visit-change-edit-홍조');
      await tap(t, 'visit-change-save');
      expect(s.changes.single.from, 4);
      expect(s.changes.single.to, 3);
      expect(find.text('관리 전 기준 변경됨 · 변화 재확인'), findsNothing);
      expect(s.scores['redness'], 4);
      expect(t.takeException(), isNull);
    },
  );
}
