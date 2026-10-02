// S3-0 특성 테스트: CustomerChart 가 사진·서명·동의서 URL을 읽고 쓰는 방식.
//
// 지금은 fromMap 에서 before/after 값을 StorageImageUrl.resolve 로 "공개 URL"로 바꾼다.
// 그래서 DB에 객체 경로가 있어도 다음 저장(toMap) 때 공개 URL로 다시 쓰인다
// (환경에 SUPABASE_URL 이 없으면 경로는 null 이 된다).
// 서명(signature_url)과 동의서(consent_pdf_url)는 바꾸지 않고 그대로 둔다.
// 보안 S3 PR 3-13에서 "원래 값 보관"으로 바뀌면 경로 관련 기대값을 그 PR에서 고친다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/config/env.dart';
import 'package:sori/models/customer_chart.dart';

const _publicBefore =
    'https://tieojdbzmqcmlwyqltrk.supabase.co/storage/v1/object/public/chart_photos/shop-a/cu-1/abc_1_before.webp';
const _publicAfter =
    'https://tieojdbzmqcmlwyqltrk.supabase.co/storage/v1/object/public/chart_photos/shop-a/cu-1/abc_2_after.webp';
const _objectPath = 'shop-a/cu-1/abc_3_before.webp';
const _signature = 'data:image/png;base64,iVBORw0KGgo=';
const _consentPdf =
    'https://tieojdbzmqcmlwyqltrk.supabase.co/storage/v1/object/public/consent_pdfs/shop-a/cu-1/consent.pdf';

Map<String, dynamic> _row({
  Object? before,
  Object? after,
  Object? signature,
  Object? consent,
}) => {
  'id': 'chart-url-1',
  'shop_id': 'shop-a',
  'customer_id': 'cu-1',
  'visit_number': 2,
  'before_image_url': before,
  'after_image_url': after,
  'signature_url': signature,
  'consent_pdf_url': consent,
};

/// 지금 resolve 규칙: 기본 버킷 chart_photos 의 공개 URL. 설정이 없으면 null.
String? _expectedResolvedPath(String path) {
  final base = Env.supabaseUrl;
  if (base.isEmpty) return null;
  return '$base/storage/v1/object/public/chart_photos/$path';
}

void main() {
  group('S3-0 CustomerChart URL 특성', () {
    test('공개 URL은 읽을 때도 쓸 때도 그대로다', () {
      final chart = CustomerChart.fromMap(
        _row(before: _publicBefore, after: _publicAfter),
      );
      expect(chart.beforeImageUrl, _publicBefore);
      expect(chart.afterImageUrl, _publicAfter);

      final map = chart.toMap();
      expect(map['before_image_url'], _publicBefore);
      expect(map['after_image_url'], _publicAfter);
      expect(
        CustomerChart.fromMap(Map<String, dynamic>.from(map)).beforeImageUrl,
        _publicBefore,
      );
    });

    test('객체 경로는 fromMap 에서 공개 URL(또는 설정이 없으면 null)로 바뀌어 다시 저장된다', () {
      final chart = CustomerChart.fromMap(_row(before: _objectPath));
      final expected = _expectedResolvedPath(_objectPath);

      expect(chart.beforeImageUrl, expected);
      expect(chart.toMap()['before_image_url'], expected);
      // 원래 경로는 어디에도 남지 않는다.
      expect(chart.toMap()['before_image_url'], isNot(_objectPath));
    });

    test('data URI 는 그대로 둔다', () {
      const dataUri = 'data:image/webp;base64,UklGRg==';
      final chart = CustomerChart.fromMap(_row(before: dataUri));
      expect(chart.beforeImageUrl, dataUri);
      expect(chart.toMap()['before_image_url'], dataUri);
    });

    test('빈 값·공백은 null 로 읽고 null 로 쓴다', () {
      final chart = CustomerChart.fromMap(_row(before: '', after: '   '));
      expect(chart.beforeImageUrl, isNull);
      expect(chart.afterImageUrl, isNull);
      final map = chart.toMap();
      expect(map['before_image_url'], isNull);
      expect(map['after_image_url'], isNull);
    });

    test('서명과 동의서 URL은 변환 없이 그대로 읽고 쓴다', () {
      final chart = CustomerChart.fromMap(
        _row(signature: _signature, consent: _consentPdf),
      );
      expect(chart.signatureUrl, _signature);
      expect(chart.consentPdfUrl, _consentPdf);
      final map = chart.toMap();
      expect(map['signature_url'], _signature);
      expect(map['consent_pdf_url'], _consentPdf);
    });

    test('서명·동의서에 객체 경로가 와도 공개 URL로 바꾸지 않는다', () {
      final chart = CustomerChart.fromMap(
        _row(
          signature: 'shop-a/cu-1/sig.png',
          consent: 'shop-a/cu-1/consent.pdf',
        ),
      );
      expect(chart.signatureUrl, 'shop-a/cu-1/sig.png');
      expect(chart.consentPdfUrl, 'shop-a/cu-1/consent.pdf');
    });

    test('photo_meta 는 사진이 있는 쪽만 적고 URL 자체는 넣지 않는다', () {
      final chart = CustomerChart.fromMap(_row(before: _publicBefore));
      final meta = chart.toMap()['photo_meta'] as Map;
      expect(meta.keys, ['before']);
      expect((meta['before'] as Map)['chart_id'], 'chart-url-1');
      expect((meta['before'] as Map).values, isNot(contains(_publicBefore)));
    });
  });
}
