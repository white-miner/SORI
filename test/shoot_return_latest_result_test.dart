import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/before_after_compare_page.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('capture save returns to chart latest result via existing compare route', () {
    final chartSrc =
        File('lib/views/customer_chart/customer_chart_page.dart').readAsStringSync();
    final hubSrc = File('lib/views/shoot_hub_page.dart').readAsStringSync();
    expect(chartSrc.contains('revealLatestResult'), isTrue);
    expect(chartSrc.contains('_openBeforeAfterCompare(chart: updated)'), isTrue);
    expect(hubSrc.contains('CustomerChartPage('), isTrue);
    expect(hubSrc.contains('revealLatestResult: true'), isTrue);
    expect(hubSrc.contains('_shootUnbound'), isTrue);
  });

  testWidgets('revealLatestResult opens B/A compare for the saved visit', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.charts.add(
      CustomerChart(
        id: 'latest-result-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 3,
        careName: '리프팅',
        beforeImageUrl: 'https://example.com/b.jpg',
        afterImageUrl: 'https://example.com/a.jpg',
        createdAt: DateTime(2026, 9, 12),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CustomerChartPage(
            store: store,
            customerId: customer.id,
            revealChartId: 'latest-result-1',
            revealLatestResult: true,
          ),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.byType(BeforeAfterComparePage), findsOneWidget);
  });
}
