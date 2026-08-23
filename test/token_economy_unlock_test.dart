import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';

void main() {
  test('unlock deducts points and credits author points only (not settlement)',
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

    final locked = post.copyWith(isBodyLocked: true);
    expect(locked.isBodyLocked, isTrue);

    await repo.purchaseSoriPoints(
      shopId: viewerShop,
      amount: 500,
      sku: 'test_pack',
    );
    await repo.creditSettlementForTest(
      shopId: authorShop,
      amount: 10000,
      note: '중고 판매 정산',
    );

    final before = await repo.loadPointWallet(viewerShop);
    expect(before.pointTotal, greaterThanOrEqualTo(500));

    final authorBefore = await repo.loadPointWallet(authorShop);
    expect(authorBefore.settlementBalance, 10000);

    final result = await repo.unlockCommunityPostWithPoints(
      postId: post.id,
      viewerShopId: viewerShop,
      cost: 500,
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 500);
    expect(result.creatorShare, 350);
    expect(result.creatorCurrency, 'point');
    expect(result.post?['body'], '원본 본문 시크릿 팁');
    expect(result.post?['is_body_locked'], isFalse);

    final afterViewer = await repo.loadPointWallet(viewerShop);
    expect(afterViewer.pointTotal, before.pointTotal - 500);
    expect(afterViewer.settlementBalance, before.settlementBalance);

    final afterAuthor = await repo.loadPointWallet(authorShop);
    expect(afterAuthor.freeBalance, authorBefore.freeBalance + 350);
    expect(afterAuthor.settlementBalance, 10000);
  });

  test('request_settlement_withdraw touches settlement only, never points',
      () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-settle';

    await repo.purchaseSoriPoints(shopId: shopId, amount: 2000);
    await repo.creditSettlementForTest(shopId: shopId, amount: 50000);

    final before = await repo.loadPointWallet(shopId);
    expect(before.pointTotal, greaterThanOrEqualTo(2000));
    expect(before.settlementBalance, 50000);

    final raw = await repo.requestSettlementWithdraw(
      shopId: shopId,
      amount: 15000,
      bankAccountMask: '***1234',
    );

    expect(raw?['ok'], isTrue);
    expect(raw?['amount'], 15000);
    expect(raw?['settlement_balance'], 35000);
    expect(raw?['point_free_balance'], before.freeBalance);
    expect(raw?['point_paid_balance'], before.paidBalance);

    final after = await repo.loadPointWallet(shopId);
    expect(after.pointTotal, before.pointTotal);
    expect(after.settlementBalance, 35000);
    expect(after.settlementPending, 15000);

    final txs = await repo.loadSettlementTransactions(shopId);
    expect(txs, isNotEmpty);
    expect(txs.first.kind, 'withdraw_request');
    expect(txs.first.amount, -15000);
  });

  test('cannot withdraw using points when settlement is empty', () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-no-settle';

    await repo.purchaseSoriPoints(shopId: shopId, amount: 9999);
    final w = await repo.loadPointWallet(shopId);
    expect(w.pointTotal, greaterThanOrEqualTo(9999));
    expect(w.settlementBalance, 0);

    expect(
      () => repo.requestSettlementWithdraw(shopId: shopId, amount: 1000),
      throwsA(isA<StateError>()),
    );

    final after = await repo.loadPointWallet(shopId);
    expect(after.pointTotal, w.pointTotal);
    expect(after.settlementBalance, 0);
  });
}
