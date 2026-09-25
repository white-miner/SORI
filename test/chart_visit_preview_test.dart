import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sori/features/chart_visit/chart_visit_flow_page.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/routing/sori_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.tap(find.byKey(const Key('chart-visit-consult-start')));
    await tester.pump();
    expect(find.text('상담 기록 중'), findsOneWidget);

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
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
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
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
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
