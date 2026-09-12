import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/content_candidate/content_candidate_inbox.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/before_after_compare_page.dart';
import 'package:sori/widgets/ai_tool_sheet.dart';

CustomerChart _chart({
  required String id,
  required String customerId,
  required String shopId,
  bool after = true,
  bool signed = true,
  bool marketing = true,
  bool caseShared = false,
  String careName = '리프팅',
}) {
  return CustomerChart(
    id: id,
    shopId: shopId,
    customerId: customerId,
    visitNumber: 1,
    careName: careName,
    beforeImageUrl: 'https://example.com/b.jpg',
    afterImageUrl: after ? 'https://example.com/a.jpg' : null,
    consentMarketing: marketing,
    consentOfflineOnly: false,
    signatureUrl: signed ? 'https://example.com/sig.png' : null,
    caseShared: caseShared,
    createdAt: DateTime(2026, 9, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentCandidateInbox.instance.debugReset();
  });

  Future<void> pumpCompare(
    WidgetTester tester, {
    required SoriStore store,
    required String customerId,
    required String chartId,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BeforeAfterComparePage(
          customerName: '테스트고객',
          charts: store.chartsForCustomer(customerId),
          initialChartId: chartId,
          customerId: customerId,
          store: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('eligible same-visit B/A offers candidate CTA and stays put', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    store.charts.add(
      _chart(
        id: 'ba-eligible-1',
        customerId: customer.id,
        shopId: store.shop.id,
      ),
    );

    await pumpCompare(
      tester,
      store: store,
      customerId: customer.id,
      chartId: 'ba-eligible-1',
    );

    final cta = find.byKey(
      const Key('ba-compare-content-candidate-ba-eligible-1'),
    );
    expect(cta, findsOneWidget);
    expect(find.text('콘텐츠 후보로 만들기'), findsOneWidget);

    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(ContentCandidateInbox.instance.contains('ba-eligible-1'), isTrue);
    expect(find.text('콘텐츠 후보함에 담았어요'), findsOneWidget);
    expect(find.byType(BeforeAfterComparePage), findsOneWidget);
    expect(cta, findsNothing);
    expect(find.byType(AiToolSheet), findsNothing);
  });

  testWidgets('hides CTA when consent missing, already queued, or mixed visit', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    store.charts.addAll([
      _chart(
        id: 'ba-unsigned-1',
        customerId: customer.id,
        shopId: store.shop.id,
        signed: false,
      ),
      _chart(
        id: 'ba-queued-1',
        customerId: customer.id,
        shopId: store.shop.id,
        careName: '클렌징',
      ),
    ]);
    expect(
      await ContentCandidateInbox.instance.enqueue(
        store.findChartById('ba-queued-1')!,
      ),
      isTrue,
    );

    await pumpCompare(
      tester,
      store: store,
      customerId: customer.id,
      chartId: 'ba-unsigned-1',
    );
    expect(
      find.byKey(const Key('ba-compare-content-candidate-ba-unsigned-1')),
      findsNothing,
    );
    expect(find.text('콘텐츠 후보로 만들기'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: BeforeAfterComparePage(
          customerName: '테스트고객',
          charts: store.chartsForCustomer(customer.id),
          initialChartId: 'ba-queued-1',
          customerId: customer.id,
          store: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const Key('ba-compare-content-candidate-ba-queued-1')),
      findsNothing,
    );
  });
}
