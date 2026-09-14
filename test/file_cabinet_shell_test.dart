import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/views/file_cabinet/file_cabinet_shell.dart';

/// FileCabinetShell은 Chart 탭에서 분리됨. 위젯 자체 회귀만 유지.

Future<void> _toggleDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('file-cabinet-drawer-a')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('isolated cabinet still toggles open by default', (tester) async {
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

    // Current shell defaults to open.
    expect(find.text('서랍 A'), findsOneWidget);
    expect(find.text(customer.name), findsOneWidget);

    await _toggleDrawer(tester);
    expect(find.text(customer.name), findsNothing);
  });

  testWidgets('cabinet file spine still opens CustomerChartPage', (
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

    await tester.tap(find.byKey(Key('file-cabinet-file-${customer.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerChartPage), findsOneWidget);
  });
}
