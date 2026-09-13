import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_care_page.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty next-care CTAs reuse addManualCareSchedule, not a fake 28-day label', () {
    final chartSrc =
        File('lib/views/customer_chart/customer_chart_page.dart').readAsStringSync();
    final careSrc =
        File('lib/views/customer_care_page.dart').readAsStringSync();
    expect(chartSrc.contains('addManualCareSchedule'), isTrue);
    expect(chartSrc.contains('다음 케어 일정 잡기'), isTrue);
    expect(chartSrc.contains('customer-chart-schedule-next'), isTrue);
    expect(careSrc.contains('다음 방문이 아직 없어요'), isTrue);
    expect(careSrc.contains('Duration(days: 28)'), isFalse);
    expect(careSrc.contains('다음 권장'), isFalse);
    expect(careSrc.contains('nextCare.note'), isFalse);
  });

  testWidgets('demo customer chart offers schedule CTA when no next care exists', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.careScheduleEntries = [];

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-chart-schedule-next')), findsOneWidget);
    expect(find.text('다음 케어 일정 잡기'), findsOneWidget);
    expect(find.text('케어 시작'), findsNothing);
    expect(find.byKey(const Key('customer-chart-next-care')), findsNothing);
  });

  testWidgets('customer care empty next visit does not expose internals', (
    tester,
  ) async {
    final store = SoriStore();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final customer = store.customers.firstWhere((c) {
      for (final chart in store.chartsForCustomer(c.id)) {
        if (chart.homeCarePrescriptions.isEmpty) continue;
        final visit = chart.visitCheckedAt ?? chart.createdAt;
        if (visit == null) continue;
        final offset = today
            .difference(DateTime(visit.year, visit.month, visit.day))
            .inDays;
        if (offset >= 0 && offset <= 2) return false;
      }
      return true;
    });
    store.session = SessionUser(
      role: UserRole.customer,
      name: customer.name,
      phone: customer.phone,
      provider: SocialProvider.kakao,
      customerId: customer.id,
      onboardingComplete: true,
      activeMode: UserRole.customer,
    );
    store.careScheduleEntries = [];

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CustomerCareTab(store: store))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-care-next-visit-empty')), findsOneWidget);
    expect(find.text('다음 방문이 아직 없어요'), findsOneWidget);
    expect(find.byKey(const Key('customer-care-next-visit')), findsNothing);
    expect(find.textContaining('원장만 보는'), findsNothing);
    expect(find.textContaining('다음 권장'), findsNothing);
  });
}
