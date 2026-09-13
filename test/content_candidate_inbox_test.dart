import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/content_candidate/content_candidate_inbox.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';

CustomerChart _chart({
  required String id,
  bool before = true,
  bool after = true,
  bool caseShared = false,
  bool signed = true,
  bool marketing = true,
  bool offlineOnly = false,
  String careName = '리프팅',
  String customerId = 'cust-secret',
  String treatmentSummary = '내부 시술 메모',
  String directorInsight = '원장 감사 메모',
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: customerId,
    visitNumber: 1,
    careName: careName,
    treatmentSummary: treatmentSummary,
    directorInsight: directorInsight,
    allergyNotes: '땅콩 알러지',
    beforeImageUrl: before ? 'https://example.com/b.jpg' : null,
    afterImageUrl: after ? 'https://example.com/a.jpg' : null,
    caseShared: caseShared,
    consentMarketing: marketing,
    consentOfflineOnly: offlineOnly,
    signatureUrl: signed ? 'https://example.com/sig.png' : null,
    createdAt: DateTime(2026, 9, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentCandidateInbox.instance.debugReset();
  });

  test('eligible requires comparable B/A, publish consent, unpublished', () {
    expect(ContentCandidateInbox.isEligible(_chart(id: 'ok')), isTrue);
    expect(
      ContentCandidateInbox.isEligible(_chart(id: 'no-after', after: false)),
      isFalse,
    );
    expect(
      ContentCandidateInbox.isEligible(_chart(id: 'shared', caseShared: true)),
      isFalse,
    );
    expect(
      ContentCandidateInbox.isEligible(_chart(id: 'unsigned', signed: false)),
      isFalse,
    );
    expect(
      ContentCandidateInbox.isEligible(
        _chart(id: 'no-mkt', marketing: false),
      ),
      isFalse,
    );
  });

  test('card uses public projection: careName + image + date, no notes', () {
    final src = _chart(id: 'c1');
    final card = ContentCandidateInbox.cardFor(
      src,
      ContentCandidateStatus.queued,
    );
    expect(card.chartId, 'c1');
    expect(card.imageUrl, 'https://example.com/a.jpg');
    expect(card.serviceSummary, '리프팅');
    expect(card.createdAt, DateTime(2026, 9, 1));
    expect(card.statusLabel, '후보');
    expect(card.serviceSummary.contains('내부'), isFalse);
    expect(card.serviceSummary.contains('감사'), isFalse);

    final pub = src.asPublicFeedProjection();
    expect(pub.customerId, isEmpty);
    expect(pub.treatmentSummary, isEmpty);
    expect(pub.directorInsight, isEmpty);
    expect(pub.allergyNotes, isEmpty);
  });

  test('enqueue is local only and skips ineligible / duplicates', () async {
    final inbox = ContentCandidateInbox.instance;
    expect(await inbox.enqueue(_chart(id: 'no-after', after: false)), isFalse);
    expect(await inbox.enqueue(_chart(id: 'ok')), isTrue);
    expect(inbox.contains('ok'), isTrue);
    expect(inbox.entries['ok'], ContentCandidateStatus.queued);
    expect(await inbox.enqueue(_chart(id: 'ok')), isFalse);

    expect(await inbox.markReady('ok'), isTrue);
    expect(inbox.entries['ok'], ContentCandidateStatus.ready);

    final hydrated = ContentCandidateInbox();
    await hydrated.hydrate();
    expect(hydrated.entries['ok'], ContentCandidateStatus.ready);
  });

  testWidgets('photo tab CTA only on eligible unpublished B/A', (tester) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.charts.addAll([
      _chart(
        id: 'eligible-1',
        customerId: customer.id,
        careName: '리프팅',
      ),
      _chart(
        id: 'no-consent-1',
        customerId: customer.id,
        signed: false,
        careName: '클렌징',
      ),
    ]);

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
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    await tester.tap(find.text('사진'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final cta = find.byKey(
      const Key('customer-chart-content-candidate-eligible-1'),
    );
    expect(cta, findsOneWidget);
    expect(find.text('콘텐츠 후보로 만들기'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-chart-content-candidate-no-consent-1')),
      findsNothing,
    );

    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(ContentCandidateInbox.instance.contains('eligible-1'), isTrue);
    expect(find.text('콘텐츠 후보함에 담았어요'), findsOneWidget);
    expect(cta, findsNothing);
    expect(
      find.byType(FloatingActionButton),
      findsOneWidget,
    );
  });
}
