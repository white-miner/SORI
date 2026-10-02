import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/media_sign_client.dart';
import 'package:sori/services/media_url_resolver.dart';
import 'package:sori/utils/storage_image_url.dart';

const _project = 'https://abcproj.supabase.co';
const _shopA = '11111111-1111-4111-8111-111111111111';
const _shopB = '22222222-2222-4222-8222-222222222222';

MediaRef _parse(String? raw, {String defaultBucket = 'chart_photos'}) =>
    MediaRef.parse(raw, defaultBucket: defaultBucket, supabaseUrl: _project);

String _publicUrl(String bucket, String path) =>
    '$_project/storage/v1/object/public/$bucket/$path';

/// Fake `media-sign`: records each body and answers via [reply].
class _FakeEdge {
  _FakeEdge({
    MediaSignTransportResponse Function(Map<String, Object?> body)? reply,
  }) : reply = reply ?? _signAll;

  MediaSignTransportResponse Function(Map<String, Object?> body) reply;
  final calls = <Map<String, Object?>>[];

  int get callCount => calls.length;

  List<Map<String, Object?>> refsOf(int call) =>
      (calls[call]['refs']! as List).cast<Map<String, Object?>>();

  Future<MediaSignTransportResponse> call(Map<String, Object?> body) async {
    calls.add(body);
    await Future<void>.delayed(Duration.zero);
    return reply(body);
  }

  static MediaSignTransportResponse _signAll(Map<String, Object?> body) {
    final refs = (body['refs']! as List).cast<Map<String, Object?>>();
    return (
      status: 200,
      data: {
        'ok': true,
        'mode': 'refs',
        'expires_in': body['expires_in'],
        'items': [
          for (var i = 0; i < refs.length; i++)
            {
              'index': i,
              'bucket': refs[i]['bucket'],
              'path': refs[i]['path'],
              'signed_url':
                  'https://signed.test/${refs[i]['bucket']}/${refs[i]['path']}?token=t',
            },
        ],
      },
    );
  }
}

String _signed(String bucket, String path) =>
    'https://signed.test/$bucket/$path?token=t';

