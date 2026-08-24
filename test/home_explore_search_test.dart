import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/subscription.dart';
import 'package:sori/utils/home_explore_search.dart';

void main() {
  group('HomeExploreSearch', () {
    test('tokens strip hash and split whitespace', () {
      expect(
        HomeExploreSearch.tokens('  #테라노바  윤곽 '),
        ['테라노바', '윤곽'],
      );
    });

    test('exact shop name ranks above body match', () {
      final exact = HomeExploreSearch.scoreHaystacks(
        tokens: const ['테라노바'],
        exactName: '테라노바',
        tagsDevice: '',
        body: '',
      );
      final body = HomeExploreSearch.scoreHaystacks(
        tokens: const ['테라노바'],
        exactName: '다른샵',
        tagsDevice: '',
        body: '오늘은 테라노바 시술을 했어요',
      );
      expect(exact, greaterThan(body));
      expect(exact, greaterThanOrEqualTo(1000));
    });

    test('device tag ranks above body', () {
      final tag = HomeExploreSearch.scoreHaystacks(
        tokens: const ['테라노바'],
        exactName: 'SORI',
        tagsDevice: '테라노바 리프팅',
        body: '',
      );
      final body = HomeExploreSearch.scoreHaystacks(
        tokens: const ['테라노바'],
        exactName: 'SORI',
        tagsDevice: '',
        body: '테라노바 후기입니다',
      );
      expect(tag, greaterThan(body));
    });

    test('miss returns -1', () {
      expect(
        HomeExploreSearch.scoreHaystacks(
          tokens: const ['없는키워드'],
          exactName: 'SORI',
          tagsDevice: '윤곽',
          body: '리프팅',
        ),
        -1,
      );
    });

    test('isSearchablePost excludes whisper and seminar', () {
      const whisper = CommunityPost(
        id: '1',
        shopId: 's',
        postType: CommunityPostType.interior,
        body: 'x',
        isWhisper: true,
      );
      const seminar = CommunityPost(
        id: '2',
        shopId: 's',
        postType: CommunityPostType.seminar,
        body: 'x',
      );
      const interior = CommunityPost(
        id: '3',
        shopId: 's',
        postType: CommunityPostType.interior,
        body: 'x',
      );
      expect(HomeExploreSearch.isSearchablePost(whisper), isFalse);
      expect(HomeExploreSearch.isSearchablePost(seminar), isFalse);
      expect(HomeExploreSearch.isSearchablePost(interior), isTrue);
    });

    test('scoreCase and scoreDirector accept tokens', () {
      final item = CommunityCaseItem(
        chart: const CustomerChart(
          id: 'c1',
          shopId: 's1',
          customerId: 'u1',
          visitNumber: 1,
          careName: '테라노바 케어',
          deviceInfo: '테라노바',
        ),
        shop: const Shop(id: 's1', name: '강남샵', naverPlaceUrl: ''),
      );
      final tokens = HomeExploreSearch.tokens('테라노바');
      expect(HomeExploreSearch.scoreCase(item, tokens), greaterThan(0));

      const director = DiscoverDirector(
        shopId: 's1',
        shopName: '테라노바 클리닉',
        nickname: '김원장',
      );
      expect(HomeExploreSearch.scoreDirector(director, tokens), greaterThan(0));
    });
  });
}
