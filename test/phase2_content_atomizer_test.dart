import 'package:flutter_test/flutter_test.dart';

import 'package:sori/content_atomizer/atomizer_consent_gate.dart';
import 'package:sori/content_atomizer/content_atomizer.dart';
import 'package:sori/content_atomizer/models/post_draft.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

CustomerChart _chart({
  bool signed = true,
  bool photo = true,
  bool marketing = true,
  bool offlineOnly = false,
  List<String> concernChips = const ['건조/장벽'],
  List<String> homeCare = const ['tag_moisture_pack'],
  String? before,
  String? after,
}) {
  return CustomerChart(
    id: 'chart-1',
    shopId: 'shop-1',
    customerId: 'cust-1',
    visitNumber: 2,
    careName: '수분 케어',
    treatmentSummary: '장벽 집중 케어',
    concernChips: concernChips,
    homeCarePrescriptions: homeCare,
    consentMandatory: signed,
    consentPhoto: photo,
    consentMarketing: marketing,
    consentOfflineOnly: offlineOnly,
    signatureUrl: signed ? 'https://example.com/sig.png' : null,
    beforeImageUrl: before ?? 'https://example.com/b.jpg',
    afterImageUrl: after ?? 'https://example.com/a.jpg',
  );
}

VisitSession _session() {
  return VisitSession(
    id: 'visit-1',
    shopId: 'shop-1',
    customerId: 'cust-1',
    customerName: '김고객',
    chartDraftId: 'chart-1',
    startedAt: DateTime.now(),
    phase: VisitPhase.publish,
  );
}

void main() {
  group('allowsPhotoMarketingContent', () {
    test('requires photo and marketing consent', () {
      expect(allowsPhotoMarketingContent(_chart()), isTrue);
      expect(allowsPhotoMarketingContent(_chart(photo: false)), isFalse);
      expect(
        allowsPhotoMarketingContent(_chart(marketing: false)),
        isFalse,
      );
    });
  });

  group('ContentAtomizer', () {
    test('always generates whisper and tip', () {
      final result = ContentAtomizer.atomize(
        session: _session(),
        chart: _chart(marketing: false, photo: false, signed: false),
        shopName: 'SORI샵',
      );

      final kinds = result.drafts.map((d) => d.kind).toSet();
      expect(kinds, contains(PostDraftKind.whisper));
      expect(kinds, contains(PostDraftKind.tipCard));
      expect(
        result.drafts.firstWhere((d) => d.kind == PostDraftKind.whisper).enabled,
        isTrue,
      );
      expect(
        result.drafts.firstWhere((d) => d.kind == PostDraftKind.tipCard).enabled,
        isTrue,
      );
    });

    test('drops clinical B/A and mentoring without photo consent', () {
      final result = ContentAtomizer.atomize(
        session: _session(),
        chart: _chart(marketing: false),
        shopName: 'SORI샵',
      );

      final clinical = result.drafts
          .firstWhere((d) => d.kind == PostDraftKind.clinicalBa);
      final mentoring = result.drafts
          .firstWhere((d) => d.kind == PostDraftKind.mentoringRequest);

      expect(clinical.enabled, isFalse);
      expect(mentoring.enabled, isFalse);
      expect(clinical.dropReason, isNotEmpty);
    });

    test('enables all four with full consent and photos', () {
      final result = ContentAtomizer.atomize(
        session: _session(),
        chart: _chart(),
        shopName: 'SORI샵',
      );

      expect(result.enabledCount, 4);
      expect(
        result.drafts.where((d) => d.enabled).length,
        4,
      );
    });

    test('whisper body is anonymized', () {
      final result = ContentAtomizer.atomize(
        session: _session(),
        chart: _chart(),
      );
      final whisper =
          result.drafts.firstWhere((d) => d.kind == PostDraftKind.whisper);
      expect(whisper.body, isNot(contains('김고객')));
      expect(whisper.body, contains('방문해 주신 고객님'));
    });
  });
}
