import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/env.dart';
import 'market_api_failure.dart';
import 'market_strategy_models.dart';

/// 요청 1회 파이프라인 개수. 비밀값·상호·주소는 넣지 않는다.
class StoreLoadAudit {
  const StoreLoadAudit({
    required this.source,
    required this.category,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.httpStatus,
    required this.resultCode,
    required this.resultMsg,
    required this.responseTotalCount,
    required this.rawItemCount,
    required this.normalizedCount,
    required this.afterFilterCount,
    required this.afterCoordCount,
    required this.afterDedupeCount,
    required this.stateCount,
    required this.renderedMarkerCount,
    required this.paginationContract,
    required this.dropReasons,
    required this.coincidentCoordGroups,
  });

  static StoreLoadAudit? last;

  final String source;
  final String category;
  final double lat;
  final double lng;
  final int radiusM;
  final int httpStatus;
  final String resultCode;
  final String resultMsg;
  final int? responseTotalCount;
  final int rawItemCount;
  final int normalizedCount;
  final int afterFilterCount;
  final int afterCoordCount;
  final int afterDedupeCount;
  final int stateCount;
  final int renderedMarkerCount;
  final String paginationContract;
  final Map<String, int> dropReasons;
  final int coincidentCoordGroups;

  StoreLoadAudit copyWith({
    String? source,
    String? category,
    double? lat,
    double? lng,
    int? radiusM,
    int? afterFilterCount,
    int? afterCoordCount,
    int? stateCount,
    int? renderedMarkerCount,
    int? coincidentCoordGroups,
    Map<String, int>? dropReasons,
  }) {
    return StoreLoadAudit(
      source: source ?? this.source,
      category: category ?? this.category,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusM: radiusM ?? this.radiusM,
      httpStatus: httpStatus,
      resultCode: resultCode,
      resultMsg: resultMsg,
      responseTotalCount: responseTotalCount,
      rawItemCount: rawItemCount,
      normalizedCount: normalizedCount,
      afterFilterCount: afterFilterCount ?? this.afterFilterCount,
      afterCoordCount: afterCoordCount ?? this.afterCoordCount,
      afterDedupeCount: afterDedupeCount,
      stateCount: stateCount ?? this.stateCount,
      renderedMarkerCount: renderedMarkerCount ?? this.renderedMarkerCount,
      paginationContract: paginationContract,
      dropReasons: dropReasons ?? this.dropReasons,
      coincidentCoordGroups: coincidentCoordGroups ?? this.coincidentCoordGroups,
    );
  }

  Map<String, Object?> toJson() => {
        'source': source,
        'category': category,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'httpStatus': httpStatus,
        'resultCode': resultCode,
        'resultMsg': resultMsg,
        'responseTotalCount': responseTotalCount,
        'rawItemCount': rawItemCount,
        'normalizedCount': normalizedCount,
        'afterFilterCount': afterFilterCount,
        'afterCoordCount': afterCoordCount,
        'afterDedupeCount': afterDedupeCount,
        'stateCount': stateCount,
        'renderedMarkerCount': renderedMarkerCount,
        'paginationContract': paginationContract,
        'dropReasons': dropReasons,
        'coincidentCoordGroups': coincidentCoordGroups,
      };

  void debugDump() {
    debugPrint('[SORI_STORE_AUDIT] ${jsonEncode(toJson())}');
    last = this;
  }
}

class PublicStoreQueryResult {
  const PublicStoreQueryResult({
    required this.ok,
    required this.httpStatus,
    required this.recordCount,
    required this.items,
    this.totalCount,
    this.errorCode,
    this.failure = MarketApiFailure.unknown,
    this.attempts = 1,
    this.resultCode = '',
    this.resultMsg = '',
    this.audit,
  });

  final bool ok;
  final int httpStatus;
  final int recordCount;
  final List<CompetitorShop> items;
  final int? totalCount;
  final String? errorCode;
  final MarketApiFailure failure;
  final int attempts;
  final String resultCode;
  final String resultMsg;
  final StoreLoadAudit? audit;

  String get userMessage => MarketApiFailureX.userMessage(failure);
}

