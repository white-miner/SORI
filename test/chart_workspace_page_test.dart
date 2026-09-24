import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/chart_workspace/chart_empty_desk.dart';
import 'package:sori/views/chart_workspace/chart_index_label.dart';
import 'package:sori/views/chart_workspace/chart_index_palette.dart';
import 'package:sori/views/chart_workspace/chart_workspace_page.dart';
import 'package:sori/views/chart_workspace/chart_workspace_state.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

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
    expect(find.text('이전 서랍 보기'), findsOneWidget);

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

  testWidgets(
    'legacy toggle restores drawer-file-embedded ChartVisitHomePage path',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      final customer = store.customers.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChartWorkspacePage(store: store)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('chart-empty-desk-legacy-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ChartEmptyDesk), findsNothing);
      expect(find.byKey(const Key('chart-drawer-rail')), findsOneWidget);
      expect(find.byKey(const Key('chart-drawer-drawer-a')), findsOneWidget);
      expect(find.text('서랍 A'), findsOneWidget);
      expect(find.byKey(const Key('chart-file-rail')), findsOneWidget);
      expect(find.text('신규'), findsOneWidget);
      expect(find.text('No.1'), findsOneWidget);
      expect(find.text('서랍에서 파일을 선택하세요'), findsOneWidget);

      await tester.tap(find.byKey(Key('chart-file-file-${customer.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(Key('chart-file-title-${customer.id}')), findsOneWidget);
      final fileNumber = fileDisplayNumberFor(store, customer);
      expect(
        find.text(fileHeaderLabel(fileNumber, customer)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chart-doc-consent')), findsOneWidget);
      expect(find.text('전자 동의서'), findsOneWidget);
      expect(find.byKey(const Key('chart-doc-photo')), findsOneWidget);
      expect(find.byKey(const Key('chart-doc-payment')), findsOneWidget);
      expect(find.byType(ChartVisitHomePage), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-home')), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-start')), findsOneWidget);
      expect(find.text('오늘 방문'), findsOneWidget);
      expect(find.text(customer.name), findsWidgets);
      expect(find.byKey(const Key('chart-drawer-rail')), findsOneWidget);
      expect(find.byKey(const Key('chart-file-rail')), findsOneWidget);
    },
  );

  testWidgets('legacy new customer opens add sheet without auto chart writer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final before = store.customers.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChartWorkspacePage(store: store)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-empty-desk-legacy-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('chart-file-file-new')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('새 고객 파일'), findsWidgets);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '워크스페이스손님');
    await tester.enterText(fields.at(1), '01000022222');
    await tester.tap(find.text('등록'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.customers.length, before + 1);
    expect(find.byType(CustomerChartPage), findsNothing);
  });

  testWidgets(
    'legacy file rail label colors follow last-digit palette',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      final customer = store.customers.first;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChartWorkspacePage(store: store))),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('chart-empty-desk-legacy-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final newLabel = tester.widget<ChartIndexLabel>(
        find.byKey(const Key('chart-file-file-new')),
      );
      expect(newLabel.baseColor, kChartIndexNoNumberColor);

      final noOneLabel = tester.widget<ChartIndexLabel>(
        find.byKey(Key('chart-file-file-${customer.id}')),
      );
      expect(
        noOneLabel.baseColor,
        ChartIndexPaletteStore.instance.colorForNumber(
          fileDisplayNumberFor(store, customer),
        ),
      );
      expect(noOneLabel.baseColor, isNot(kChartIndexNoNumberColor));
    },
  );

  testWidgets(
    'legacy visit home after file select has no visit rail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      final customer = store.customers.firstWhere(
        (c) => todayChartForCustomer(store, c.id) == null,
        orElse: () => store.customers.first,
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChartWorkspacePage(store: store))),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('chart-empty-desk-legacy-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(Key('chart-file-file-${customer.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('chart-visit-home')), findsOneWidget);
      expect(find.text('오늘 방문'), findsOneWidget);
      expect(find.byKey(const Key('chart-visit-rail')), findsNothing);
    },
  );

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
