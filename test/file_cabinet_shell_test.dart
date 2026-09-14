import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/views/file_cabinet/file_cabinet_shell.dart';

import 'support/tolerant_golden_comparator.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('file-cabinet-drawer-a')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 280));
}

Color? _cabinetBodyColor(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find.byKey(const Key('file-cabinet-body')),
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Chart tab closed cabinet hides files search and add', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisitLauncherPage(store: store)),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Chart'));
    await _settle(tester);

    expect(find.byKey(const Key('file-cabinet-drawer-a')), findsOneWidget);
    expect(find.text('서랍 A'), findsOneWidget);
    expect(find.text('파일 ${store.customers.length}개'), findsOneWidget);
    expect(find.byKey(const Key('file-cabinet-search')), findsNothing);
    expect(find.byKey(Key('file-cabinet-file-${customer.id}')), findsNothing);
    expect(find.byKey(const Key('file-cabinet-add')), findsNothing);
    expect(find.text('새 고객 파일'), findsNothing);
    expect(find.textContaining('번호 준비 중'), findsNothing);
    expect(find.textContaining('파일 준비 중'), findsNothing);
    expect(_cabinetBodyColor(tester), CabinetFinish.ivory.body);
  });

  testWidgets('drawer tap opens spines then tap closes them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = store.customers.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FileCabinetShell(store: store)),
      ),
    );
    await tester.pump();

    expect(find.text(customer.name), findsNothing);
    expect(find.byKey(const Key('file-cabinet-search')), findsNothing);

    await _openDrawer(tester);

    expect(find.byKey(const Key('file-cabinet-search')), findsOneWidget);
    expect(find.text(customer.name), findsOneWidget);
    expect(find.text(customer.phone), findsOneWidget);
    expect(find.text('새 고객 파일'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('번호 준비 중'), findsNothing);

    await tester.tap(find.byKey(const Key('file-cabinet-handle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text(customer.name), findsNothing);
    expect(find.byKey(const Key('file-cabinet-search')), findsNothing);
    expect(find.text('새 고객 파일'), findsNothing);
  });

  testWidgets('file spine opens CustomerChartPage not the writer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = store.customers.first;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: FileCabinetShell(store: store)),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await _openDrawer(tester);

    await tester.tap(find.byKey(Key('file-cabinet-file-${customer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerChartPage), findsOneWidget);
    expect(find.text(customer.name), findsWidgets);
  });

  testWidgets('new customer file opens add sheet and list updates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final before = store.customers.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FileCabinetShell(store: store)),
      ),
    );
    await tester.pump();
    await _openDrawer(tester);

    await tester.tap(find.byKey(const Key('file-cabinet-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('새 고객 파일'), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '서랍파일손님');
    await tester.enterText(fields.at(2), '01000011111');
    await tester.tap(find.text('등록'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.customers.length, before + 1);
    expect(find.text('서랍파일손님'), findsOneWidget);
    expect(find.byType(CustomerChartPage), findsNothing);
  });

  testWidgets('long press opens local color settings and repaints cabinet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final beforeCount = store.customers.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FileCabinetShell(store: store)),
      ),
    );
    await tester.pump();

    expect(_cabinetBodyColor(tester), CabinetFinish.ivory.body);

    await tester.longPress(find.byKey(const Key('file-cabinet-drawer-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('캐비넷 설정'), findsOneWidget);
    expect(find.text('캐비넷 색상'), findsOneWidget);
    expect(find.text('아이보리'), findsOneWidget);
    expect(find.text('세이지'), findsOneWidget);
    expect(find.text('슬레이트'), findsOneWidget);
    expect(find.text('차콜'), findsOneWidget);
    expect(find.text('버건디'), findsOneWidget);
    expect(find.text('네이비'), findsOneWidget);

    await tester.tap(find.byKey(const Key('file-cabinet-swatch-sage')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_cabinetBodyColor(tester), CabinetFinish.sage.body);
    expect(store.customers.length, beforeCount);

    await tester.tap(find.byKey(const Key('file-cabinet-swatch-charcoal')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_cabinetBodyColor(tester), CabinetFinish.charcoal.body);
    expect(store.customers.length, beforeCount);
  });

  testWidgets('cabinet visual goldens', (tester) async {
    useTolerantGoldens(
      'test/file_cabinet_shell_test.dart',
      maxDiffPercent: 2.0,
    );
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: FileCabinetShell(store: store)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    await expectLater(
      find.byType(FileCabinetShell),
      matchesGoldenFile('goldens/cabinet_closed_ivory.png'),
    );

    await _openDrawer(tester);
    await expectLater(
      find.byType(FileCabinetShell),
      matchesGoldenFile('goldens/cabinet_open_ivory.png'),
    );
    await expectLater(
      find.byType(FileCabinetShell),
      matchesGoldenFile('goldens/cabinet_open_spines.png'),
    );

    await tester.longPress(find.byKey(const Key('file-cabinet-drawer-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cabinet_settings_sheet.png'),
    );

    await tester.tap(find.byKey(const Key('file-cabinet-swatch-sage')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    Navigator.of(tester.element(find.text('캐비넷 설정'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(FileCabinetShell),
      matchesGoldenFile('goldens/cabinet_sage.png'),
    );
  });
}
