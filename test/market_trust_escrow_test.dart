import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';

void main() {
  test('market listing inquiry and escrow flow', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final post = await repo.insertCommunityPost(
      shopId: 'shop-1',
      authorUserId: 'u1',
      title: 'LDM 중고',
      body: '판매합니다',
      postType: CommunityPostType.marketplace,
      marketListing: const MarketListingDraft(
        deviceName: 'LDM',
        price: 500000,
      ),
    );
    expect(post.listing, isNotNull);
    final listingId = post.listing!.id;

    final scored = await repo.loadMarketListingsScored(deviceName: 'LDM');
    expect(scored, isNotEmpty);

    final inquiry = await repo.createMarketListingInquiry(
      listingId: listingId,
      message: '구매 문의',
    );
    expect(inquiry.ok, isTrue);

    final held = await repo.holdMarketEscrow(listingId: listingId);
    expect(held.ok, isTrue);
    expect(held.status, 'held');

    final done = await repo.completeMarketEscrow(listingId);
    expect(done.ok, isTrue);
  });

  test('market listings sorted by trust score desc', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    await repo.insertCommunityPost(
      shopId: 'shop-a',
      authorUserId: 'u1',
      title: 'A',
      body: 'a',
      postType: CommunityPostType.marketplace,
      marketListing: const MarketListingDraft(deviceName: 'RF', price: 100),
    );
    await repo.toggleCaseBookmark('chart-1');
    await repo.purchaseCustomerEcho(customerId: 'c1', amount: 200);
    final hot = await repo.loadCommunityHotCases(limit: 1);
    if (hot.isNotEmpty) {
      await repo.purchaseFanBoost(
        customerId: 'c1',
        sku: 'boost_bump_4h',
        targetType: 'chart',
        targetId: hot.first.chart.id,
        targetShopId: hot.first.shop.id,
        fanDisplayName: '후원',
      );
    }

    final rows = await repo.loadMarketListingsScored(deviceName: 'RF');
    expect(rows, isNotEmpty);
    expect(rows.first.sellerTrustScore, greaterThanOrEqualTo(0));
  });
}
