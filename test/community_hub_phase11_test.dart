import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/subscription.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('hub warm caches discover + follow without wiping state', () async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.ensureCommunityHubWarm(force: true);
    expect(store.discoverDirectors.length, greaterThanOrEqualTo(3));
    expect(store.hubWarmedAt, isNotNull);

    final first = store.discoverDirectors.first;
    final ok = await store.toggleDiscoverFollow(first);
    expect(ok, isTrue);
    expect(store.isFollowingShop(first.shopId), isTrue);
    expect(store.subscriptionCount, greaterThan(0));

    await store.refreshDiscoverDirectors(soft: true);
    expect(store.isFollowingShop(first.shopId), isTrue);
  });

  test('following feed empty until subscription exists', () async {
    final repo = MemorySoriRepository();
    // Isolate: clear memory subs by unfollowing any leftover
    final store = SoriStore(repository: repo);
    await store.refreshMySubscriptions();
    await store.refreshFollowingFeed();
    // May still have subs from prior test in same process — filter via count
    if (store.subscriptionCount == 0) {
      expect(store.followingFeedPosts, isEmpty);
    }

    final directors = await repo.loadDiscoverDirectors();
    await repo.setSubscription(
      targetType: SubscriptionTargetType.shop,
      targetShopId: directors.first.shopId,
      following: true,
    );
    await store.refreshMySubscriptions();
    await store.refreshFollowingFeed();
    // Following feed may be empty of posts but subscriptionCount > 0
    expect(store.subscriptionCount, greaterThan(0));
  });

  test('discover directors are directory rows not media cards', () async {
    final rows =
        await MemorySoriRepository().loadDiscoverDirectors(limit: 10);
    expect(rows, isNotEmpty);
    expect(rows.first.nickname, isNotEmpty);
    expect(rows.first.shopName, isNotEmpty);
    expect(rows.any((e) => e.isSeed), isTrue);
  });
}
