import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/chart_summary.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

CustomerChart _chart({
  required String id,
  required int visitNumber,
  String careName = '',
  String? before,
  String? after,
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop',
    customerId: 'c1',
    visitNumber: visitNumber,
    careName: careName,
    beforeImageUrl: before,
    afterImageUrl: after,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('latest change uses highest visitNumber and hides missing fields', () {
    expect(ChartSummary.changeLineFor(null), isNull);
    expect(ChartSummary.changeLineFor(_chart(id: 'empty', visitNumber: 1)), isNull);
    expect(
      ChartSummary.changeLineFor(
        _chart(id: 'named', visitNumber: 1, careName: '리프팅'),
      ),
      '리프팅',
    );
    expect(
      ChartSummary.changeLineFor(
        _chart(
          id: 'ba',
          visitNumber: 1,
          careName: '리프팅',
          before: 'https://example.com/b.jpg',
          after: 'https://example.com/a.jpg',
        ),
      ),
      '리프팅  ·  B/A 있음',
    );
    expect(
      ChartSummary.changeLineFor(
        _chart(
          id: 'after',
          visitNumber: 1,
          careName: '리프팅',
          before: 'https://example.com/b.jpg',
        ),
      ),
      '리프팅  ·  After 촬영 필요',
    );

    final summary = ChartSummary.from([
      _chart(id: 'old', visitNumber: 1, careName: '클렌징'),
      _chart(
        id: 'new',
        visitNumber: 3,
        careName: '리프팅',
        before: 'https://example.com/b.jpg',
        after: 'https://example.com/a.jpg',
      ),
      _chart(id: 'mid', visitNumber: 2, careName: '재생'),
    ]);
    expect(summary.latestChangeLine, '리프팅  ·  B/A 있음');
  });

  testWidgets('customer chart header shows latest change, not a new engine', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    store.charts.removeWhere((c) => c.customerId == customer.id);
    store.charts.add(
      CustomerChart(
        id: 'latest-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 2,
        careName: '리프팅',
        beforeImageUrl: 'https://example.com/b.jpg',
        afterImageUrl: 'https://example.com/a.jpg',
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CustomerChartPage(
            store: store,
            customerId: customer.id,
          ),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-chart-latest-change')), findsOneWidget);
    expect(find.textContaining('최근 시술'), findsOneWidget);
    expect(find.textContaining('리프팅'), findsWidgets);
    expect(find.textContaining('B/A 있음'), findsOneWidget);
  });
}
