import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/recommend_feed_category.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/models/unified_feed_item.dart';

void main() {
  final shop = const Shop(id: 's1', name: '테스트샵', naverPlaceUrl: '');
  final chart = CustomerChart(
    id: 'c1',
    shopId: 's1',
    customerId: 'u1',
    visitNumber: 1,
  );
  final caseItem = CommunityCaseItem(chart: chart, shop: shop);

  test('ba maps to ba_case', () {
    final item = UnifiedFeedItem.ba(caseItem);
    expect(RecommendFeedCategory.fromUnified(item), RecommendFeedCategory.baCase);
    expect(RecommendFeedCategory.fromUnified(item).label, '전후');
  });

  test('daySectionLabel buckets', () {
    final now = DateTime(2026, 9, 11, 12);
    expect(
      RecommendFeedCategory.daySectionLabel(DateTime(2026, 9, 11, 8), now: now),
      '오늘',
    );
    expect(
      RecommendFeedCategory.daySectionLabel(DateTime(2026, 9, 10, 8), now: now),
      '어제',
    );
    expect(
      RecommendFeedCategory.daySectionLabel(DateTime(2026, 9, 8, 8), now: now),
      '이번 주',
    );
    expect(
      RecommendFeedCategory.daySectionLabel(DateTime(2026, 8, 1, 8), now: now),
      '이전',
    );
  });
}
