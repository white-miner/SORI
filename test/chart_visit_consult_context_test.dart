import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/chart_visit/chart_visit_flow_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/models/chart_visit_record.dart';

void main() {
  final store = ChartVisitPreviewStore.instance;
  setUp(store.debugResetForTest);

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const ChartVisitFlowPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'chart-visit-next');
    await tap(tester, 'chart-visit-next');
  }

  for (final size in [const Size(360, 800), const Size(1024, 900)]) {
    testWidgets(
      'manual consult uses actual intake and survives edits at $size',
      (tester) async {
        final s = ChartVisitSession.fresh(
          id: 'same-visit',
          startedAt: DateTime(2026, 9, 29),
          safety: const SafetySnapshot(allergy: '금속 접촉 주의', medication: ''),
        );
        store.active = s;
        store.live = true;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ChartVisitFlowPage(),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'chart-visit-next');
        await tester.tap(find.text('건조'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('3~6개월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3~6개월'));
        await tester.pumpAndSettle();
        final wish = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '한 문장으로',
        );
        await tester.ensureVisible(wish);
        await tester.pumpAndSettle();
        await tester.enterText(wish, '오늘은 세안 후 당김이 줄었으면 해요');
        await tap(tester, 'chart-visit-next');
        expect(find.text('고민: 건조'), findsOneWidget);
        expect(find.text('기간: 3~6개월'), findsOneWidget);
        expect(find.text('원하는 변화: 오늘은 세안 후 당김이 줄었으면 해요'), findsOneWidget);
        expect(find.textContaining('불편 정도:'), findsNothing);
        expect(find.text('알레르기: 금속 접촉 주의'), findsOneWidget);
        expect(find.text('안전정보 · 오늘 확인 여부 미확인'), findsOneWidget);
        expect(
          find.byKey(const Key('chart-visit-consult-start')),
          findsNothing,
        );
        await tap(tester, 'consult-intake-expand');
        expect(find.text('복용약: 미확인'), findsOneWidget);
        expect(find.text('관리사 피부 체크 · 입력한 점수'), findsNothing);
        await tap(tester, 'consult-intake-expand');
        await tap(tester, 'chart-visit-consult-manual');
        expect(s.summaryConcerns, isEmpty);
        expect(s.summaryWish, isEmpty);
        expect(s.consultSeconds, 0);
        expect(
          find.byKey(const Key('chart-visit-consult-clock')),
          findsNothing,
        );
        final judgement = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '관리사 판단',
        );
        await tester.ensureVisible(judgement);
        await tester.pumpAndSettle();
        await tester.enterText(judgement, '당김 관찰 후 보습 방향을 함께 결정');
        await tap(tester, 'consult-intake-edit');
        await tester.ensureVisible(wish);
        await tester.pumpAndSettle();
        await tester.enterText(wish, '당김과 거친 느낌을 줄이고 싶어요');
        await tap(tester, 'chart-visit-next');
        expect(s.summaryJudgement, '당김 관찰 후 보습 방향을 함께 결정');
        expect(find.text('원하는 변화: 당김과 거친 느낌을 줄이고 싶어요'), findsOneWidget);
        await tap(tester, 'chart-visit-apply');
        expect(s.consultApplied, isTrue);
        await tap(tester, 'chart-visit-next');
        await tap(tester, 'chart-visit-back');
        expect(find.text('당김 관찰 후 보습 방향을 함께 결정'), findsOneWidget);
        await tap(tester, 'consult-intake-edit');
        await tester.ensureVisible(wish);
        await tester.pumpAndSettle();
        await tester.enterText(wish, '문진 재확인 후 바뀐 희망');
        await tap(tester, 'chart-visit-next');
        expect(find.text('문진 변경됨 · 상담 내용 재확인'), findsOneWidget);
        expect(s.summaryJudgement, '당김 관찰 후 보습 방향을 함께 결정');
        await tap(tester, 'chart-visit-apply');
        expect(find.text('문진 변경됨 · 상담 내용 재확인'), findsNothing);
        expect(s.summaryJudgement, '당김 관찰 후 보습 방향을 함께 결정');
        expect(s.consultApplied, isTrue);
        await tap(tester, 'consult-intake-expand');
        final safetyEdit = find.text('안전정보 수정');
        await tester.ensureVisible(safetyEdit);
        await tester.pumpAndSettle();
        await tester.tap(safetyEdit);
        await tester.pumpAndSettle();
        await tap(tester, 'chart-visit-safety-edit');
        final allergy = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '알레르기',
        );
        await tester.ensureVisible(allergy);
        await tester.pumpAndSettle();
        await tester.enterText(allergy, '금속과 접착제 접촉 주의');
        await tester.pump();
        expect(find.text('저장 중...'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('저장됨'), findsOneWidget);
        await tap(tester, 'chart-visit-next');
        await tap(tester, 'chart-visit-next');
        expect(find.text('알레르기: 금속과 접착제 접촉 주의'), findsOneWidget);
        expect(find.text('문진 변경됨 · 상담 내용 재확인'), findsOneWidget);
        await tap(tester, 'chart-visit-apply');
        expect(find.text('문진 변경됨 · 상담 내용 재확인'), findsNothing);
        expect(s.summaryJudgement, '당김 관찰 후 보습 방향을 함께 결정');
        expect(s.id, 'same-visit');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'reopened record shows stored intake independently of consultation',
    (tester) async {
      store.live = true;
      store.active = ChartVisitSession.fromRecord(
        id: 'reopened',
        startedAt: DateTime(2026, 9, 29),
        record: ChartVisitRecord(
          concerns: const ['등 불편'],
          duration: '오래 앉은 뒤',
          discomfortScore: 2,
          desiredChange: '등이 편안했으면',
          scores: const {'hydration': 4},
          safety: const {'allergy': '접착제'},
          consultApproved: const {'director_assessment': '기존 상담 판단'},
          consultApplied: true,
        ),
      );
      await open(tester, const Size(360, 800));
      expect(find.text('고민: 등 불편'), findsOneWidget);
      expect(find.text('기간: 오래 앉은 뒤'), findsOneWidget);
      expect(find.text('불편 정도: 2/5'), findsOneWidget);
      expect(find.text('원하는 변화: 등이 편안했으면'), findsOneWidget);
      expect(find.text('기존 상담 판단'), findsOneWidget);
      await tap(tester, 'consult-intake-expand');
      expect(find.text('수분 4/5'), findsOneWidget);
      expect(find.text('알레르기: 접착제'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tap(tester, 'consult-intake-edit');
      final wish = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '한 문장으로',
      );
      await tester.ensureVisible(wish);
      await tester.pumpAndSettle();
      await tester.enterText(wish, '재확인한 뒤 달라진 희망');
      await tap(tester, 'chart-visit-next');
      expect(find.text('아직 차트에 적용되지 않았습니다.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, const Size(360, 800));
      expect(find.text('아직 차트에 적용되지 않았습니다.'), findsOneWidget);
      expect(find.text('기존 상담 판단'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('live mode cannot resume a stale simulated recording', (
    tester,
  ) async {
    store.live = true;
    store.active = ChartVisitSession.fresh(
      id: 'stale',
      startedAt: DateTime(2026, 9, 29),
      safety: const SafetySnapshot(),
    )..consult = ConsultPhase.recording;
    await open(tester, const Size(360, 800));
    expect(find.byKey(const Key('chart-visit-consult-clock')), findsNothing);
    expect(find.byKey(const Key('chart-visit-consult-start')), findsNothing);
    expect(find.byKey(const Key('chart-visit-consult-end')), findsNothing);
    await tap(tester, 'chart-visit-consult-manual');
    await tester.pump(const Duration(seconds: 3));
    expect(store.active!.consultSeconds, 0);
    expect(store.active!.summaryConcerns, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
