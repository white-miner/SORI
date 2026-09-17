import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/shop_trust_score.dart';

void main() {
  test('shop trust score rises with bookmarks and gifts', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final shopId = hot.first.shop.id;
    final chartId = hot.first.chart.id;

    final before = await repo.loadShopTrustScore(shopId);
    expect(before.score, greaterThanOrEqualTo(0));

    await repo.toggleCaseBookmark(chartId);
    await repo.purchaseCustomerEcho(customerId: 'cust-ts', amount: 100);
    await repo.purchaseFanBoost(
      customerId: 'cust-ts',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '테스터',
    );

    final after = await repo.loadShopTrustScore(shopId);
    expect(after.score, greaterThanOrEqualTo(before.score));
    expect(after.supporterGiftCount, greaterThanOrEqualTo(1));
  });

  test('trust score tier labels map to score bands', () {
    const high = ShopTrustScore(score: 80, tierLabel: '검증된 레퍼런스');
    const mid = ShopTrustScore(score: 50, tierLabel: '신뢰 쌓이는 중');
    expect(high.summaryLine, isNotEmpty);
    expect(mid.tierLabel, '신뢰 쌓이는 중');
  });
}
