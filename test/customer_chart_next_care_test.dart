import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('customer chart shows next care CTA from existing schedule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    final now = DateTime.now();
    store.careScheduleEntries = [
      CareScheduleEntry(
        id: 'next-1',
        shopId: store.shop.id,
        scheduledAt: DateTime(now.year, now.month, now.day, 18),
        customerName: customer.name,
        customerId: customer.id,
        careLabel: '리프팅',
      ),
    ];

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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-chart-next-care')), findsOneWidget);
    expect(find.text('케어 시작'), findsOneWidget);
    expect(find.textContaining('리프팅'), findsWidgets);
  });

  testWidgets('customer chart hides next care when none is scheduled', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    store.careScheduleEntries = [];

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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.byKey(const Key('customer-chart-next-care')), findsNothing);
  });
}
