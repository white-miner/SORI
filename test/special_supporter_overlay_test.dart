import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/point_shop.dart';

void main() {
  test('special supporter stacks overlay without cancelling boost', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 5);
    expect(hot, isNotEmpty);
    final chart = hot.first.chart;
    final shopId = hot.first.shop.id;

    await repo.purchaseCustomerEcho(customerId: 'cust-test-1', amount: 200);
    await repo.purchaseCustomerEcho(customerId: 'cust-test-2', amount: 200);

    final shopBoost = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chart.id,
    );
    expect(shopBoost.ok, isTrue);

    final micro = await repo.purchaseFanBoost(
      customerId: 'cust-test-1',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chart.id,
      targetShopId: shopId,
      fanDisplayName: '골드후원자',
    );
    expect(micro.ok, isTrue);

    final placementsBefore = (await repo.loadActiveBoostPlacements())
        .where((p) => p.targetId == chart.id && p.status == 'active')
        .length;
    expect(placementsBefore, greaterThan(0));

    final special = await repo.purchaseSpecialSupporterGift(
      customerId: 'cust-test-2',
      sku: PointShopItem.catalogSpecialGold.sku,
      targetType: 'chart',
      targetId: chart.id,
      targetShopId: shopId,
      fanDisplayName: 'VIP후원자',
    );
    expect(special.ok, isTrue, reason: special.message);

    final placementsAfter = (await repo.loadActiveBoostPlacements())
        .where((p) => p.targetId == chart.id && p.status == 'active')
        .length;
    expect(placementsAfter, placementsBefore);

    final overlays = await repo.loadActivePremiumOverlays();
    expect(
      overlays.any((o) => o.targetId == chart.id && o.isGold),
      isTrue,
    );
  });

  test('platinum overlay is returned in active list', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final chart = hot.first.chart;

    await repo.purchaseCustomerEcho(customerId: 'cust-plat', amount: 300);

    final r = await repo.purchaseSpecialSupporterGift(
      customerId: 'cust-plat',
      sku: PointShopItem.catalogSpecialPlatinum.sku,
      targetType: 'chart',
      targetId: chart.id,
      targetShopId: hot.first.shop.id,
      fanDisplayName: '플래티넘후원자',
    );
    expect(r.ok, isTrue, reason: r.message);

    final overlays = await repo.loadActivePremiumOverlays();
    final hit = overlays.where((o) => o.targetId == chart.id).toList();
    expect(hit, isNotEmpty);
    expect(hit.first.isPlatinum, isTrue);
  });
}
