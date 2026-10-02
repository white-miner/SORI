// S3-0 특성 테스트: StorageImageUrl.resolve 와 ChartPhotoStorage 경로 파싱.
//
// 지금 resolve 는 동기 함수로, 객체 경로를 "공개 URL"로 바꾼다 (Supabase 클라이언트가 없고
// SUPABASE_URL 도 없으면 null). 보안 S3 PR 3-1/3-2에서 비동기 MediaUrlResolver 를
// 추가해도 이 함수의 기존 동작은 바꾸지 않는다 (공개 버킷 shop_profiles 표시에 계속 쓴다).
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/config/env.dart';
import 'package:sori/services/chart_photo_storage.dart';
import 'package:sori/utils/storage_image_url.dart';

String? _publicUrl(String bucket, String path) {
  final base = Env.supabaseUrl;
  if (base.isEmpty) return null;
  return '$base/storage/v1/object/public/$bucket/$path';
}

String? _withBase(String storagePath) {
  final base = Env.supabaseUrl;
  if (base.isEmpty) return null;
  return '$base$storagePath';
}

void main() {
  group('S3-0 StorageImageUrl.resolve 특성', () {
    test('null·빈 문자열·공백은 null', () {
      expect(StorageImageUrl.resolve(null), isNull);
      expect(StorageImageUrl.resolve(''), isNull);
      expect(StorageImageUrl.resolve('   '), isNull);
    });

    test('data URI 는 그대로', () {
      const v = 'data:image/png;base64,AAAA';
      expect(StorageImageUrl.resolve(v), v);
    });

    test('http(s) URL은 앞뒤 공백만 지우고 그대로 (버킷이 달라도 바꾸지 않음)', () {
      const pub =
          'https://x.supabase.co/storage/v1/object/public/chart_photos/s/c/a.webp';
      expect(StorageImageUrl.resolve('  $pub  '), pub);
      expect(
        StorageImageUrl.resolve('http://example.com/a.png'),
        'http://example.com/a.png',
      );
      expect(StorageImageUrl.resolve(pub, bucket: 'shop_profiles'), pub);
    });

    test('/storage/v1/... 상대 경로는 SUPABASE_URL 을 앞에 붙인다', () {
      const p = '/storage/v1/object/public/chart_photos/s/c/a.webp';
      expect(StorageImageUrl.resolve(p), _withBase(p));
      expect(
        StorageImageUrl.resolve(
          'storage/v1/object/public/chart_photos/s/c/a.webp',
        ),
        _withBase(p),
      );
    });

    test('객체 경로는 기본 버킷 chart_photos 의 공개 URL로, 앞 슬래시는 지운다', () {
      expect(
        StorageImageUrl.resolve('shop-a/cu-1/x.webp'),
        _publicUrl('chart_photos', 'shop-a/cu-1/x.webp'),
      );
      expect(
        StorageImageUrl.resolve('//shop-a/cu-1/x.webp'),
        _publicUrl('chart_photos', 'shop-a/cu-1/x.webp'),
      );
    });

    test('bucket 인자를 주면 그 버킷의 공개 URL로 만든다', () {
      expect(
        StorageImageUrl.resolve(
          'shop-a/gallery/g.webp',
          bucket: 'shop_profiles',
        ),
        _publicUrl('shop_profiles', 'shop-a/gallery/g.webp'),
      );
    });

    test('isNetworkUrl 은 http/https 만 true', () {
      expect(StorageImageUrl.isNetworkUrl('https://a/b'), isTrue);
      expect(StorageImageUrl.isNetworkUrl(' http://a/b '), isTrue);
      expect(StorageImageUrl.isNetworkUrl('shop/a.webp'), isFalse);
      expect(StorageImageUrl.isNetworkUrl('data:image/png;base64,AA'), isFalse);
      expect(StorageImageUrl.isNetworkUrl(null), isFalse);
    });
  });

  group('S3-0 ChartPhotoStorage.objectPathFromPublicUrl 특성', () {
    test('공개 URL에서 버킷 뒤 경로만 꺼내고 쿼리·해시는 버린다', () {
      expect(
        ChartPhotoStorage.objectPathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/chart_photos/shop-a/cu-1/a.webp?t=1#h',
        ),
        'shop-a/cu-1/a.webp',
      );
    });

    test('퍼센트 인코딩은 풀어서 돌려준다', () {
      expect(
        ChartPhotoStorage.objectPathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/chart_photos/shop-a/%EA%B3%A0%EA%B0%9D/a.webp',
        ),
        'shop-a/고객/a.webp',
      );
    });

    test('객체 경로는 그대로(앞 슬래시 제거), 다른 버킷 URL·data URI·빈 값은 null', () {
      expect(
        ChartPhotoStorage.objectPathFromPublicUrl('/shop-a/cu-1/a.webp'),
        'shop-a/cu-1/a.webp',
      );
      expect(
        ChartPhotoStorage.objectPathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/consent_pdfs/shop-a/c.pdf',
        ),
        isNull,
      );
      expect(
        ChartPhotoStorage.objectPathFromPublicUrl('data:image/png;base64,AA'),
        isNull,
      );
      expect(ChartPhotoStorage.objectPathFromPublicUrl('   '), isNull);
    });
  });
}
