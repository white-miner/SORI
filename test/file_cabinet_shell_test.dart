import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/views/file_cabinet/file_cabinet_shell.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Chart tab always shows drawer A from live store customers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    expect(store.customers, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
    );
    await _settle(tester);

    await tester.tap(find.text('Chart'));
    await _settle(tester);

    expect(find.byKey(const Key('file-cabinet-drawer-a')), findsOneWidget);
    expect(find.text('서랍 A'), findsOneWidget);
    expect(find.textContaining('파일 준비 중'), findsNothing);
    expect(find.textContaining('아직 준비 중'), findsNothing);
    expect(find.text(store.customers.first.name), findsWidgets);
    expect(find.text('번호\n준비 중'), findsWidgets);
  });

  testWidgets('drawer A file opens CustomerChartPage not the writer', (
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
          builder: (_, __) => Scaffold(
            body: FileCabinetShell(store: store),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.byKey(const Key('file-cabinet-drawer-a')), findsOneWidget);
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
      MaterialApp(home: Scaffold(body: FileCabinetShell(store: store))),
    );
    await tester.pump();

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
}
