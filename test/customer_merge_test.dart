import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/customer_merge_service.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('local merge combines charts and memberships for duplicate customers', () async {
    final store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());

    final shopId = store.shop.id;
    final now = DateTime.now();

    final primary = Customer(
      id: 'cust-primary',
      shopId: shopId,
      name: '하얀광부',
      phone: '01085878542',
      lastTreatmentDate: now.subtract(const Duration(days: 3)),
      treatmentType: '페이스',
      memberships: const [],
    );
    final secondary = Customer(
      id: 'cust-secondary',
      shopId: shopId,
      name: '하얀광부',
      phone: '01085878542',
      lastTreatmentDate: now.subtract(const Duration(days: 7)),
      treatmentType: '페이스',
      memberships: const [],
    );

    store.customers
      ..clear()
      ..addAll([primary, secondary]);

    store.charts
      ..clear()
      ..addAll([
        CustomerChart(
          id: 'ch-1',
          shopId: shopId,
          customerId: primary.id,
          visitNumber: 1,
          careName: '페이스',
          visitChecked: true,
          visitCheckedAt: now.subtract(const Duration(days: 3)),
        ),
        CustomerChart(
          id: 'ch-2',
          shopId: shopId,
          customerId: secondary.id,
          visitNumber: 1,
          careName: '페이스',
          visitChecked: true,
          visitCheckedAt: now.subtract(const Duration(days: 7)),
        ),
      ]);

    final preview = CustomerMergeService.buildPreview(
      selected: [primary, secondary],
      charts: store.charts,
      reviews: store.reviews,
    );
    expect(preview.suggestedPrimaryId, primary.id);
    expect(preview.totalChartsAfter, 2);

    final result = await store.mergeShopCustomers(
      primaryId: primary.id,
      sourceIds: [secondary.id],
    );

    expect(result.mergedIds, [secondary.id]);
    expect(store.customers.where((c) => c.name == '하얀광부').length, 1);
    expect(store.charts.where((c) => c.customerId == primary.id).length, 2);
    expect(
      store.charts.map((c) => c.visitNumber).toList()..sort(),
      [1, 2],
    );
  });
}
