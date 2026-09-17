import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/customer_consent_archive.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

CustomerChart _signed({
  required String id,
  required String customerId,
  required DateTime createdAt,
  int visitNumber = 1,
  String careName = '시술',
  DateTime? homeHiddenAt,
  String? pdfUrl = 'https://example.com/consent.pdf',
  String? signatureUrl = 'https://example.com/sig.png',
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: customerId,
    visitNumber: visitNumber,
    careName: careName,
    createdAt: createdAt,
    signatureUrl: signatureUrl,
    consentPdfUrl: pdfUrl,
    homeHiddenAt: homeHiddenAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('consent history ignores visit_number and empty customer_id', () {
    const customerId = 'cust-a';
    final now = DateTime(2026, 9, 14);
    final charts = [
      _signed(
        id: 'older-high-v',
        customerId: customerId,
        createdAt: DateTime(2026, 1, 1),
        visitNumber: 99,
      ),
      _signed(
        id: 'newer-low-v',
        customerId: customerId,
        createdAt: DateTime(2026, 8, 1),
        visitNumber: 1,
      ),
      _signed(
        id: 'orphan',
        customerId: '',
        createdAt: DateTime(2026, 9, 1),
        visitNumber: 1,
      ),
      CustomerChart(
        id: 'unsigned',
        shopId: 'shop-1',
        customerId: customerId,
        visitNumber: 2,
        createdAt: DateTime(2026, 9, 1),
      ),
      _signed(
        id: 'hidden',
        customerId: customerId,
        createdAt: DateTime(2026, 7, 1),
        visitNumber: 8,
        homeHiddenAt: DateTime(2026, 9, 11),
      ),
    ];

    final snap = CustomerConsentArchive.snapshot(
      customerId: customerId,
      charts: charts,
      now: now,
    );

    expect(snap.history.map((c) => c.id), ['newer-low-v', 'hidden', 'older-high-v']);
    expect(snap.historyCount, 3);
    expect(snap.latest?.id, 'newer-low-v');
    expect(snap.hasValid, isTrue);
    expect(snap.statusLabel, '유효');
    expect(snap.history.any((c) => c.id == 'orphan'), isFalse);
    expect(snap.history.any((c) => c.id == 'unsigned'), isFalse);
    expect(snap.history.any((c) => c.id == 'hidden'), isTrue);
  });

  test('expired when created_at is older than 365 days', () {
    const customerId = 'cust-a';
    final now = DateTime(2026, 9, 14);
    final snap = CustomerConsentArchive.snapshot(
      customerId: customerId,
      charts: [
        _signed(
          id: 'old',
          customerId: customerId,
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
      now: now,
    );
    expect(snap.hasAny, isTrue);
    expect(snap.hasValid, isFalse);
    expect(snap.statusLabel, '만료 또는 재동의 필요');
  });

  test('tie-breaker uses chart id desc', () {
    const customerId = 'cust-a';
    final at = DateTime(2026, 8, 13, 1);
    final snap = CustomerConsentArchive.snapshot(
      customerId: customerId,
      charts: [
        _signed(id: 'aaa', customerId: customerId, createdAt: at),
        _signed(id: 'zzz', customerId: customerId, createdAt: at),
      ],
    );
    expect(snap.history.map((c) => c.id), ['zzz', 'aaa']);
  });

  test('stored pdf preferred over generator when url exists', () {
    expect(
      CustomerConsentArchive.hasStoredPdf(
        _signed(
          id: 'p',
          customerId: 'c',
          createdAt: DateTime(2026, 1, 1),
        ),
      ),
      isTrue,
    );
    expect(
      CustomerConsentArchive.hasStoredPdf(
        CustomerChart(
          id: 's',
          shopId: 'shop-1',
          customerId: 'c',
          visitNumber: 1,
          signatureUrl: 'https://example.com/sig.png',
        ),
      ),
      isFalse,
    );
  });

  testWidgets('file cabinet shows 12 signed consents including home_hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final customer = store.customers.first;
    final charts = <CustomerChart>[
      for (var i = 0; i < 12; i++)
        _signed(
          id: 'signed-$i',
          customerId: customer.id,
          createdAt: DateTime(2026, 8, 1).add(Duration(days: i)),
          visitNumber: i == 11 ? 8 : 1,
          homeHiddenAt: i >= 10 ? DateTime(2026, 9, 11) : null,
        ),
      for (var i = 0; i < 6; i++)
        CustomerChart(
          id: 'orphan-$i',
          shopId: store.shop.id,
          customerId: '',
          visitNumber: 1,
          createdAt: DateTime(2026, 8, 12),
          signatureUrl: 'https://example.com/orphan.png',
        ),
    ];
    store.charts
      ..clear()
      ..addAll(charts);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => CustomerChartPage(
            store: store,
            customerId: customer.id,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('customer-chart-consent-entry')), findsOneWidget);
    expect(find.text('전자 동의서'), findsOneWidget);
    expect(find.textContaining('동의 이력 12건'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer-chart-consent-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('customer-consent-history-summary')), findsOneWidget);
    expect(find.textContaining('동의 이력 12건'), findsWidgets);
    expect(find.byKey(const Key('customer-consent-history-item-signed-11')), findsOneWidget);
    expect(find.byKey(const Key('customer-consent-history-item-signed-10')), findsOneWidget);
    expect(find.text('서명된 동의서가 없습니다.'), findsNothing);
    expect(store.charts.where((c) => c.customerId.isEmpty).length, 6);
  });

  testWidgets('file cabinet empty consent does not create charts', (tester) async {
    final store = SoriStore();
    final customer = store.customers.first;
    store.charts.removeWhere((c) => c.customerId == customer.id);
    final chartCount = store.charts.length;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => CustomerChartPage(
            store: store,
            customerId: customer.id,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('동의 없음'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer-chart-consent-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('서명된 동의서가 없습니다.'), findsOneWidget);
    expect(store.charts.length, chartCount);
    expect(
      store.charts.where((c) => c.customerId == customer.id && c.isConsentSigned),
      isEmpty,
    );
  });
}
