import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/sori_point_wallet.dart';

void main() {
  test('unlock deducts Echo and credits author Echo only (not settlement)',
      () async {
    final repo = MemorySoriRepository();
    const authorShop = 'shop-author';
    const viewerShop = 'shop-viewer';

    final post = await repo.insertCommunityPost(
      shopId: authorShop,
      postType: CommunityPostType.interior,
      title: '잠금 노하우',
      body: '원본 본문 시크릿 팁',
      visibility: CommunityVisibility.goldPlus,
    );

    await repo.purchaseSoriPoints(
      shopId: viewerShop,
      amount: 55,
      sku: 'sori_e_55',
    );
    await repo.creditSettlementForTest(
      shopId: authorShop,
      amount: 10000,
      note: '중고 판매 정산',
    );

    final before = await repo.loadPointWallet(viewerShop);
    expect(before.pointTotal, greaterThanOrEqualTo(5));

    final authorBefore = await repo.loadPointWallet(authorShop);
    expect(authorBefore.settlementBalance, 10000);

    final result = await repo.unlockCommunityPostWithPoints(
      postId: post.id,
      viewerShopId: viewerShop,
      cost: 5,
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 5);
    expect(result.creatorShare, 3); // 70% of 5E
    expect(result.creatorCurrency, 'echo');
    expect(result.post?['body'], '원본 본문 시크릿 팁');

    final afterViewer = await repo.loadPointWallet(viewerShop);
    expect(afterViewer.pointTotal, before.pointTotal - 5);
    expect(afterViewer.settlementBalance, before.settlementBalance);

    final afterAuthor = await repo.loadPointWallet(authorShop);
    expect(afterAuthor.freeBalance, authorBefore.freeBalance + 3);
    expect(afterAuthor.settlementBalance, 10000);
  });

  test('request_settlement_withdraw touches settlement only, never Echo',
      () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-settle';

    await repo.purchaseSoriPoints(shopId: shopId, amount: 120);
    await repo.creditSettlementForTest(shopId: shopId, amount: 50000);

    final before = await repo.loadPointWallet(shopId);
    expect(before.pointTotal, greaterThanOrEqualTo(120));
    expect(before.settlementBalance, 50000);

    final raw = await repo.requestSettlementWithdraw(
      shopId: shopId,
      amount: 15000,
      bankAccountMask: '***1234',
    );

    expect(raw?['ok'], isTrue);
    expect(raw?['settlement_balance'], 35000);
    expect(raw?['point_free_balance'], before.freeBalance);
    expect(raw?['point_paid_balance'], before.paidBalance);

    final after = await repo.loadPointWallet(shopId);
    expect(after.pointTotal, before.pointTotal);
    expect(after.settlementBalance, 35000);
  });

  test('Echo IAP packs follow 1E=₩100 peg anchors', () {
    expect(SoriPointWallet.krwPerEcho, 100);
    expect(PointPack.catalog.map((e) => e.echo).toList(), [55, 120, 330]);
    expect(PointPack.catalog.first.priceLabel, '₩5,500');
  });
}