void main() {
  group('MediaRef.parse', () {
    test('null / blank → empty', () {
      expect(_parse(null).kind, MediaRefKind.empty);
      expect(_parse('').kind, MediaRefKind.empty);
      expect(_parse('   ').kind, MediaRefKind.empty);
    });

    test('data URI → dataUri (kept as is)', () {
      final ref = _parse(' data:image/png;base64,AAAA ');
      expect(ref.kind, MediaRefKind.dataUri);
      expect(ref.raw, 'data:image/png;base64,AAAA');
      expect(ref.isSignable, isFalse);
    });

    test('project public URL → bucket + decoded path, query/hash dropped', () {
      final ref = _parse(
        '$_project/storage/v1/object/public/chart_photos/$_shopA/c%201/%EC%82%AC%EC%A7%84.webp?v=2#x',
      );
      expect(ref.kind, MediaRefKind.storage);
      expect(ref.bucket, 'chart_photos');
      expect(ref.path, '$_shopA/c 1/사진.webp');
      expect(ref.shopId, _shopA);
      expect(ref.isSignable, isTrue);
    });

    test('sign / authenticated / render URLs and host case are accepted', () {
      for (final prefix in [
        'object/sign',
        'object/authenticated',
        'render/image/public',
      ]) {
        final ref = _parse(
          'https://ABCPROJ.supabase.co/storage/v1/$prefix/consent_pdfs/$_shopA/x.pdf?token=1',
        );
        expect(ref.kind, MediaRefKind.storage, reason: prefix);
        expect(ref.bucket, 'consent_pdfs', reason: prefix);
        expect(ref.path, '$_shopA/x.pdf', reason: prefix);
      }
    });

    test(
      'other hosts, missing SUPABASE_URL, dot segments, unknown buckets → external',
      () {
        expect(
          _parse(
            'https://other.supabase.co/storage/v1/object/public/chart_photos/$_shopA/a.webp',
          ).kind,
          MediaRefKind.external,
        );
        expect(
          MediaRef.parse(
            _publicUrl('chart_photos', '$_shopA/a.webp'),
            supabaseUrl: '',
          ).kind,
          MediaRefKind.external,
        );
        expect(
          _parse(
            '$_project/storage/v1/object/public/chart_photos/$_shopA/../b.webp',
          ).kind,
          MediaRefKind.external,
        );
        expect(
          _parse(
            '$_project/storage/v1/object/public/chart_photos/$_shopA/%2e%2e/b.webp',
          ).kind,
          MediaRefKind.external,
        );
        expect(
          _parse(_publicUrl('secret_bucket', '$_shopA/a.webp')).kind,
          MediaRefKind.external,
        );
        expect(_parse('https://picsum.photos/200').kind, MediaRefKind.external);
        expect(
          _parse('ftp://abcproj.supabase.co/x').kind,
          MediaRefKind.external,
        );
      },
    );

    test('relative /storage/v1/... path → storage', () {
      final ref = _parse(
        '/storage/v1/object/public/chart-signatures/$_shopA/s.png',
      );
      expect(ref.kind, MediaRefKind.storage);
      expect(ref.bucket, 'chart-signatures');
      expect(ref.path, '$_shopA/s.png');
      expect(
        _parse('storage/v1/object/public/chart_photos/$_shopA/a.webp').bucket,
        'chart_photos',
      );
    });

    test('object path → column bucket, leading slash and query removed', () {
      final ref = _parse('/$_shopA/cust/a.webp?x=1');
      expect(ref.kind, MediaRefKind.storage);
      expect(ref.bucket, 'chart_photos');
      expect(ref.path, '$_shopA/cust/a.webp');

      final sig = _parse(
        '$_shopA/cust/s.png',
        defaultBucket: 'chart-signatures',
      );
      expect(sig.bucket, 'chart-signatures');
      expect(sig.defaultBucket, 'chart-signatures');
    });

    test('unsafe object paths or unknown column bucket → unknown', () {
      for (final raw in [
        '$_shopA/../x.webp',
        '$_shopA//x.webp',
        r'a\b.webp',
        '$_shopA/./x',
      ]) {
        expect(_parse(raw).kind, MediaRefKind.unknown, reason: raw);
      }
      expect(
        _parse('$_shopA/a.webp', defaultBucket: 'nope').kind,
        MediaRefKind.unknown,
      );
    });

    test('signable only for private buckets with a shop UUID folder', () {
      expect(_parse('$_shopA/c/a.webp').isSignable, isTrue);
      expect(_parse('${_shopA.toUpperCase()}/c/a.webp').shopId, _shopA);
      expect(_parse('unknown-shop/c/a.webp').isSignable, isFalse);
      expect(_parse('unknown-shop/c/a.webp').shopId, isNull);
      expect(
        _parse(_publicUrl('shop_profiles', '$_shopA/p.webp')).isSignable,
        isFalse,
      );
      expect(
        _parse(_publicUrl('chart-photos', '$_shopA/old.webp')).isSignable,
        isFalse,
      );
      expect(_parse('https://picsum.photos/200').isSignable, isFalse);
    });

    test('URL and object path forms share one cache key', () {
      final a = _parse(_publicUrl('chart_photos', '$_shopA/c/a.webp'));
      final b = _parse('$_shopA/c/a.webp');
      expect(a.cacheKey, 'chart_photos/$_shopA/c/a.webp');
      expect(a.cacheKey, b.cacheKey);
      expect(
        _parse('https://picsum.photos/200').cacheKey,
        'https://picsum.photos/200',
      );
    });
  });

  group('MediaSignClient', () {
    test('sends refs + expires_in and maps items by index', () async {
      final edge = _FakeEdge(
        reply: (body) => (
          status: 200,
          data: {
            'ok': true,
            'expires_in': 3600,
            'expires_at': '2026-10-03T01:00:00.000Z',
            'items': [
              {'index': 1, 'signed_url': 'https://s.test/b'},
              {'index': 0, 'signed_url': null, 'error': 'not_found'},
              {'index': 2, 'signed_url': 'javascript:alert(1)'},
              {'index': 9, 'signed_url': 'https://s.test/out-of-range'},
            ],
          },
        ),
      );
      final client = MediaSignClient(transport: edge.call);
      final result = await client.signRefs([
        (bucket: 'chart_photos', path: '$_shopA/a.webp'),
        (bucket: 'chart_photos', path: '$_shopA/b.webp'),
        (bucket: 'consent_pdfs', path: '$_shopA/c.pdf'),
      ], expiresInSeconds: 99999);

      expect(edge.callCount, 1);
      expect(edge.calls.single['expires_in'], 3600);
      expect(edge.refsOf(0), [
        {'bucket': 'chart_photos', 'path': '$_shopA/a.webp'},
        {'bucket': 'chart_photos', 'path': '$_shopA/b.webp'},
        {'bucket': 'consent_pdfs', 'path': '$_shopA/c.pdf'},
      ]);
      expect(result.signedUrls, [null, 'https://s.test/b', null]);
      expect(result.expiresIn, const Duration(hours: 1));
      expect(result.expiresAt, DateTime.utc(2026, 10, 3, 1));
    });

    test(
      'non-2xx or ok:false → MediaSignException with server error code',
      () async {
        final unauth = MediaSignClient(
          transport: _FakeEdge(
            reply: (_) =>
                (status: 401, data: {'ok': false, 'error': 'login_required'}),
          ).call,
        );
        await expectLater(
          unauth.signRefs([(bucket: 'chart_photos', path: '$_shopA/a.webp')]),
          throwsA(
            isA<MediaSignException>()
                .having((e) => e.status, 'status', 401)
                .having((e) => e.error, 'error', 'login_required')
                .having((e) => e.isAuthError, 'isAuthError', isTrue),
          ),
        );

        final weird = MediaSignClient(
          transport: _FakeEdge(reply: (_) => (status: 200, data: 'oops')).call,
        );
        await expectLater(
          weird.signRefs([(bucket: 'chart_photos', path: '$_shopA/a.webp')]),
          throwsA(
            isA<MediaSignException>().having(
              (e) => e.error,
              'error',
              'unexpected_response',
            ),
          ),
        );
      },
    );

    test('empty list skips the call; more than 50 refs is rejected', () async {
      final edge = _FakeEdge();
      final client = MediaSignClient(transport: edge.call);
      expect((await client.signRefs(const [])).signedUrls, isEmpty);
      expect(edge.callCount, 0);
      expect(
        () => client.signRefs([
          for (var i = 0; i < 51; i++)
            (bucket: 'chart_photos', path: '$_shopA/$i.webp'),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('MediaUrlResolver', () {
    late _FakeEdge edge;
    late DateTime now;
    late bool canSign;

    MediaUrlResolver build({
      Duration batchWindow = const Duration(milliseconds: 1),
    }) => MediaUrlResolver(
      client: MediaSignClient(transport: edge.call),
      canSign: () => canSign,
      legacyUrl: (r) => 'legacy:${r.raw}',
      now: () => now,
      batchWindow: batchWindow,
    );

    setUp(() {
      edge = _FakeEdge();
      now = DateTime.utc(2026, 10, 3);
      canSign = true;
    });

    test(
      'empty, data URI, external URL pass through without media-sign',
      () async {
        final r = build();
        expect(await r.resolve(_parse(null)), isNull);
        expect(
          await r.resolve(_parse('data:image/png;base64,AA')),
          'data:image/png;base64,AA',
        );
        expect(
          await r.resolve(_parse('https://picsum.photos/200')),
          'https://picsum.photos/200',
        );
        expect(edge.callCount, 0);
      },
    );

    test(
      'public bucket, unknown-shop path, unknown form → old public URL, no call',
      () async {
        final r = build();
        final profile = _publicUrl('shop_profiles', '$_shopA/p.webp');
        expect(await r.resolve(_parse(profile)), 'legacy:$profile');
        expect(
          await r.resolve(_parse('unknown-shop/c/a.webp')),
          'legacy:unknown-shop/c/a.webp',
        );
        expect(
          await r.resolve(_parse('$_shopA/../a.webp')),
          'legacy:$_shopA/../a.webp',
        );
        expect(edge.callCount, 0);
      },
    );

    test(
      'customer / anon mode (canSign false) → old public URL, no call',
      () async {
        canSign = false;
        final r = build();
        final raw = _publicUrl('chart_photos', '$_shopA/c/a.webp');
        expect(await r.resolve(_parse(raw)), 'legacy:$raw');
        expect(edge.callCount, 0);
      },
    );

    test(
      'requests in one window are batched; same object is asked once',
      () async {
        final r = build(batchWindow: const Duration(milliseconds: 20));
        final results = await Future.wait([
          r.resolve(_parse('$_shopA/c/a.webp')),
          r.resolve(_parse(_publicUrl('chart_photos', '$_shopA/c/a.webp'))),
          r.resolve(_parse('$_shopA/c/b.webp')),
          r.resolve(
            _parse('$_shopA/c/s.png', defaultBucket: 'chart-signatures'),
          ),
        ]);
        expect(edge.callCount, 1);
        expect(edge.refsOf(0), hasLength(3));
        expect(results, [
          _signed('chart_photos', '$_shopA/c/a.webp'),
          _signed('chart_photos', '$_shopA/c/a.webp'),
          _signed('chart_photos', '$_shopA/c/b.webp'),
          _signed('chart-signatures', '$_shopA/c/s.png'),
        ]);
      },
    );

    test('one request per shop, at most 50 refs each', () async {
      final r = build();
      await Future.wait([
        for (var i = 0; i < 120; i++) r.resolve(_parse('$_shopA/c/$i.webp')),
        r.resolve(_parse('$_shopB/c/x.webp')),
      ]);
      final sizes = [
        for (var i = 0; i < edge.callCount; i++) edge.refsOf(i).length,
      ]..sort();
      expect(sizes, [1, 20, 50, 50]);
      for (var i = 0; i < edge.callCount; i++) {
        final shops = edge
            .refsOf(i)
            .map((m) => (m['path']! as String).split('/').first)
            .toSet();
        expect(shops, hasLength(1));
      }
    });

    test('signed URLs are cached for 50 minutes (peek + resolve)', () async {
      final r = build();
      final ref = _parse('$_shopA/c/a.webp');
      expect(r.peek(ref), isNull);
      expect(await r.resolve(ref), _signed('chart_photos', '$_shopA/c/a.webp'));
      expect(r.peek(ref), _signed('chart_photos', '$_shopA/c/a.webp'));

      now = now.add(const Duration(minutes: 49));
      expect(await r.resolve(ref), _signed('chart_photos', '$_shopA/c/a.webp'));
      expect(edge.callCount, 1);

      now = now.add(const Duration(minutes: 2));
      expect(r.peek(ref), isNull);
      await r.resolve(ref);
      expect(edge.callCount, 2);
    });

    test('cache never outlives server expires_at (minus 1 minute)', () async {
      edge.reply = (body) {
        final reply = _FakeEdge._signAll(body);
        final data = Map<String, Object?>.from(reply.data! as Map)
          ..['expires_at'] = now
              .add(const Duration(minutes: 10))
              .toIso8601String();
        return (status: 200, data: data);
      };
      final r = build();
      final ref = _parse('$_shopA/c/a.webp');
      await r.resolve(ref);
      now = now.add(const Duration(minutes: 8, seconds: 59));
      expect(r.peek(ref), isNotNull);
      now = now.add(const Duration(seconds: 2));
      expect(r.peek(ref), isNull);
    });

    test('401 → old public URL, then no sign attempts for 1 minute', () async {
      edge.reply = (_) =>
          (status: 401, data: {'ok': false, 'error': 'login_required'});
      final r = build();
      final raw = _publicUrl('chart_photos', '$_shopA/c/a.webp');
      expect(await r.resolve(_parse(raw)), 'legacy:$raw');
      expect(
        await r.resolve(_parse('$_shopA/c/b.webp')),
        'legacy:$_shopA/c/b.webp',
      );
      expect(edge.callCount, 1);
      expect(r.cacheSize, 0);

      now = now.add(const Duration(minutes: 1, seconds: 1));
      edge.reply = _FakeEdge._signAll;
      expect(
        await r.resolve(_parse(raw)),
        _signed('chart_photos', '$_shopA/c/a.webp'),
      );
      expect(edge.callCount, 2);
    });

    test(
      '403 → old public URL and that shop is skipped; other shops still sign',
      () async {
        edge.reply = (body) {
          final path =
              ((body['refs']! as List).first as Map)['path']! as String;
          return path.startsWith(_shopB)
              ? (
                  status: 403,
                  data: {
                    'ok': false,
                    'error': 'forbidden',
                    'forbidden': [0],
                  },
                )
              : _FakeEdge._signAll(body);
        };
        final r = build();
        final results = await Future.wait([
          r.resolve(_parse('$_shopA/c/a.webp')),
          r.resolve(_parse('$_shopB/c/b.webp')),
        ]);
        expect(results, [
          _signed('chart_photos', '$_shopA/c/a.webp'),
          'legacy:$_shopB/c/b.webp',
        ]);
        expect(edge.callCount, 2);

        expect(
          await r.resolve(_parse('$_shopB/c/other.webp')),
          'legacy:$_shopB/c/other.webp',
        );
        expect(edge.callCount, 2);
      },
    );

    test(
      'network failure / 5xx / thrown errors → old public URL, retried next time',
      () async {
        final r = build();
        final ref = _parse('$_shopA/c/a.webp');
        for (final reply
            in <MediaSignTransportResponse Function(Map<String, Object?>)>[
              (_) => (status: 0, data: null),
              (_) =>
                  (status: 500, data: {'ok': false, 'error': 'server_error'}),
              (_) => throw StateError('boom'),
            ]) {
          edge.reply = reply;
          expect(await r.resolve(ref), 'legacy:$_shopA/c/a.webp');
        }
        expect(edge.callCount, 3);
        expect(r.cacheSize, 0);
        expect(r.pendingCount, 0);
      },
    );

    test(
      'object not found → old public URL, remembered for 1 minute',
      () async {
        edge.reply = (body) => (
          status: 200,
          data: {
            'ok': true,
            'items': [
              {'index': 0, 'signed_url': null, 'error': 'not_found'},
            ],
          },
        );
        final r = build();
        final ref = _parse('$_shopA/c/gone.webp');
        expect(await r.resolve(ref), 'legacy:$_shopA/c/gone.webp');
        expect(await r.resolve(ref), 'legacy:$_shopA/c/gone.webp');
        expect(r.peek(ref), isNull);
        expect(edge.callCount, 1);

        now = now.add(const Duration(minutes: 2));
        await r.resolve(ref);
        expect(edge.callCount, 2);
      },
    );

    test(
      'clear() drops cache; replies that arrive after clear are not cached',
      () async {
        final r = build();
        final ref = _parse('$_shopA/c/a.webp');
        await r.resolve(ref);
        expect(r.cacheSize, 1);
        r.clear();
        expect(r.cacheSize, 0);

        final inFlight = r.resolve(_parse('$_shopA/c/b.webp'));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        r.clear();
        expect(await inFlight, _signed('chart_photos', '$_shopA/c/b.webp'));
        expect(r.cacheSize, 0);
      },
    );

    test(
      'default fallback is exactly StorageImageUrl.resolve (today\'s display URL)',
      () async {
        final r = MediaUrlResolver(
          client: MediaSignClient(transport: edge.call),
          canSign: () => false,
        );
        for (final (raw, bucket) in [
          ('https://cdn.example.com/a.webp', 'chart_photos'),
          (_publicUrl('chart_photos', '$_shopA/c/a.webp'), 'chart_photos'),
          ('$_shopA/c/a.webp', 'chart_photos'),
          ('$_shopA/c/s.png', 'chart-signatures'),
          (
            '/storage/v1/object/public/consent_pdfs/$_shopA/x.pdf',
            'consent_pdfs',
          ),
          ('data:image/png;base64,AA', 'chart_photos'),
          ('', 'chart_photos'),
        ]) {
          expect(
            await r.resolveRaw(raw, defaultBucket: bucket),
            StorageImageUrl.resolve(raw, bucket: bucket),
            reason: raw,
          );
        }
        expect(edge.callCount, 0);
      },
    );
  });
}