/// 소상공인시장진흥공단 상가(상권)정보 — 반경 업소 조회.
/// serviceKey 값·전체 요청 URL은 로그하지 않는다.
class PublicDataClient {
  PublicDataClient({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 12),
    String? serviceKey,
    this.maxRetries = 2,
    this.maxBodyBytes = 1500000,
  })  : _http = httpClient ?? http.Client(),
        // ignore: prefer_initializing_formals
        _timeout = timeout,
        _serviceKeyOverride = serviceKey;

  static const storesEndpoint =
      'https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius';

  final http.Client _http;
  final Duration _timeout;
  final String? _serviceKeyOverride;
  final int maxRetries;
  final int maxBodyBytes;

  bool get keyConfigured {
    final key = _serviceKeyOverride ?? Env.publicDataServiceKey;
    return key.trim().isNotEmpty;
  }

  Future<PublicStoreQueryResult> fetchStoresInRadius({
    required double lat,
    required double lng,
    required int radiusM,
    int pageNo = 1,
    int numOfRows = 100,
    MarketRequestToken? token,
  }) async {
    final key = (_serviceKeyOverride ?? Env.publicDataServiceKey).trim();
    if (key.isEmpty) {
      return const PublicStoreQueryResult(
        ok: false,
        httpStatus: 0,
        errorCode: 'missing_service_key',
        recordCount: 0,
        items: [],
        failure: MarketApiFailure.unauthorizedOrInvalidKey,
      );
    }

    final uri = Uri.parse(storesEndpoint).replace(
      queryParameters: {
        'serviceKey': _rawServiceKey(key),
        'pageNo': '$pageNo',
        'numOfRows': '$numOfRows',
        'radius': '$radiusM',
        'cx': lng.toString(),
        'cy': lat.toString(),
        'type': 'json',
      },
    );

    var attempt = 0;
    PublicStoreQueryResult? last;
    while (attempt <= maxRetries) {
      if (token?.cancelled == true) {
        return PublicStoreQueryResult(
          ok: false,
          httpStatus: 0,
          errorCode: 'cancelled',
          recordCount: 0,
          items: const [],
          failure: MarketApiFailure.cancelled,
          attempts: attempt,
        );
      }
      attempt += 1;
      try {
        final res = await _http.get(uri).timeout(_timeout);
        if (res.bodyBytes.length > maxBodyBytes) {
          return PublicStoreQueryResult(
            ok: false,
            httpStatus: res.statusCode,
            errorCode: 'payload_too_large',
            recordCount: 0,
            items: const [],
            failure: MarketApiFailure.malformedResponse,
            attempts: attempt,
          );
        }
        last = parseResponse(
          httpStatus: res.statusCode,
          body: res.body,
          originLat: lat,
          originLng: lng,
        );
        final failure = last.ok
            ? MarketApiFailure.none
            : MarketApiFailureX.fromHttp(
                status: last.httpStatus,
                errorCode: last.errorCode,
                emptyItems: last.items.isEmpty,
              );
        last = PublicStoreQueryResult(
          ok: last.ok,
          httpStatus: last.httpStatus,
          recordCount: last.recordCount,
          items: last.items,
          totalCount: last.totalCount,
          errorCode: last.errorCode,
          failure: failure,
          attempts: attempt,
          resultCode: last.resultCode,
          resultMsg: last.resultMsg,
          audit: last.audit,
        );
        final retryable = res.statusCode == 429 || res.statusCode >= 500;
        if (!retryable || attempt > maxRetries) return last;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt * attempt));
      } on Exception catch (e) {
        final timeout = e.toString().toLowerCase().contains('timeout') ||
            e.toString().contains('TimeoutException');
        last = PublicStoreQueryResult(
          ok: false,
          httpStatus: 0,
          errorCode: timeout ? 'timeout' : 'network_error',
          recordCount: 0,
          items: const [],
          failure: timeout
              ? MarketApiFailure.timeout
              : MarketApiFailure.networkOffline,
          attempts: attempt,
        );
        if (!timeout || attempt > maxRetries) return last;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt * attempt));
      }
    }
    return last ??
        const PublicStoreQueryResult(
          ok: false,
          httpStatus: 0,
          errorCode: 'unknown',
          recordCount: 0,
          items: [],
          failure: MarketApiFailure.unknown,
        );
  }

  /// 테스트용: 이중 인코딩 없이 Uri가 쓸 원문 키.
  static String rawServiceKeyForTest(String raw) => _rawServiceKey(raw);

  static String _rawServiceKey(String raw) {
    final k = raw.trim();
    final percentEncoded = RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(k);
    final looksRaw = k.contains('+') || k.contains('/') || k.contains('=');
    if (percentEncoded && !looksRaw) {
      return Uri.decodeQueryComponent(k);
    }
    return k;
  }

  static PublicStoreQueryResult parseResponse({
    required int httpStatus,
    required String body,
    required double originLat,
    required double originLng,
  }) {
    if (httpStatus < 200 || httpStatus >= 300) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'http_$httpStatus',
        recordCount: 0,
        items: const [],
      );
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'empty_body',
        recordCount: 0,
        items: const [],
      );
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('<html') || lower.contains('<!doctype html')) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'malformed_body',
        recordCount: 0,
        items: const [],
      );
    }

    final xmlAuth = _xmlAuthError(trimmed);
    if (xmlAuth != null) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: xmlAuth,
        recordCount: 0,
        items: const [],
      );
    }

    Map<String, dynamic>? jsonMap;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          jsonMap = decoded;
        } else if (decoded is Map) {
          jsonMap = Map<String, dynamic>.from(decoded);
        } else {
          return PublicStoreQueryResult(
            ok: false,
            httpStatus: httpStatus,
            errorCode: 'malformed_body',
            recordCount: 0,
            items: const [],
          );
        }
      } catch (_) {
        return PublicStoreQueryResult(
          ok: false,
          httpStatus: httpStatus,
          errorCode: 'json_parse_error',
          recordCount: 0,
          items: const [],
        );
      }
    }

    if (jsonMap != null) {
      final cmm = _findCmmHeader(jsonMap);
      if (cmm != null) {
        final reason = (cmm['returnReasonCode'] ??
                cmm['returnAuthMsg'] ??
                cmm['errMsg'] ??
                'auth')
            .toString()
            .trim();
        return PublicStoreQueryResult(
          ok: false,
          httpStatus: httpStatus,
          errorCode: 'xml_$reason',
          recordCount: 0,
          items: const [],
        );
      }
    }

    final resultCode = jsonMap != null
        ? (_deepString(jsonMap, const ['header', 'resultCode']) ??
            _deepString(jsonMap, const ['response', 'header', 'resultCode']) ??
            '')
        : (_xmlTag(trimmed, 'resultCode') ?? '');
    final resultMsg = jsonMap != null
        ? (_deepString(jsonMap, const ['header', 'resultMsg']) ??
            _deepString(jsonMap, const ['response', 'header', 'resultMsg']) ??
            '')
        : (_xmlTag(trimmed, 'resultMsg') ?? '');
    if (!_resultCodeOk(resultCode)) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: resultCode.isEmpty
            ? 'result_not_ok'
            : 'api_$resultCode',
        recordCount: 0,
        items: const [],
        resultCode: resultCode,
        resultMsg: resultMsg,
      );
    }

    final bodyMap = jsonMap == null
        ? null
        : (_asMap(jsonMap['body']) ??
            _asMap(_asMap(jsonMap['response'])?['body']));
    if (jsonMap != null && bodyMap == null) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'missing_body',
        recordCount: 0,
        items: const [],
      );
    }
    if (jsonMap == null && !_xmlHasBody(trimmed)) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'missing_body',
        recordCount: 0,
        items: const [],
      );
    }

    final totalCount = jsonMap != null
        ? _readTotalCount(bodyMap)
        : _readInt(_xmlTag(trimmed, 'totalCount'));
    final rawItems = jsonMap != null
        ? extractStoreMaps(jsonMap)
        : _extractXmlItemMaps(trimmed);

    if (totalCount == null && rawItems.isEmpty) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'invalid_total_count',
        recordCount: 0,
        items: const [],
      );
    }
    if (totalCount != null && totalCount < 0) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'invalid_total_count',
        recordCount: 0,
        items: const [],
      );
    }
    if ((totalCount ?? 0) > 0 && rawItems.isEmpty) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'positive_total_without_parseable_items',
        recordCount: 0,
        items: const [],
        totalCount: totalCount,
      );
    }

    final dropReasons = <String, int>{};
    void drop(String reason) {
      dropReasons[reason] = (dropReasons[reason] ?? 0) + 1;
    }

    final seenIds = <String>{};
    final dedupedRaw = <Map<String, dynamic>>[];
    for (final raw in rawItems) {
      final id =
          '${raw['bizesId'] ?? raw['bizesNo'] ?? ''}'.trim();
      if (id.isNotEmpty) {
        if (seenIds.contains(id)) {
          drop('dedupe_bizesId');
          continue;
        }
        seenIds.add(id);
      }
      dedupedRaw.add(raw);
    }

    final items = <CompetitorShop>[];
    var namedRaw = 0;
    for (final raw in dedupedRaw) {
      final name =
          '${raw['bizesNm'] ?? raw['storeNm'] ?? raw['name'] ?? ''}'.trim();
      if (name.isNotEmpty) namedRaw += 1;
      final shop = mapStoreItem(raw, originLat, originLng);
      if (shop == null) {
        if (name.isEmpty) {
          drop('empty_name');
        } else {
          final label = [
            raw['indsSclsNm'],
            raw['indsMclsNm'],
            raw['indsLclsNm'],
            raw['sclsNm'],
          ].map((e) => '$e'.trim()).where((e) => e.isNotEmpty && e != 'null').join(' ');
          final classified = classifyTrade(label, name: name);
          if (classified.excluded) {
            drop('excluded_category');
          } else if (classified.unclassified) {
            drop('unclassified_trade');
          } else {
            drop('map_rejected');
          }
        }
        continue;
      }
      items.add(shop);
    }
    if ((totalCount ?? 0) > 0 && namedRaw == 0 && rawItems.isNotEmpty) {
      return PublicStoreQueryResult(
        ok: false,
        httpStatus: httpStatus,
        errorCode: 'positive_total_without_parseable_items',
        recordCount: 0,
        items: const [],
        totalCount: totalCount,
        resultCode: resultCode,
        resultMsg: resultMsg,
      );
    }
    items.sort((a, b) {
      if (a.hasCoords != b.hasCoords) return a.hasCoords ? -1 : 1;
      return a.distanceM.compareTo(b.distanceM);
    });

    final resolvedTotal = totalCount ?? items.length;
    final pageUnknown = totalCount != null && totalCount > rawItems.length;
    final coordOk = items.where((s) => s.hasCoords).length;
    final audit = StoreLoadAudit(
      source: 'LIVE',
      category: '',
      lat: originLat,
      lng: originLng,
      radiusM: 0,
      httpStatus: httpStatus,
      resultCode: resultCode,
      resultMsg: resultMsg,
      responseTotalCount: totalCount,
      rawItemCount: rawItems.length,
      normalizedCount: rawItems.length,
      afterFilterCount: items.length,
      afterCoordCount: coordOk,
      afterDedupeCount: dedupedRaw.length,
      stateCount: items.length,
      renderedMarkerCount: 0,
      paginationContract: pageUnknown ? 'contractUnknown' : 'this_page_only',
      dropReasons: dropReasons,
      coincidentCoordGroups: _coincidentCoordGroups(items),
    );
    audit.debugDump();

    return PublicStoreQueryResult(
      ok: true,
      httpStatus: httpStatus,
      errorCode: null,
      recordCount: items.length,
      items: items,
      totalCount: resolvedTotal,
      resultCode: resultCode,
      resultMsg: resultMsg,
      audit: audit,
    );
  }

  static List<Map<String, dynamic>> extractStoreMaps(Map<String, dynamic> root) {
    final found = <Map<String, dynamic>>[];
    void walk(dynamic node, int depth) {
      if (depth > 8 || node == null) return;
      if (node is List) {
        if (node.isEmpty) return;
        // 공공 API는 1건일 때 List가 아니라 단일 object를 준다.
        // 배열이면 전 원소를 정규화하고 첫 원소만 쓰지 않는다.
        final asMaps = <Map<String, dynamic>>[];
        for (final e in node) {
          asMaps.addAll(_coerceStoreMaps(e));
        }
        if (asMaps.isNotEmpty && asMaps.any(_looksLikeStore)) {
          found.addAll(asMaps.where(_looksLikeStore));
          return;
        }
        for (final e in node) {
          walk(e, depth + 1);
        }
        return;
      }
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        if (map.containsKey('item')) {
          walk(map['item'], depth + 1);
          return;
        }
        if (map.containsKey('items')) {
          walk(map['items'], depth + 1);
          return;
        }
        if (_looksLikeStore(map)) {
          found.add(map);
          return;
        }
        for (final v in map.values) {
          walk(v, depth + 1);
        }
      }
    }

    walk(root, 0);
    return found;
  }

  /// item이 단일 object이거나 배열이거나 {item: ...} 래핑이어도 Store[]로 만든다.
  static List<Map<String, dynamic>> _coerceStoreMaps(dynamic node) {
    if (node is List) {
      return [for (final e in node) ..._coerceStoreMaps(e)];
    }
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      if (map.containsKey('item') && !_looksLikeStore(map)) {
        return _coerceStoreMaps(map['item']);
      }
      return [map];
    }
    return const [];
  }

  static bool _looksLikeStore(Map<String, dynamic> row) {
    return row.containsKey('bizesNm') ||
        row.containsKey('storeNm') ||
        row.containsKey('bizesId');
  }

  static int _coincidentCoordGroups(List<CompetitorShop> items) {
    final buckets = <String, int>{};
    for (final s in items) {
      if (!s.hasCoords) continue;
      final key =
          '${s.lat.toStringAsFixed(5)},${s.lng.toStringAsFixed(5)}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets.values.where((n) => n > 1).length;
  }

  static List<Map<String, dynamic>> _extractXmlItemMaps(String xml) {
    final out = <Map<String, dynamic>>[];
    final itemRe = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false);
    for (final m in itemRe.allMatches(xml)) {
      final body = m.group(1) ?? '';
      String tag(String name) {
        final t = RegExp(
          '<$name>([^<]*)</$name>',
          caseSensitive: false,
        ).firstMatch(body);
        return t?.group(1)?.trim() ?? '';
      }

      out.add({
        'bizesId': tag('bizesId'),
        'bizesNo': tag('bizesNo'),
        'bizesNm': tag('bizesNm'),
        'storeNm': tag('storeNm'),
        'lat': tag('lat').isNotEmpty ? tag('lat') : tag('latCrd'),
        'lon': tag('lon').isNotEmpty ? tag('lon') : tag('lonCrd'),
        'lng': tag('lng'),
        'cy': tag('cy'),
        'cx': tag('cx'),
        'rdnmAdr': tag('rdnmAdr'),
        'lnbrAdr': tag('lnbrAdr'),
        'lnoAdr': tag('lnoAdr'),
        'indsLclsNm': tag('indsLclsNm'),
        'indsMclsNm': tag('indsMclsNm'),
        'indsSclsNm': tag('indsSclsNm'),
      });
    }
    return out;
  }

  static String? _xmlAuthError(String body) {
    if (!body.contains('OpenAPI_ServiceResponse') &&
        !body.contains('cmmMsgHeader') &&
        !body.contains('returnReasonCode')) {
      return null;
    }
    final xmlCode = RegExp(
      r'<returnReasonCode>([^<]+)</returnReasonCode>',
      caseSensitive: false,
    ).firstMatch(body)?.group(1)?.trim();
    if (xmlCode != null && xmlCode.isNotEmpty) return 'xml_$xmlCode';
    final jsonCode = RegExp(
      r'"returnReasonCode"\s*:\s*"([^"]+)"',
    ).firstMatch(body)?.group(1)?.trim();
    if (jsonCode != null && jsonCode.isNotEmpty) return 'xml_$jsonCode';
    if (body.contains('cmmMsgHeader') ||
        body.contains('OpenAPI_ServiceResponse')) {
      return 'xml_auth_error';
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic>? _findCmmHeader(Map<String, dynamic> root) {
    final direct = _asMap(root['cmmMsgHeader']);
    if (direct != null) return direct;
    final wrapped = _asMap(root['OpenAPI_ServiceResponse']);
    final nested = _asMap(wrapped?['cmmMsgHeader']);
    if (nested != null) return nested;
    for (final value in root.values) {
      final map = _asMap(value);
      if (map == null) continue;
      final inner = _asMap(map['cmmMsgHeader']);
      if (inner != null) return inner;
    }
    return null;
  }

  static bool _resultCodeOk(String code) {
    final trimmed = code.trim();
    return trimmed == '00' || trimmed == '0' || trimmed == '0000';
  }

  static int? _readTotalCount(Map<String, dynamic>? body) {
    if (body == null) return null;
    return _readInt(body['totalCount'] ?? body['totalcount']);
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value'.trim());
  }

  static String? _xmlTag(String xml, String name) {
    return RegExp(
      '<$name>\\s*([^<]*)\\s*</$name>',
      caseSensitive: false,
    ).firstMatch(xml)?.group(1)?.trim();
  }

  static bool _xmlHasBody(String xml) {
    return RegExp(r'<body[\s>]', caseSensitive: false).hasMatch(xml);
  }

  static String? _deepString(Map<String, dynamic> root, List<String> path) {
    dynamic cur = root;
    for (final key in path) {
      if (cur is Map && cur[key] != null) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur?.toString();
  }

  /// 원본 JSON 키는 storeListInRadius 공식 샘플이 없어 후보 fallback이다.
  /// indsSclsCd 값은 코드표 원문 확보 전까지 읽거나 하드코딩하지 않는다.
  static CompetitorShop? mapStoreItem(
    Map<String, dynamic> raw,
    double originLat,
    double originLng,
  ) {
    final name =
        '${raw['bizesNm'] ?? raw['storeNm'] ?? raw['name'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    final lat = _firstDouble(raw, const [
      'lat',
      'latCrd',
      'ycord',
      'cy',
      'y',
    ]);
    final lng = _firstDouble(raw, const [
      'lon',
      'lonCrd',
      'xcord',
      'cx',
      'x',
      'lng',
    ]);
    final inKorea = lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132;
    final hasCoords = lat.abs() >= 0.01 && lng.abs() >= 0.01 && inKorea;
    final label = [
      raw['indsSclsNm'],
      raw['indsMclsNm'],
      raw['indsLclsNm'],
      raw['sclsNm'],
    ].map((e) => '$e'.trim()).where((e) => e.isNotEmpty && e != 'null').join(' ');
    final classified = classifyTrade(label, name: name);
    if (classified.excluded) return null;
    if (classified.unclassified && !classified.needsReview) return null;
    final id =
        '${raw['bizesId'] ?? raw['bizesNo'] ?? '${hasCoords ? '$lat,$lng,' : ''}$name'}';
    return CompetitorShop(
      id: id,
      name: name,
      trade: classified.trade,
      lat: hasCoords ? lat : 0,
      lng: hasCoords ? lng : 0,
      address:
          '${raw['rdnmAdr'] ?? raw['lnbrAdr'] ?? raw['lnoAdr'] ?? raw['addr'] ?? ''}'
              .trim(),
      distanceM: hasCoords
          ? haversineM(originLat, originLng, lat, lng)
          : 0,
      similarMatch: classified.similarMatch || classified.needsReview,
      rawTradeLabel: label,
      hasCoords: hasCoords,
      needsReview: classified.needsReview,
    );
  }

  static String normalizeTrade(String label, {String name = ''}) {
    return classifyTrade(label, name: name).trade;
  }

  static TradeClassification classifyTrade(String label, {String name = ''}) {
    final text = '$label $name';
    final compact = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (_isExcluded(compact)) {
      return const TradeClassification(
        trade: MarketTrade.mixed,
        excluded: true,
      );
    }

    if (RegExp(r'반영구눈썹|눈썹문신|semipermanent|smp|타투|문신|tattoo|반영구')
        .hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.tattoo,
        similarMatch: true,
      );
    }
    if (RegExp(r'속눈썹|래쉬|lash|브로우리프트|눈썹손질|browlift|브로우펌')
        .hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.lash,
        similarMatch: true,
      );
    }
    if (RegExp(r'눈썹').hasMatch(compact) &&
        !RegExp(r'속눈썹|래쉬|lash|브로우|brow|반영구|문신').hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.lash,
        similarMatch: true,
        needsReview: true,
      );
    }
    if (RegExp(r'왁싱|waxing|제모').hasMatch(compact) &&
        !compact.contains('의료제모')) {
      return const TradeClassification(
        trade: MarketTrade.waxing,
        similarMatch: true,
      );
    }
    if (RegExp(r'메이크업|makeup|웨딩메이크업|출장메이크업').hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.makeup,
        similarMatch: true,
      );
    }
    if (RegExp(r'네일아트|네일|손톱|발톱|nail').hasMatch(compact) &&
        !compact.contains('네일용품')) {
      return const TradeClassification(
        trade: MarketTrade.nail,
        similarMatch: true,
      );
    }

    if (compact.contains('두발미용')) {
      return const TradeClassification(trade: MarketTrade.hair);
    }
    if (compact.contains('이용업') &&
        !compact.contains('이용및미용') &&
        !compact.contains('미용업')) {
      return const TradeClassification(trade: MarketTrade.barber);
    }
    if (compact.contains('피부미용') ||
        compact.contains('피부관리') ||
        compact.contains('에스테틱') ||
        compact.contains('스킨케어')) {
      return const TradeClassification(trade: MarketTrade.skin);
    }
    if (RegExp(r'바버|이발|이용원|barber|수염').hasMatch(compact) &&
        !RegExp(r'미용실|헤어샵|두발미용').hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.barber,
        similarMatch: true,
      );
    }
    if (RegExp(r'헤어샵|헤어|미용실|염색|파마|펌|커트|hair').hasMatch(compact) &&
        !RegExp(r'이발|이용원|바버').hasMatch(compact)) {
      return const TradeClassification(
        trade: MarketTrade.hair,
        similarMatch: true,
      );
    }
    return const TradeClassification(
      trade: MarketTrade.mixed,
      unclassified: true,
    );
  }

  static bool _isExcluded(String compact) {
    return RegExp(
      r'피부과|성형외과|성형외|한의원|병원|의원|목욕|사우나|찜질|마사지|안마|헬스장|피트니스|헬스클럽|체형|미용학원|학원|화장품|로드샵|가발|사진관|의료제모',
    ).hasMatch(compact);
  }

  static bool matchesTrade(String wanted, CompetitorShop shop) {
    return shop.trade == wanted;
  }

  static bool matchesSimilar(String wanted, CompetitorShop shop) {
    if (matchesTrade(wanted, shop)) return true;
    const related = <String, Set<String>>{
      MarketTrade.skin: {
        MarketTrade.waxing,
        MarketTrade.makeup,
        MarketTrade.lash,
      },
      MarketTrade.hair: {MarketTrade.barber},
      MarketTrade.barber: {MarketTrade.hair},
      MarketTrade.nail: {MarketTrade.lash},
      MarketTrade.makeup: {MarketTrade.lash, MarketTrade.skin},
      MarketTrade.lash: {MarketTrade.makeup, MarketTrade.nail},
      MarketTrade.tattoo: <String>{},
      MarketTrade.waxing: {MarketTrade.skin},
    };
    return related[wanted]?.contains(shop.trade) == true;
  }

  static double _firstDouble(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      if (!raw.containsKey(key)) continue;
      final value = _num(raw[key]);
      if (value.abs() >= 0.01) return value;
    }
    return 0;
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll(',', '')) ?? 0;
  }

  static int haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return (r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))).round();
  }
}

class TradeClassification {
  const TradeClassification({
    required this.trade,
    this.similarMatch = false,
    this.excluded = false,
    this.unclassified = false,
    this.needsReview = false,
  });

  final String trade;
  final bool similarMatch;
  final bool excluded;
  final bool unclassified;
  final bool needsReview;
}
