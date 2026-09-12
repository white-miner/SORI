import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/before_after_compare_page.dart';
import 'package:sori/views/chart_management_page.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('photo tab opens B/A compare, not chart management', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.charts.add(
      CustomerChart(
        id: 'ba-chart-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 1,
        careName: '리프팅',
        beforeImageUrl: 'https://example.com/b.jpg',
        afterImageUrl: 'https://example.com/a.jpg',
        createdAt: DateTime(2026, 9, 1),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => CustomerChartPage(
            store: store,
            customerId: customer.id,
          ),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    await tester.tap(find.text('사진'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final row = find.byKey(const Key('customer-chart-photo-row-ba-chart-1'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BeforeAfterComparePage), findsOneWidget);
    expect(find.byType(ChartManagementPage), findsNothing);
  });

  test('timeline stays on chart management; photo tab uses compare', () {
    final src =
        File('lib/views/customer_chart/customer_chart_page.dart').readAsStringSync();
    expect(src.contains('_TimelineTab('), isTrue);
    expect(
      src.contains('onTapChart: (c) => _openChartManagement(chartId: c.id)'),
      isTrue,
    );
    expect(
      src.contains('onTapChart: (c) => _openBeforeAfterCompare(chart: c)'),
      isTrue,
    );
  });
}
