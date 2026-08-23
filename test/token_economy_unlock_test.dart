import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';

void main() {
  test('unlock_community_post_with_points deducts and returns unlocked body',
      () async {
    final repo = MemorySoriRepository();
    final authorShop = 'shop-author';
    final viewerShop = 'shop-viewer';

    final post = await repo.insertCommunityPost(
      shopId: authorShop,
      postType: CommunityPostType.interior,
      title: '잠금 노하우',
      body: '원본 본문 시크릿 팁',
      visibility: CommunityVisibility.goldPlus,
    );

    // Force locked flag as feed would.
    final locked = post.copyWith(isBodyLocked: true);
    expect(locked.isBodyLocked, isTrue);
    expect(locked.body, '원본 본문 시크릿 팁');

    await repo.purchaseSoriPoints(
      shopId: viewerShop,
      amount: 500,
      sku: 'test_pack',
    );

    final before = await repo.loadPointWallet(viewerShop);
    expect(before.totalBalance, greaterThanOrEqualTo(500));

    final result = await repo.unlockCommunityPostWithPoints(
      postId: post.id,
      viewerShopId: viewerShop,
      cost: 500,
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 500);
    expect(result.creatorShare, 350); // 70%
    expect(result.post?['body'], '원본 본문 시크릿 팁');
    expect(result.post?['is_body_locked'], isFalse);

    final afterViewer = await repo.loadPointWallet(viewerShop);
    expect(afterViewer.totalBalance, before.totalBalance - 500);

    final afterAuthor = await repo.loadPointWallet(authorShop);
    expect(afterAuthor.freeBalance, greaterThanOrEqualTo(350));
  });
}
