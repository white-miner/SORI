import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('과거 B&A 차트도 히스토리에 한 번씩 남는다', () {
    final store = SoriStore();
    final customer = store.customers.first;
    final chart = CustomerChart(
      id: 'past-case', customerId: customer.id, shopId: store.shop.id,
      visitNumber: 99, careName: '관리', treatmentSummary: '', directorInsight: '',
      concernChips: const [], firstVisitFearChips: const [], revisitFeedbackChips: const [],
      beforeImageUrl: 'https://example.com/past-b.webp',
      afterImageUrl: 'https://example.com/past-a.webp',
      createdAt: DateTime(2020, 1, 1), visitChecked: true,
    );
    store.charts.add(chart);
    expect(store.baCarouselSessions.where((s) => s.chartId == chart.id), hasLength(1));
  });

  test('NEW 거치가 차트를 만들지 않고 저장 후 연결은 수정 사진을 보존한다', () async {
    final store = SoriStore();
    final customer = store.customers.first;
    final count = store.charts.length;
    var pending = await store.captureIntoPendingBaSlot(
      kind: 'before', imageUrl: 'https://example.com/original-b.webp');
    pending = await store.attachBaPhoto(target: pending,
      kind: 'after', imageUrl: 'https://example.com/original-a.webp');
    expect(store.charts.length, count);
    expect(store.baPendingSession?.id, pending.id);
    final chart = await store.saveChartAndConfirmVisitAsync(
      customerId: customer.id, visitNumber: store.nextVisitNumber(customer.id),
      careName: '관리', treatmentSummary: '', directorInsight: '',
      concernChips: const [], firstVisitFearChips: const [], revisitFeedbackChips: const [],
      beforeImageUrl: 'https://example.com/replaced-b.webp',
      afterImageUrl: 'https://example.com/replaced-a.webp',
    );
    final linked = await store.bindSavedBaSessionToChart(target: pending, chart: chart);
    expect(linked.beforeImageUrl, chart.beforeImageUrl);
    expect(linked.afterImageUrl, chart.afterImageUrl);
    expect(store.baPendingSession, isNull);
    expect(store.baCarouselSessions.where((s) => s.chartId == chart.id), hasLength(1));
    await store.bindSavedBaSessionToChart(target: pending, chart: chart);
    expect(store.charts.where((c) => c.id == chart.id), hasLength(1));
  });
}
