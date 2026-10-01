import 'package:sori/features/chart_visit/chart_visit_live.dart';
import 'package:sori/features/chart_visit/consultation_intake_context.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/chart_visit_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sori/features/chart_visit/chart_visit_flow_page.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/routing/sori_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = ChartVisitPreviewStore.instance;
  testWidgets('wizard distinguishes unknown safety and permits body-only intake', (tester) async {
    store.debugResetForTest();
    final session = ChartVisitSession.fresh(id: 'body', startedAt: DateTime(2026, 10, 1),
        safety: const SafetySnapshot());
    store.active = session;
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ChartVisitFlowPage()));
    await tester.pumpAndSettle();
    expect(find.text('미확인'), findsNWidgets(6));
    await tester.tap(find.byKey(const Key('chart-visit-safety-edit')));
    await tester.pumpAndSettle();
    final no = find.text('없음').first;
    await tester.ensureVisible(no);
    await tester.tap(no);
    await tester.pumpAndSettle();
    expect(session.safety.allergy, '없음');
    expect(session.safety.medication, isEmpty);
    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('현재 상태를 남겨둘게요'), findsOneWidget);
    expect(find.text('수분'), findsNothing);
    final body = find.text('등 불편');
    await tester.ensureVisible(body);
    await tester.tap(body);
    await tester.pumpAndSettle();
    expect(session.concerns, ['등 불편']);
    expect(find.text('언제부터 신경 쓰였나요?'), findsOneWidget);
    expect(session.scores.values.every((v) => v == 0), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.debugResetForTest();
  });

  testWidgets('missing history does not infer a first visit or normal state', (
    tester,
  ) async {
    store.history = [];
    final session = ChartVisitSession.fresh(
      id: 'new',
      startedAt: DateTime(2026, 9, 30),
      safety: const SafetySnapshot(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsultationIntakeContext(
            session: session,
            onEdit: () {},
            onEditSafety: () {},
          ),
        ),
      ),
    );
    expect(find.text('이전 기록 없음 · 오늘 문진을 보며 상담하세요.'), findsOneWidget);
    expect(find.text('첫 방문'), findsNothing);
    store.history = [
      pastVisitFromChart(
        const CustomerChart(
          id: 'unknown',
          shopId: 'shop',
          customerId: 'customer',
          visitNumber: 1,
        ),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsultationIntakeContext(
            key: const Key('unknown'),
            session: session,
            onEdit: () {},
            onEditSafety: () {},
          ),
        ),
      ),
    );
    expect(find.text('방문 날짜 미기록'), findsOneWidget);
    expect(find.text('실제 관리: 기록 없음'), findsOneWidget);
  });
  test(
    'past adapter retains actual care separately from goals and missing date',
    () {
      final past = pastVisitFromChart(
        const CustomerChart(
          id: 'old',
          shopId: 'shop',
          customerId: 'customer',
          visitNumber: 1,
          careName: '등 관리',
          visitRecord: ChartVisitRecord(
            careGoals: ['이완'],
            nextCareNote: '등 상태 확인',
          ),
        ),
      );
      expect(past.performedCare, '등 관리');
      expect(past.record.careGoals, ['이완']);
      expect(past.record.nextCareNote, '등 상태 확인');
      expect(past.hasKnownDate, isFalse);
    },
  );

  for (final width in [360.0, 1024.0]) {
    testWidgets('past visit selection is read-only at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = ChartVisitSession.fresh(
        id: 'today',
        startedAt: DateTime(2026, 9, 30),
        safety: const SafetySnapshot(),
      );
      PastVisit visit(String id, DateTime date, ChartVisitRecord record) =>
          PastVisit(
            id: id,
            date: date,
            title: '목표를 관리명으로 쓰면 안 됨',
            safety: const SafetySnapshot(),
            record: record,
          );
      store.history = [
        visit('today', today.startedAt, const ChartVisitRecord()),
        visit(
          'draft',
          DateTime(2026, 9, 29),
          const ChartVisitRecord(flowStatus: 'draft'),
        ),
        visit('future', DateTime(2026, 10, 1), const ChartVisitRecord()),
        visit(
          'body',
          DateTime(2026, 9, 23),
          const ChartVisitRecord(
            careGoals: ['이완'],
            treatmentSteps: [
              {'sort': 1, 'title': '수기 관리', 'area': '등'},
            ],
            reactionTypes: ['열감'],
            nextCareNote: '등 불편 지속 여부 확인',
            homeAm: '가벼운 움직임',
            nextCareTiming: '2주',
          ),
        ),
        visit('face', DateTime(2026, 9, 2), const ChartVisitRecord()),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsultationIntakeContext(
                session: today,
                onEdit: () {},
                onEditSafety: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('실제 관리: 수기 관리 · 부위: 등'), findsOneWidget);
      expect(find.text('관리 중 특이 반응: 열감'), findsOneWidget);
      expect(find.text('당시 다음 계획: 등 불편 지속 여부 확인'), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('consult-past-select')),
      );
      expect(dropdown.items!.map((item) => item.value), ['body', 'face']);
      await tester.tap(find.byKey(const Key('consult-past-expand')));
      await tester.pumpAndSettle();
      expect(find.text('당시 관리 목표: 이완'), findsOneWidget);
      expect(find.text('당시 홈케어 AM: 가벼운 움직임'), findsOneWidget);
      await tester.tap(find.byKey(const Key('consult-past-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026.09.02 · 방문 기록').last);
      await tester.pumpAndSettle();
      expect(find.text('실제 관리: 기록 없음'), findsOneWidget);
      expect(find.text('관리 중 특이 반응: 기록 없음'), findsOneWidget);
      expect(today.goals, isEmpty);
      expect(today.summaryJudgement, isEmpty);
      expect(today.reactions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsultationIntakeContext(
                session: today,
                onEdit: () {},
                onEditSafety: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('consult-past-select')),
            )
            .value,
        'face',
      );
      expect(find.text('지난 기록 접기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  setUp(() => ChartVisitPreviewStore.instance.debugResetForTest());

  testWidgets('sample chart home opens a new visit and keeps past history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: AppPaths.chartVisitPreview,
      routes: [
        GoRoute(
          path: AppPaths.chartVisitPreview,
          builder: (_, _) => const ChartVisitHomePage(),
          routes: [
            GoRoute(
              path: 'write',
              builder: (_, _) => const ChartVisitFlowPage(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('김소리'), findsOneWidget);
    expect(find.text('민감성 · 레티놀 사용'), findsOneWidget);
    expect(find.text('진정 · 수분관리'), findsOneWidget);
    expect(find.textContaining('알레르기 없음'), findsNothing);
    await tester.scrollUntilVisible(find.text('장벽관리'), 300);
    expect(find.text('장벽관리'), findsOneWidget);
    expect(find.byKey(const Key('chart-visit-history-v-0902')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('chart-visit-start')),
      -400,
    );

    await tester.tap(find.byKey(const Key('chart-visit-start')));
    await tester.pumpAndSettle();

    expect(find.text('오늘 확인'), findsOneWidget);
    expect(find.text('Safety Check'), findsNothing);
    expect(find.text('지난 방문 문장은 바뀌지 않습니다.'), findsNothing);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('최대 3개까지 선택할 수 있어요.'), findsOneWidget);
    expect(find.text('언제부터 신경 쓰였나요?'), findsNothing);

    await tester.tap(find.text('홍조'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건조'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('피부결'));
    await tester.pumpAndSettle();
    expect(find.text('언제부터 신경 쓰였나요?'), findsOneWidget);
    expect(find.text('관리사 피부 체크'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('상담 전'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('chart-visit-consult-start')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-visit-consult-start')));
    await tester.pump();
    expect(find.text('상담 기록 중'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('chart-visit-consult-end')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-visit-consult-end')));
    await tester.pumpAndSettle();
    expect(find.text('아직 차트에 적용되지 않았습니다.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('chart-visit-apply')));
    await tester.tap(find.byKey(const Key('chart-visit-apply')));
    await tester.pumpAndSettle();
    expect(find.text('차트에 적용됨'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('TODAY CARE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 변화'), findsOneWidget);
    expect(find.text('Before'), findsWidgets);
    expect(find.text('After'), findsWidgets);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    expect(find.text('TODAY COMPLETE'), findsNothing);
    expect(find.text('저장됨'), findsNothing);
    expect(find.text('홍조 · 건조 · 피부결'), findsOneWidget);
    expect(find.textContaining('4 → 2'), findsWidgets);
    expect(find.text('고객 CHART'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('chart-visit-to-home')));
    await tester.tap(find.byKey(const Key('chart-visit-to-home')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-visit-home')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('장벽관리'), 300);
    expect(find.text('장벽관리'), findsOneWidget);
    expect(find.byKey(const Key('chart-visit-history-v-0902')), findsOneWidget);
  });

  testWidgets('larger text does not overflow home or the visit steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: AppPaths.chartVisitPreview,
      routes: [
        GoRoute(
          path: AppPaths.chartVisitPreview,
          builder: (_, _) => const ChartVisitHomePage(),
          routes: [
            GoRoute(
              path: 'write',
              builder: (_, _) => const ChartVisitFlowPage(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('chart-visit-start')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('chart-visit-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홍조'));
    await tester.pumpAndSettle();
    expect(find.text('관리사 피부 체크'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('INFO 있음 opens the detail field and keeps typed text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ChartVisitFlowPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chart-visit-safety-edit')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    final before = fields.evaluate().length;

    // 첫 '있음' = 알레르기.
    final yes = find.text('있음').first;
    await tester.ensureVisible(yes);
    await tester.tap(yes);
    await tester.pumpAndSettle();
    expect(fields, findsNWidgets(before + 1));

    final allergyField = fields.first;
    await tester.enterText(allergyField, '견과류');
    await tester.pumpAndSettle();
    expect(ChartVisitPreviewStore.instance.active!.safety.allergy, '견과류');
    expect(fields, findsNWidgets(before + 1));

    final row = find.ancestor(of: allergyField, matching: find.byType(Column)).first;
    final no = find.descendant(of: row, matching: find.text('없음'));
    await tester.ensureVisible(no);
    await tester.tap(no);
    await tester.pumpAndSettle();
    expect(fields, findsNWidgets(before));
    expect(ChartVisitPreviewStore.instance.active!.safety.allergy, '없음');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bottom next stays above the keyboard inset', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 280)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const ChartVisitFlowPage(),
      ),
    );
    await tester.pumpAndSettle();

    final next = tester.getRect(find.byKey(const Key('chart-visit-next')));
    expect(next.bottom, lessThanOrEqualTo(844 - 280));
    expect(next.top, greaterThan(0));
  });
}
