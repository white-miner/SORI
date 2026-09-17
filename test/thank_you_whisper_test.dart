import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/point_shop.dart';

void main() {
  test('thank you whisper links to fan gift and my boost gifts list', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final chart = hot.first.chart;
    final shopId = hot.first.shop.id;

    await repo.purchaseCustomerEcho(customerId: 'cust-a', amount: 100);

    final bought = await repo.purchaseFanBoost(
      customerId: 'cust-a',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chart.id,
      targetShopId: shopId,
      fanDisplayName: '민지',
    );
    expect(bought.ok, isTrue);

    final gifts = await repo.loadMyBoostGifts('cust-a');
    expect(gifts, isNotEmpty);
    final giftId = gifts.first.fanGiftId;
    expect(gifts.first.hasThankYou, isFalse);

    final notifs = await repo.loadSupporterNotifications(shopId);
    expect(notifs.any((n) => n.fanGiftId == giftId), isTrue);
    expect(notifs.first.canThank, isTrue);

    final sent = await repo.sendThankYouWhisper(fanGiftId: giftId);
    expect(sent.postId, isNotEmpty);

    final giftsAfter = await repo.loadMyBoostGifts('cust-a');
    expect(giftsAfter.first.hasThankYou, isTrue);

    final notifsAfter = await repo.loadSupporterNotifications(shopId);
    final row = notifsAfter.firstWhere((n) => n.fanGiftId == giftId);
    expect(row.hasThankYou, isTrue);
    expect(row.canThank, isFalse);
  });

  test('special supporter gift appears in my boost gifts', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);

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

    final gifts = await repo.loadMyBoostGifts('cust-vip');
    expect(gifts.any((g) => g.isSpecialGift), isTrue);
  });
}
