import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_care_page.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('customer care tab does not invent 28-day next visit or show notes', () {
    final src = File('lib/views/customer_care_page.dart').readAsStringSync();
    expect(src.contains('Duration(days: 28)'), isFalse);
    expect(src.contains('다음 권장'), isFalse);
    expect(src.contains('nextUpcomingForCustomer'), isTrue);
    expect(src.contains('다음 방문'), isTrue);
    expect(src.contains('customer-care-next-visit'), isTrue);
    expect(src.contains('nextCare.note'), isFalse);
    expect(src.contains('customerPhone'), isFalse);
    expect(src.contains('directorInsight'), isFalse);
    expect(src.contains('treatmentSummary'), isFalse);
    expect(src.contains('원장 인사이트'), isFalse);
  });

  testWidgets('care tab shows scheduled next visit without internal note', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
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
    final existing = store.chartsForCustomer(customer.id);
    if (existing.isNotEmpty) {
      final idx = store.charts.indexWhere((c) => c.id == existing.first.id);
      if (idx >= 0) {
        store.charts[idx] = existing.first.copyWith(
          directorInsight: '원장만 보는 판단',
        );
      }
    }
    store.careScheduleEntries = [
      CareScheduleEntry(
        id: 'cust-next',
        shopId: store.shop.id,
        scheduledAt: DateTime(now.year, now.month, now.day).add(
          const Duration(days: 3, hours: 14, minutes: 30),
        ),
        customerName: customer.name,
        customerId: customer.id,
        careLabel: '리프팅',
        note: '원장만 보는 내부 메모',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CustomerCareTab(store: store))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-care-next-visit')), findsOneWidget);
    expect(find.textContaining('다음 방문'), findsWidgets);
    expect(find.textContaining('리프팅'), findsWidgets);
    expect(find.textContaining('원장만 보는 내부 메모'), findsNothing);
    expect(find.textContaining('원장만 보는 판단'), findsNothing);
    expect(find.textContaining('다음 권장'), findsNothing);
  });
}
