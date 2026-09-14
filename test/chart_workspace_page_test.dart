import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Chart tab shows drawer and file rails without cabinet UI', (
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
    await tester.tap(find.text('Chart'));
    await _settle(tester);

    expect(find.byType(ChartWorkspacePage), findsOneWidget);
    expect(find.byKey(const Key('chart-drawer-rail')), findsOneWidget);
    expect(find.byKey(const Key('chart-drawer-drawer-a')), findsOneWidget);
    expect(find.text('서랍 A'), findsOneWidget);
    expect(find.byKey(const Key('chart-file-rail')), findsOneWidget);
    expect(find.text('신규'), findsOneWidget);
    expect(find.text('서랍 B'), findsNothing);
    expect(find.textContaining('번호 준비 중'), findsNothing);
    expect(find.byKey(const Key('file-cabinet-drawer-a')), findsNothing);

    // 파일 rail 주 라벨은 No.N — 등록순 첫 고객은 항상 No.1.
    expect(find.text('No.1'), findsOneWidget);
    // 고객 이름이 rail 라벨을 대체하지 않는다.
    for (final c in store.customers) {
      expect(find.text(c.name), findsNothing);
    }
    // 화면 중앙을 채우던 구 빈 상태 배너는 사라졌다.
    expect(find.text('파일을 선택하거나 신규로 등록하세요'), findsNothing);
  });

  testWidgets('selecting file shows document strip and visit rail', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(Key('chart-file-file-${customer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(Key('chart-file-title-${customer.id}')), findsOneWidget);
    // 헤더는 "No.N · 이름" — No가 이름을 대체하지 않고 함께 존재한다.
    final fileNumber = fileDisplayNumberFor(store, customer);
    expect(
      find.text(fileHeaderLabel(fileNumber, customer)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chart-doc-consent')), findsOneWidget);
    expect(find.text('전자 동의서'), findsOneWidget);
    expect(find.byKey(const Key('chart-doc-photo')), findsOneWidget);
    expect(find.byKey(const Key('chart-doc-payment')), findsOneWidget);
    expect(find.byKey(const Key('chart-visit-rail')), findsOneWidget);

    final items = buildVisitRailItems(store, customer.id);
    expect(items, isNotEmpty);
    expect(
      items.first.kind,
      anyOf(VisitRailKind.newDraft, VisitRailKind.today),
    );
    if (items.first.kind == VisitRailKind.newDraft) {
      expect(find.text('신규 작성'), findsWidgets);
      expect(find.byKey(const Key('chart-new-sheet-title')), findsOneWidget);
      expect(find.text('고객 상태'), findsOneWidget);
      expect(find.text('니즈'), findsOneWidget);
      expect(find.text('상담'), findsOneWidget);
      expect(find.text('제공 서비스'), findsOneWidget);
      expect(find.text('사진'), findsWidgets);
      expect(find.text('결제'), findsWidgets);
      expect(find.text('다음 방문 참고'), findsOneWidget);
    } else {
      expect(find.text('Today'), findsWidgets);
    }
  });

  testWidgets('new customer opens add sheet without auto chart writer', (
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

  testWidgets('saving new draft switches rail to Today on same chart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    // Prefer a customer without today's chart.
    final customer = store.customers.firstWhere(
      (c) => todayChartForCustomer(store, c.id) == null,
      orElse: () => store.customers.first,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChartWorkspacePage(store: store)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(Key('chart-file-file-${customer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    if (todayChartForCustomer(store, customer.id) != null) {
      // Already has Today — skip create path for this seed.
      expect(find.text('Today'), findsWidgets);
      return;
    }

    expect(find.byKey(const Key('chart-new-sheet-title')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('chart-new-service')),
      '테스트케어\n본문',
    );
    await tester.tap(find.byKey(const Key('chart-new-sheet-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(todayChartForCustomer(store, customer.id), isNotNull);
    expect(find.text('Today'), findsWidgets);
    expect(find.byKey(const Key('chart-new-sheet-title')), findsNothing);
    expect(find.textContaining('Today ·'), findsOneWidget);
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
