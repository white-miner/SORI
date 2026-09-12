import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/views/smart_guide_camera_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('photo tab missing-result CTA reuses guide camera, not a new schema', () {
    final src =
        File('lib/views/customer_chart/customer_chart_page.dart').readAsStringSync();
    expect(src.contains('SmartGuideCameraPage.open'), isTrue);
    expect(src.contains('patchChartAfterImage'), isTrue);
    expect(src.contains('needsAfterPhoto'), isTrue);
    expect(src.contains('After 촬영'), isTrue);
    expect(src.contains('결과 촬영'), isTrue);
  });

  testWidgets('photo tab offers capture CTA only when B/A is not comparable', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.charts.addAll([
      CustomerChart(
        id: 'missing-after-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 2,
        careName: '리프팅',
        beforeImageUrl: 'https://example.com/b.jpg',
        createdAt: DateTime(2026, 9, 10),
      ),
      CustomerChart(
        id: 'complete-ba-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 1,
        careName: '클렌징',
        beforeImageUrl: 'https://example.com/b2.jpg',
        afterImageUrl: 'https://example.com/a2.jpg',
        createdAt: DateTime(2026, 9, 1),
      ),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CustomerChartPage(
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

    final missingCta = find.byKey(
      const Key('customer-chart-photo-capture-missing-after-1'),
    );
    expect(missingCta, findsOneWidget);
    expect(find.text('After 촬영'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-chart-photo-capture-complete-ba-1')),
      findsNothing,
    );
    expect(find.byType(SmartGuideCameraPage), findsNothing);
  });
}
