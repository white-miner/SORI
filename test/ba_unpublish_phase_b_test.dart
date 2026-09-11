import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/models/community_post.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('unpublishBaFromCommunity clears caseShared and keeps chart/photos',
      () async {
    final store = SoriStore();
    final chart = CustomerChart(
      id: 'ba-chart-1',
      shopId: store.shop.id,
      customerId: 'c1',
      visitNumber: 1,
      careName: '수분',
      caseShared: true,
      signatureUrl: 'sig',
      consentMarketing: true,
      beforeImageUrl: 'https://example.com/b.jpg',
      afterImageUrl: 'https://example.com/a.jpg',
    );
    store.charts.add(chart);
    store.communityPosts.add(
      CommunityPost(
        id: 'post-1',
        shopId: store.shop.id,
        postType: CommunityPostType.caseShare,
        title: 'BA',
        body: '',
        sourceChartId: chart.id,
        createdAt: DateTime.now(),
      ),
    );

    final ok = await store.unpublishBaFromCommunity(chart.id);
    expect(ok, isTrue);
    final next = store.findChartById(chart.id)!;
    expect(next.caseShared, isFalse);
    expect(next.beforeImageUrl, 'https://example.com/b.jpg');
    expect(next.afterImageUrl, 'https://example.com/a.jpg');
    expect(
      store.communityPosts.any((p) => p.sourceChartId == chart.id),
      isFalse,
    );
  });
}
