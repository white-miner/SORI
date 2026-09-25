import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/chart_workspace/chart_empty_desk.dart';
import 'package:sori/views/chart_workspace/chart_index_palette.dart';
import 'package:sori/views/chart_workspace/chart_workspace_page.dart';
import 'package:sori/views/chart_workspace/chart_workspace_state.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChartIndexPaletteStore.instance.debugResetForTest();
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
    'desk recent select embeds ChartVisitHomePage with chart-visit-start',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      final recent = List.of(store.customers)
        ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
      final customer = recent.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChartWorkspacePage(store: store)),
        ),
      );
      await tester.pump();

      expect(find.byType(ChartEmptyDesk), findsOneWidget);
      await tester.tap(
        find.byKey(Key('chart-empty-desk-recent-${customer.id}')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ChartEmptyDesk), findsNothing);
      expect(find.byType(ChartVisitHomePage), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-home')), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-start')), findsOneWidget);
      expect(find.text(customer.name), findsWidgets);
      expect(find.byKey(const Key('chart-drawer-rail')), findsNothing);
      expect(find.byKey(const Key('chart-file-rail')), findsNothing);
      expect(find.byKey(const Key('chart-desk-back')), findsOneWidget);

      final labels = find
          .descendant(
            of: find.byKey(const Key('chart-visit-start')),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .toList();
      expect(
        labels.any((t) => t == '오늘 방문' || t == '이어서 작성'),
        isTrue,
        reason: 'chart-visit-start must show 오늘 방문 or 이어서 작성, got $labels',
      );
    },
  );

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
