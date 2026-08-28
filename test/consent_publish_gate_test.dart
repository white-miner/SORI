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
}
