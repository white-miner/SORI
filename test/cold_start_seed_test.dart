import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_official.dart';

void main() {
  test('cold-start feed spans ~14 days and includes master personas', () async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.refreshCommunityHotCases();
    final cases = store.communityHotCases;
    expect(cases.length, greaterThanOrEqualTo(12));

    final masters = cases.where(
      (e) =>
          e.authorNickname == '서연' ||
          e.authorNickname == '준호' ||
          e.authorNickname == '하늘',
    );
    expect(masters.length, greaterThanOrEqualTo(12));

    final shops = masters.map((e) => e.displayShopAffiliation).toSet();
    expect(shops, containsAll(['글로우핏 청담', '바디아틀리에 성수', '루미에르 한남']));

    final times = masters
        .map((e) => e.chart.createdAt)
        .whereType<DateTime>()
        .toList();
    expect(times.length, greaterThanOrEqualTo(12));
    times.sort();
    final span = times.last.difference(times.first).inDays;
    expect(span, greaterThanOrEqualTo(7));

    // Not all "just now"
    final recent = times.where(
      (t) => DateTime.now().difference(t).inMinutes < 30,
    );
    expect(recent.length, lessThan(times.length));
  });

  test('hit cold-start cases expose Fan-Boost Facepile data', () async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.refreshCommunityHotCases();
    final boosted = store.communityHotCases.where(
      (e) => e.isFanBoosted && e.effectiveFanSupporters.length >= 3,
    );
    expect(boosted, isNotEmpty);
    expect(boosted.first.effectiveFanSupporters.first.name, isNotEmpty);
  });

  test('official seed still present alongside cold-start pack', () async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.refreshCommunityHotCases();
    final official = store.communityHotCases.where(
      (e) => e.shop.displayIsOfficial || e.shop.slug == SoriOfficial.slug,
    );
    expect(official, isNotEmpty);
  });
}
