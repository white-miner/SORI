import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/customer_chart.dart';
import 'package:sori/utils/consent_publish_gate.dart';

CustomerChart _chart({
  bool signed = true,
  bool marketing = true,
  bool offlineOnly = false,
}) {
  return CustomerChart(
    id: 'c1',
    shopId: 's1',
    customerId: 'u1',
    visitNumber: 1,
    consentMandatory: signed,
    consentPhoto: signed,
    consentMarketing: marketing,
    consentOfflineOnly: offlineOnly,
    signatureUrl: signed ? 'https://example.com/sig.png' : null,
  );
}

void main() {
  group('canPublishBa', () {
    test('ok when signed + marketing', () {
      expect(canPublishBa(_chart()), ConsentPublishGate.ok);
    });

    test('blocks unsigned', () {
      expect(
        canPublishBa(_chart(signed: false, marketing: false)),
        ConsentPublishGate.notSigned,
      );
    });

    test('blocks offlineOnly without marketing', () {
      expect(
        canPublishBa(_chart(marketing: false, offlineOnly: true)),
        ConsentPublishGate.offlineOnly,
      );
    });

    test('blocks missing marketing even if not offlineOnly', () {
      expect(
        canPublishBa(_chart(marketing: false, offlineOnly: false)),
        ConsentPublishGate.missingMarketing,
      );
    });

    test('allows offlineOnly when marketing also true', () {
      expect(
        canPublishBa(_chart(marketing: true, offlineOnly: true)),
        ConsentPublishGate.ok,
      );
    });
  });

  group('gate judgment + alertMessage frozen', () {
    test('allowsPublish only for ok', () {
      expect(ConsentPublishGate.ok.allowsPublish, isTrue);
      expect(ConsentPublishGate.notSigned.allowsPublish, isFalse);
      expect(ConsentPublishGate.offlineOnly.allowsPublish, isFalse);
      expect(ConsentPublishGate.missingMarketing.allowsPublish, isFalse);
    });

    test('alertMessage contract unchanged', () {
      expect(ConsentPublishGate.ok.alertMessage, '');
      expect(
        ConsentPublishGate.notSigned.alertMessage,
        '고객의 정보 활용 동의서 서명이 필요합니다.',
      );
      expect(
        ConsentPublishGate.offlineOnly.alertMessage,
        '고객의 SNS 공유 동의가 필요합니다.',
      );
      expect(
        ConsentPublishGate.missingMarketing.alertMessage,
        '고객의 SNS 공유 동의가 필요합니다.',
      );
    });
  });

  group('badgeLabel Korean UI only', () {
    test('Korean badge labels for each gate', () {
      expect(ConsentPublishGate.ok.badgeLabel, 'SNS 공개 가능');
      expect(ConsentPublishGate.notSigned.badgeLabel, '동의 대기');
      expect(ConsentPublishGate.offlineOnly.badgeLabel, '샵 내부 전용');
      expect(ConsentPublishGate.missingMarketing.badgeLabel, 'SNS 동의 필요');
    });
  });
}
