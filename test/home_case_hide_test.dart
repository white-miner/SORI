import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';

CustomerChart _baChart(String id, {DateTime? homeHiddenAt}) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: 'cus-1',
    visitNumber: 1,
    careName: '테스트',
    beforeImageUrl: 'https://example.com/$id-b.webp',
    afterImageUrl: 'https://example.com/$id-a.webp',
    createdAt: DateTime(2026, 9, 1),
    caseShared: true,
    homeHiddenAt: homeHiddenAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hideManagementCaseFromHome excludes from feed and keeps caseShared',
      () async {
    final store = SoriStore();
    store.charts
      ..clear()
      ..addAll([
        _baChart('c1'),
        _baChart('c2'),
      ]);

    expect(
      store.managementCaseCharts().map((c) => c.id).toSet(),
      {'c1', 'c2'},
    );

    final ok = await store.hideManagementCaseFromHome('c1');
    expect(ok, isTrue);

    expect(
      store.managementCaseCharts().map((c) => c.id).toList(),
      ['c2'],
    );

    final hidden = store.charts.firstWhere((c) => c.id == 'c1');
    expect(hidden.homeHiddenAt, isNotNull);
    expect(hidden.caseShared, isTrue);

    // 멱등
    expect(await store.hideManagementCaseFromHome('c1'), isTrue);
    expect(store.charts.firstWhere((c) => c.id == 'c1').caseShared, isTrue);
  });
}
