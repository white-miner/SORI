import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/profile_showcase.dart';
import 'package:sori/models/customer_chart.dart';

CustomerChart _chart({
  required String id,
  bool caseShared = true,
  String? signatureUrl = 'sig',
  String? before = 'https://example.com/b.jpg',
  String? after = 'https://example.com/a.jpg',
  String careName = '케어',
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop',
    customerId: 'c1',
    visitNumber: 1,
    careName: careName,
    caseShared: caseShared,
    signatureUrl: signatureUrl,
    beforeImageUrl: before,
    afterImageUrl: after,
  );
}

void main() {
  group('displayFeaturedCases', () {
    test('preserves selection order and caps at 5', () {
      final charts = List.generate(
        6,
        (i) => _chart(id: 'c$i', careName: '케어$i'),
      );
      final shown = ProfileShowcase.displayFeaturedCases(
        featuredIds: ['c2', 'c0', 'c5', 'c1', 'c3', 'c4'],
        charts: charts,
      );
      expect(shown.map((c) => c.id).toList(), ['c2', 'c0', 'c5', 'c1', 'c3']);
    });

    test('ignores missing chart ids without crash', () {
      final shown = ProfileShowcase.displayFeaturedCases(
        featuredIds: ['gone', 'c1'],
        charts: [_chart(id: 'c1')],
      );
      expect(shown.map((c) => c.id).toList(), ['c1']);
    });

    test('hides caseShared=false but does not mutate community flag', () {
      final chart = _chart(id: 'c1', caseShared: false);
      final shown = ProfileShowcase.displayFeaturedCases(
        featuredIds: ['c1'],
        charts: [chart],
      );
      expect(shown, isEmpty);
      expect(chart.caseShared, isFalse);
    });

    test('hides consent=false without auto re-consent', () {
      final chart = _chart(id: 'c1', signatureUrl: null);
      final shown = ProfileShowcase.displayFeaturedCases(
        featuredIds: ['c1'],
        charts: [chart],
      );
      expect(shown, isEmpty);
      expect(chart.isConsentSigned, isFalse);
    });

    test('hides when images missing', () {
      final shown = ProfileShowcase.displayFeaturedCases(
        featuredIds: ['c1'],
        charts: [_chart(id: 'c1', before: null, after: null)],
      );
      expect(shown, isEmpty);
    });
  });

  group('featured list ops', () {
    test('tryAddFeatured rejects beyond max 5', () {
      final full = ['a', 'b', 'c', 'd', 'e'];
      expect(ProfileShowcase.tryAddFeatured(full, 'f'), isNull);
      expect(ProfileShowcase.tryAddFeatured(full, 'a'), ['a', 'b', 'c', 'd', 'e']);
    });

    test('removeFeatured does not imply unpublish', () {
      final next = ProfileShowcase.removeFeatured(['a', 'b'], 'a');
      expect(next, ['b']);
      final chart = _chart(id: 'a', caseShared: true);
      expect(chart.caseShared, isTrue);
    });

    test('normalizeFeaturedIds dedupes and caps', () {
      expect(
        ProfileShowcase.normalizeFeaturedIds(
          [' a ', 'b', 'a', 'c', 'd', 'e', 'f'],
        ),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });
  });

  group('resolveCta', () {
    test('valid booking url → 예약하기', () {
      final cta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: 'https://booking.naver.com/x',
        phone: '01012345678',
      );
      expect(cta.kind, ProfilePublicCtaKind.book);
      expect(cta.label, '예약하기');
      expect(cta.showsButton, isTrue);
      expect(cta.semanticsHint, isNotNull);
    });

    test('blank url + phone → 문의하기 tel', () {
      final cta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: '   ',
        phone: '010-1234-5678',
      );
      expect(cta.kind, ProfilePublicCtaKind.inquire);
      expect(cta.label, '문의하기');
      expect(cta.launchUri.toString(), 'tel:01012345678');
    });

    test('no url no phone → hide button + hint', () {
      final cta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: '',
        phone: null,
      );
      expect(cta.kind, ProfilePublicCtaKind.none);
      expect(cta.showsButton, isFalse);
      expect(cta.helperText, ProfileShowcase.preparingHint);
    });

    test('invalid url falls back to phone', () {
      final cta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: 'not-a-url',
        phone: '01099998888',
      );
      expect(cta.kind, ProfilePublicCtaKind.inquire);
    });

    test('url and phone → primary is book only', () {
      final cta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: 'https://naver.me/place',
        phone: '01011112222',
      );
      expect(cta.kind, ProfilePublicCtaKind.book);
      expect(cta.label, isNot(equals('문의하기')));
    });
  });
}
