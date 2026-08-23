import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('Fan-Boost burns customer Echo and never touches shop settlement',
      () async {
    final repo = MemorySoriRepository();
    const customerId = 'cust-fan-1';
    const shopId = 'shop-target';

    await repo.purchaseCustomerEcho(customerId: customerId, amount: 120);
    final cwBefore = await repo.loadCustomerEchoWallet(customerId);
    await repo.creditSettlementForTest(shopId: shopId, amount: 50000);
    final shopBefore = await repo.loadPointWallet(shopId);
    expect(shopBefore.settlementBalance, 50000);

    // Seed a chart via hot cases then boost that chart's shop explicitly
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();
    final chartId = store.communityHotCases.isNotEmpty
        ? store.communityHotCases.first.chart.id
        : 'chart-hot-1';
    final targetShop = store.communityHotCases.isNotEmpty
        ? store.communityHotCases.first.shop.id
        : shopId;

    await repo.creditSettlementForTest(shopId: targetShop, amount: 10000);
    final settleBefore =
        (await repo.loadPointWallet(targetShop)).settlementBalance;

    final result = await repo.purchaseFanBoost(
      customerId: customerId,
      sku: 'boost_local_2h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: targetShop,
      fanDisplayName: '민지',
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 29);
    expect(result.placement?.source, 'fan_boost');
    expect(result.placement?.fanDisplayName, '민지');
    expect(result.settlementBalance, settleBefore);

    final settleAfter =
        (await repo.loadPointWallet(targetShop)).settlementBalance;
    expect(settleAfter, settleBefore);

    final cw = await repo.loadCustomerEchoWallet(customerId);
    expect(cw.pointTotal, cwBefore.pointTotal - 29);
    expect(cw.settlementBalance, 0);

    final notes = await repo.loadShopNotifications(targetShop);
    expect(notes, isNotEmpty);
    expect(notes.first['kind'], 'fan_boost');
    expect(notes.first['body'], contains('민지'));
  });

  test('Fan-Boost pins local feed with Fans source', () async {
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();
    expect(store.communityHotCases, isNotEmpty);

    final item = store.communityHotCases.first;
    await repo.purchaseCustomerEcho(customerId: 'cust-2', amount: 55);
    final bought = await repo.purchaseFanBoost(
      customerId: 'cust-2',
      sku: 'boost_local_2h',
      targetType: 'chart',
      targetId: item.chart.id,
      targetShopId: item.shop.id,
      fanDisplayName: '팬A',
    );
    expect(bought.ok, isTrue);

    await store.refreshCommunityHotCases();
    final local = store.localBoostPinnedFeed();
    expect(local.first.chart.id, item.chart.id);
    expect(local.first.isBoosted, isTrue);
    expect(local.first.isFanBoosted, isTrue);
    expect(local.first.boostSource, 'fan_boost');
    expect(local.first.fanDisplayName, '팬A');
  });

  test('insufficient Fan-Boost returns gap for IAP bridge', () async {
    final repo = MemorySoriRepository();
    // default customer free 20E < 89E
    final result = await repo.purchaseFanBoost(
      customerId: 'cust-poor',
      sku: 'boost_local_1d',
      targetType: 'chart',
      targetId: 'chart-x',
      targetShopId: 'shop-x',
    );
    expect(result.ok, isFalse);
    expect(result.insufficient, isTrue);
    expect(result.need, 89);
  });
}
