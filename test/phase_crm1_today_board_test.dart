import 'package:flutter_test/flutter_test.dart';

import 'package:sori/crm_kernel/models/care_schedule_entry.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('CrmStore snapshot counts scheduled and unwritten', () async {
    final store = SoriStore();
    await store.refreshCareScheduleEntries(force: true);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final at = DateTime(day.year, day.month, day.day, 14, 30);

    if (store.customers.isEmpty) {
      expect(store.crm.snapshotForDay(day).scheduledCount, 0);
      return;
    }

    final customer = store.customers.first;
    await store.addManualCareSchedule(
      scheduledAt: at,
      customerName: customer.name,
      customerId: customer.id,
      careLabel: '테스트 케어',
    );

    final snap = store.crm.snapshotForDay(day);
    expect(snap.scheduledCount, greaterThan(0));
    expect(snap.orbitItems.first.displayName, isNotEmpty);
  });

  test('submitCareScheduleLead creates customerLead entry', () async {
    final store = SoriStore();
    final shopId = store.shop.id;
    final preferred = DateTime.now().add(const Duration(days: 2));

    final entry = await store.submitCareScheduleLead(
      shopId: shopId,
      customerName: '리드 고객',
      customerPhone: '01012345678',
      preferredAt: preferred,
      careLabel: '상담',
    );

    expect(entry.source, CareScheduleSource.customerLead);
    expect(
      store.careScheduleEntries.any((e) => e.id == entry.id),
      isTrue,
    );
  });
}
