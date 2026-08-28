import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/point_shop.dart';

void main() {
  test('boost gift impact report includes reach and bookmarks', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final chart = hot.first.chart;

    await repo.purchaseCustomerEcho(customerId: 'cust-r', amount: 100);
    final bought = await repo.purchaseFanBoost(
      customerId: 'cust-r',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chart.id,
      targetShopId: hot.first.shop.id,
      fanDisplayName: '리포트테스트',
    );
    expect(bought.ok, isTrue);

    await repo.toggleCaseBookmark(chart.id);

    final reports = await repo.loadBoostGiftImpactReports('cust-r');
    expect(reports, isNotEmpty);
    expect(reports.first.estimatedReach, greaterThan(0));
    expect(reports.first.bookmarksSinceGift, greaterThanOrEqualTo(1));
  });

  test('shop sponsorship impact aggregates gifts and thanks', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final shopId = hot.first.shop.id;

    await repo.purchaseCustomerEcho(customerId: 'cust-a', amount: 100);
    final bought = await repo.purchaseFanBoost(
      customerId: 'cust-a',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: hot.first.chart.id,
      targetShopId: shopId,
      fanDisplayName: '민지',
    );
    expect(bought.ok, isTrue);

    final impactBefore = await repo.loadShopSponsorshipImpact(shopId);
    expect(impactBefore.giftCount, greaterThanOrEqualTo(1));
    expect(impactBefore.echoTotal, greaterThan(0));

    final gifts = await repo.loadMyBoostGifts('cust-a');
    await repo.sendThankYouWhisper(fanGiftId: gifts.first.fanGiftId);

    final impactAfter = await repo.loadShopSponsorshipImpact(shopId);
    expect(impactAfter.thankYousSent, greaterThanOrEqualTo(1));
    expect(impactAfter.pendingThanks, lessThan(impactBefore.pendingThanks + 1));
  });

  test('special supporter gift appears in impact reports', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final hot = await repo.loadCommunityHotCases(limit: 1);

    await repo.purchaseCustomerEcho(customerId: 'cust-vip', amount: 300);
    final r = await repo.purchaseSpecialSupporterGift(
      customerId: 'cust-vip',
      sku: PointShopItem.catalogSpecialGold.sku,
      targetType: 'chart',
      targetId: hot.first.chart.id,
      targetShopId: hot.first.shop.id,
      fanDisplayName: 'VIP',
    );
    expect(r.ok, isTrue);

    final reports = await repo.loadBoostGiftImpactReports('cust-vip');
    expect(reports.any((g) => g.isSpecialGift), isTrue);
    expect(reports.first.boostStillActive, isTrue);
  });
}
