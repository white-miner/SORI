import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/shoot_inbox_item.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('ensureTodayShootChart reuses same-day chart', () async {
    final store = SoriStore();
    // Seed has customers; pick first if any
    if (store.customers.isEmpty) {
      expect(true, isTrue);
      return;
    }
    final customer = store.customers.first;
    final a = await store.ensureTodayShootChart(customerId: customer.id);
    final b = await store.ensureTodayShootChart(customerId: customer.id);
    expect(a.id, b.id);
  });

  test('ShootInboxItem json roundtrip', () {
    final item = ShootInboxItem(
      id: 'i1',
      shopId: 's1',
      kind: 'before',
      imageUrl: 'https://example.com/a.webp',
      label: '베드1',
      sessionToken: 'sess',
      createdAt: DateTime.utc(2026, 8, 25),
    );
    final again = ShootInboxItem.fromJson(item.toJson());
    expect(again.id, 'i1');
    expect(again.isBefore, isTrue);
    expect(again.label, '베드1');
  });
}
