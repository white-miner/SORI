import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sori/features/market_strategy/market_api_failure.dart';
import 'package:sori/features/market_strategy/market_query_cache.dart';
import 'package:sori/features/market_strategy/market_strategy_models.dart';
import 'package:sori/features/market_strategy/market_data_provider.dart';
import 'package:sori/features/market_strategy/public_data_client.dart';
import 'package:sori/config/env.dart';
import 'package:sori/models/shop.dart';

void main() {
  test('JSON fixture normalizes shops without leaking keys', () {
    final raw = File('test/fixtures/store_list_in_radius.json').readAsStringSync();
    expect(raw.toLowerCase().contains('servicekey'), isFalse);
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: raw,
      originLat: 35.8534,
      originLng: 129.2087,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.recordCount, 2);
    expect(parsed.items.first.trade, MarketTrade.skin);
    expect(PublicDataClient.normalizeTrade('피부미용업'), MarketTrade.skin);
    expect(PublicDataClient.normalizeTrade('두발미용업'), MarketTrade.hair);
  });

  test('XML auth error is classified without echoing body secrets', () {
    const xml = '''
<OpenAPI_ServiceResponse><cmmMsgHeader>
<returnReasonCode>30</returnReasonCode>
</cmmMsgHeader></OpenAPI_ServiceResponse>
''';
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: xml,
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'xml_30');
    expect(jsonEncode(parsed.errorCode).contains('serviceKey'), isFalse);
  });

  test('malformed JSON', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: '{not-json',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'json_parse_error');
  });

  test('empty items stay ok with zero records', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body:
          '{"header":{"resultCode":"00","resultMsg":"NORMAL SERVICE."},"body":{"totalCount":0,"items":[]}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.recordCount, 0);
    expect(parsed.totalCount, 0);
  });

  test('HTTP 200 error JSON is unavailable', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body:
          '{"cmmMsgHeader":{"errMsg":"SERVICE ERROR","returnAuthMsg":"SERVICE_KEY_IS_NOT_REGISTERED_ERROR","returnReasonCode":"30"}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'xml_30');
    expect(parsed.recordCount, 0);
  });

  test('HTTP 200 resultCode 00 and totalCount 0 is live empty not error', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body:
          '{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL SERVICE."},"body":{"totalCount":0,"items":{"item":[]}}}}',
      originLat: 37.5665,
      originLng: 126.9780,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.totalCount, 0);
    expect(parsed.items, isEmpty);
  });

  test('HTTP 200 missing body is unavailable', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: '{"header":{"resultCode":"00"}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'missing_body');
  });

  test('positive totalCount without parseable items is unavailable', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body:
          '{"header":{"resultCode":"00"},"body":{"totalCount":5,"items":[]}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'positive_total_without_parseable_items');
  });

  test('HTTP 500 is unavailable even with success-shaped JSON', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 500,
      body:
          '{"header":{"resultCode":"00"},"body":{"totalCount":1,"items":[{"bizesNm":"A피부","lat":35.85,"lon":129.2,"indsSclsNm":"피부미용업"}]}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isFalse);
    expect(parsed.errorCode, 'http_500');
    expect(parsed.items, isEmpty);
  });

  test('XML success response maps shops', () {
    const xml = '''
<response>
  <header><resultCode>00</resultCode><resultMsg>NORMAL SERVICE.</resultMsg></header>
  <body>
    <totalCount>1</totalCount>
    <items>
      <item>
        <bizesNm>A피부</bizesNm>
        <lat>35.85</lat>
        <lon>129.20</lon>
        <indsSclsNm>피부미용업</indsSclsNm>
        <rdnmAdr>경북 경주시</rdnmAdr>
      </item>
    </items>
  </body>
</response>
''';
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: xml,
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.recordCount, 1);
    expect(parsed.items.first.trade, MarketTrade.skin);
    expect(parsed.items.first.hasCoords, isTrue);
  });

  test('shops without coords stay list-only', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body:
          '{"header":{"resultCode":"00"},"body":{"totalCount":1,"items":[{"bizesNm":"좌표없는피부","indsSclsNm":"피부미용업","rdnmAdr":"경북 경주시"}]}}',
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.items, hasLength(1));
    expect(parsed.items.first.hasCoords, isFalse);
    expect(parsed.items.first.trade, MarketTrade.skin);
  });

  test('KSIC names classify exact and similar trades', () {
    expect(PublicDataClient.classifyTrade('이용업').trade, MarketTrade.barber);
    expect(PublicDataClient.classifyTrade('이용업').similarMatch, isFalse);
    expect(PublicDataClient.classifyTrade('두발미용업').trade, MarketTrade.hair);
    expect(PublicDataClient.classifyTrade('피부미용업').trade, MarketTrade.skin);
    expect(
      PublicDataClient.classifyTrade('기타미용업', name: '네일아트').trade,
      MarketTrade.nail,
    );
    expect(
      PublicDataClient.classifyTrade('기타미용업', name: '네일아트').similarMatch,
      isTrue,
    );
    expect(
      PublicDataClient.classifyTrade('피부미용업', name: '속눈썹 연장').trade,
      MarketTrade.lash,
    );
    expect(
      PublicDataClient.classifyTrade('피부미용업', name: '반영구 눈썹').trade,
      MarketTrade.tattoo,
    );
    expect(
      PublicDataClient.classifyTrade('피부미용업', name: '눈썹').needsReview,
      isTrue,
    );
    expect(
      PublicDataClient.classifyTrade('피부미용업', name: '눈썹').trade,
      MarketTrade.lash,
    );
    expect(PublicDataClient.classifyTrade('피부과의원').excluded, isTrue);
    expect(PublicDataClient.classifyTrade('마사지샵').excluded, isTrue);
    expect(PublicDataClient.classifyTrade('체형관리').excluded, isTrue);
    final unknown = PublicDataClient.mapStoreItem(
      {'bizesNm': '동네슈퍼', 'indsSclsNm': '슈퍼마켓', 'lat': 35.85, 'lon': 129.2},
      35.85,
      129.20,
    );
    expect(unknown, isNull);
    final brow = PublicDataClient.mapStoreItem(
      {
        'bizesNm': '눈썹만있는샵',
        'indsSclsNm': '피부미용업',
        'lat': 35.85,
        'lon': 129.2,
      },
      35.85,
      129.20,
    );
    expect(brow, isNotNull);
    expect(brow!.needsReview, isTrue);
    expect(brow.matchBadge, '분류 확인 필요');
    expect(brow.similarMatch, isTrue);
  });


  test('cache freshness is cached then stale then still readable', () {
    final cache = MarketQueryCache(
      ttl: const Duration(hours: 6),
      staleAfter: const Duration(hours: 2),
    );
    final snap = MarketSnapshot(
      status: MarketDataStatus.live,
      centerLat: 35.85,
      centerLng: 129.2,
      radiusKm: 1,
      trade: MarketTrade.skin,
      competitors: const [],
      fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
      competitionMeta: const IndicatorMeta(
        source: 's',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '1km',
      ),
      populationMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      footMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      trendMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
    );
    expect(cache.freshnessOf(snap), MarketDataStatus.stale);
    expect(
      cache.freshnessOf(
        snap.copyWithStatus(MarketDataStatus.live),
        now: DateTime.now().toUtc(),
      ),
      MarketDataStatus.stale,
    );
  });

  test('429 retries then stops', () async {
    var hits = 0;
    final client = PublicDataClient(
      httpClient: MockClient((_) async {
        hits += 1;
        return http.Response('rate', 429);
      }),
      serviceKey: 'test-key',
      maxRetries: 2,
      timeout: const Duration(seconds: 2),
    );
    final res = await client.fetchStoresInRadius(
      lat: 35.85,
      lng: 129.20,
      radiusM: 1000,
    );
    expect(hits, 3);
    expect(res.httpStatus, 429);
    expect(res.failure, MarketApiFailure.rateLimited);
    expect(res.userMessage.contains('다시 시도'), isTrue);
  });

  test('timeout classified', () async {
    final client = PublicDataClient(
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response('ok', 200);
      }),
      serviceKey: 'test-key',
      maxRetries: 0,
      timeout: const Duration(milliseconds: 10),
    );
    final res = await client.fetchStoresInRadius(
      lat: 35.85,
      lng: 129.20,
      radiusM: 1000,
    );
    expect(res.failure, MarketApiFailure.timeout);
  });

  test('cancellation returns cancelled', () async {
    final token = MarketRequestToken()..cancel();
    final client = PublicDataClient(serviceKey: 'test-key', maxRetries: 0);
    final res = await client.fetchStoresInRadius(
      lat: 35.85,
      lng: 129.20,
      radiusM: 1000,
      token: token,
    );
    expect(res.failure, MarketApiFailure.cancelled);
  });

  test('density uses pi r^2', () {
    const snap = MarketSnapshot(
      status: MarketDataStatus.live,
      centerLat: 35.85,
      centerLng: 129.2,
      radiusKm: 1,
      trade: MarketTrade.skin,
      competitors: [
        CompetitorShop(
          id: '1',
          name: 'a',
          trade: MarketTrade.skin,
          lat: 35.85,
          lng: 129.2,
          address: '',
          distanceM: 10,
        ),
      ],
      competitionMeta: IndicatorMeta(
        source: 's',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '1km',
      ),
      populationMeta: IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      footMeta: IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      trendMeta: IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
    );
    expect(snap.densityPerKm2, closeTo(1 / 3.141592653589793, 0.0001));
  });

  test('cache key does not include secrets', () {
    final key = MarketQueryCache.key(
      lat: 35.8534,
      lng: 129.2087,
      radiusKm: 3,
      trade: MarketTrade.skin,
    );
    expect(key.contains('service'), isFalse);
    expect(key.startsWith('market:'), isTrue);
  });

  test('web does not allow direct public data until CORS is verified', () {
    expect(MarketFetchPolicy.allowDirectPublicData(isWeb: true), isFalse);
    expect(MarketFetchPolicy.allowDirectPublicData(isWeb: false), isTrue);
  });

  test('launch flags expose configured booleans only', () {
    final flags = Env.launchConfiguredFlags();
    expect(flags.keys, containsAll(['supabase', 'public_data', 'demo_market']));
    expect(flags.values.every((v) => v == true || v == false), isTrue);
  });

  test('production release disables demo', () {
    expect(Env.isReleaseProduction && Env.useDemoMarketData, isFalse);
  });

  test('item array is fully normalized, never first-only', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: jsonEncode({
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'totalCount': 3,
          'items': {
            'item': [
              {
                'bizesId': 'a',
                'bizesNm': '이용A',
                'lat': 35.85,
                'lon': 129.20,
                'indsSclsNm': '이용업',
              },
              {
                'bizesId': 'b',
                'bizesNm': '이용B',
                'lat': 35.851,
                'lon': 129.201,
                'indsSclsNm': '이용업',
              },
              {
                'bizesId': 'c',
                'bizesNm': '이용C',
                'lat': 35.852,
                'lon': 129.202,
                'indsSclsNm': '이용업',
              },
            ],
          },
        },
      }),
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.items, hasLength(3));
    expect(parsed.items.map((e) => e.name), ['이용A', '이용B', '이용C']);
    expect(parsed.audit?.rawItemCount, 3);
    expect(parsed.audit?.paginationContract, 'this_page_only');
  });

  test('single item object is wrapped to a one-element list', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: jsonEncode({
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'totalCount': 1,
          'items': {
            'item': {
              'bizesId': 'solo',
              'bizesNm': '솔로바버',
              'lat': 35.85,
              'lon': 129.20,
              'indsSclsNm': '이용업',
            },
          },
        },
      }),
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.name, '솔로바버');
  });

  test('same coordinates with different ids are not merged', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: jsonEncode({
        'header': {'resultCode': '00'},
        'body': {
          'totalCount': 2,
          'items': [
            {
              'bizesId': 'id-1',
              'bizesNm': '샵1',
              'lat': 35.85,
              'lon': 129.20,
              'indsSclsNm': '피부미용업',
            },
            {
              'bizesId': 'id-2',
              'bizesNm': '샵2',
              'lat': 35.85,
              'lon': 129.20,
              'indsSclsNm': '피부미용업',
            },
          ],
        },
      }),
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.items, hasLength(2));
    expect(parsed.audit?.coincidentCoordGroups, 1);
  });

  test('duplicate bizesId is deduped and counted', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: jsonEncode({
        'header': {'resultCode': '00'},
        'body': {
          'totalCount': 2,
          'items': [
            {
              'bizesId': 'same',
              'bizesNm': '원본',
              'lat': 35.85,
              'lon': 129.20,
              'indsSclsNm': '두발미용업',
            },
            {
              'bizesId': 'same',
              'bizesNm': '복제',
              'lat': 35.851,
              'lon': 129.201,
              'indsSclsNm': '두발미용업',
            },
          ],
        },
      }),
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.name, '원본');
    expect(parsed.audit?.dropReasons['dedupe_bizesId'], 1);
  });

  test('totalCount larger than this page is contractUnknown without fetching more', () {
    final parsed = PublicDataClient.parseResponse(
      httpStatus: 200,
      body: jsonEncode({
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'totalCount': 50,
          'items': [
            {
              'bizesNm': '페이지1-1',
              'lat': 35.85,
              'lon': 129.20,
              'indsSclsNm': '피부미용업',
            },
            {
              'bizesNm': '페이지1-2',
              'lat': 35.851,
              'lon': 129.201,
              'indsSclsNm': '피부미용업',
            },
          ],
        },
      }),
      originLat: 35.85,
      originLng: 129.20,
    );
    expect(parsed.ok, isTrue);
    expect(parsed.items, hasLength(2));
    expect(parsed.audit?.paginationContract, 'contractUnknown');
    expect(parsed.audit?.responseTotalCount, 50);
    expect(parsed.audit?.rawItemCount, 2);
  });

  test('provider keeps every exact trade match in state', () async {
    final provider = PublicMarketProvider(
      shop: const Shop(id: 's', name: 's', naverPlaceUrl: ''),
      client: PublicDataClient(
        httpClient: MockClient((_) async {
          final body = jsonEncode({
              'header': {'resultCode': '00'},
              'body': {
                'totalCount': 3,
                'items': [
                  {
                    'bizesId': 'b1',
                    'bizesNm': 'barber-1',
                    'lat': 35.85,
                    'lon': 129.20,
                    'indsSclsNm': '이용업',
                  },
                  {
                    'bizesId': 'b2',
                    'bizesNm': 'barber-2',
                    'lat': 35.851,
                    'lon': 129.201,
                    'indsSclsNm': '이용업',
                  },
                  {
                    'bizesId': 'h1',
                    'bizesNm': 'hair-1',
                    'lat': 35.852,
                    'lon': 129.202,
                    'indsSclsNm': '두발미용업',
                  },
                ],
              },
            });
          return http.Response.bytes(
            utf8.encode(body),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        serviceKey: 'test-key',
      ),
    );
    final snap = await provider.load(
      lat: 35.85,
      lng: 129.20,
      radiusKm: 1,
      trade: MarketTrade.barber,
    );
    expect(snap.status, MarketDataStatus.live);
    expect(snap.competitors.where((s) => !s.similarMatch), hasLength(2));
    expect(snap.competitors.where((s) => s.similarMatch), hasLength(1));
    expect(StoreLoadAudit.last?.stateCount, 3);
  });
}
