import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import '../../models/shop.dart';
import 'market_query_cache.dart';
import 'market_strategy_models.dart';
import 'public_data_client.dart';

/// CORS가 실측되기 전 웹 브라우저의 공공 API 직접 호출을 막는다.
abstract final class MarketFetchPolicy {
  static bool allowDirectPublicData({required bool isWeb}) => !isWeb;
}

abstract class MarketDataProvider {
  Future<MarketSnapshot> load({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    String addressLabel = '',
  });
}

/// 즉시 동작하는 데모 상권. 화면 상단에 데모 데이터라고 표시해야 한다.
class DemoMarketProvider implements MarketDataProvider {
  const DemoMarketProvider();

  static const seonggeon = (lat: 35.8534, lng: 129.2087, label: '경주시 성건동');
  static const hwangseong = (lat: 35.8688, lng: 129.2099, label: '경주시 황성동');
  static const dongcheon = (lat: 35.8452, lng: 129.2184, label: '경주시 동천동');

  static const demoMeta = IndicatorMeta(
    source: 'SORI 데모 시드 (공공 API 대체)',
    periodLabel: '2026년 8월 가정',
    updatedOn: '2026-09-13',
    geoUnit: '반경 원 (사용자 지정 km)',
    available: true,
    nextAction: 'LIVE 연결 후 같은 반경으로 다시 불러오세요.',
  );

  @override
  Future<MarketSnapshot> load({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    String addressLabel = '',
  }) async {
    final area = _nearestArea(lat, lng);
    final rivals = _seedShops(area, trade, lat, lng)
        .where((s) => s.distanceM <= radiusKm * 1000)
        .toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));

    final pop = switch (area.label) {
      '경주시 성건동' => 18420,
      '경주시 황성동' => 22110,
      _ => 15280,
    };
    final foot = switch (area.label) {
      '경주시 성건동' => 62.0,
      '경주시 황성동' => 71.0,
      _ => 54.0,
    };
    final trend = switch (area.label) {
      '경주시 성건동' => -2.4,
      '경주시 황성동' => 1.1,
      _ => -4.0,
    };
    final shopChg = switch (area.label) {
      '경주시 성건동' => 6.2,
      '경주시 황성동' => 2.0,
      _ => -1.5,
    };

    final snap = MarketSnapshot(
      status: MarketDataStatus.demo,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: rivals,
      population: pop,
      footIndex: foot,
      marketTrendPct: trend,
      shopCountChangePct: shopChg,
      competitionMeta: demoMeta.copyUnavailable(
        comparisonWarning: '경쟁 매장 정보는 참고용이며 오분류·폐업이 있을 수 있습니다.',
      ),
      populationMeta: demoMeta.copyUnavailable(
        source: '데모 주거 인구 (행정동 근사)',
        geoUnit: '행정동 근사 · 반경과 단위가 다를 수 있음',
        comparisonWarning: '인구는 행정동 단위, 경쟁은 반경 원이라 직접 비교에 주의하세요.',
      ),
      footMeta: demoMeta.copyUnavailable(
        source: '데모 유동 지수 0–100',
        nextAction: '현장 보행 수를 같은 시간대에 직접 세어 검증하세요.',
      ),
      trendMeta: demoMeta.copyUnavailable(
        source: '데모 시장 추이',
        periodLabel: '최근 12개월 가정',
      ),
      addressLabel: addressLabel.isEmpty ? area.label : addressLabel,
    );
    StoreLoadAudit(
      source: 'MOCK',
      category: trade,
      lat: lat,
      lng: lng,
      radiusM: (radiusKm * 1000).round(),
      httpStatus: 0,
      resultCode: '',
      resultMsg: 'demo_seed',
      responseTotalCount: rivals.length,
      rawItemCount: rivals.length,
      normalizedCount: rivals.length,
      afterFilterCount: rivals.length,
      afterCoordCount: rivals.where((s) => s.hasCoords).length,
      afterDedupeCount: rivals.length,
      stateCount: rivals.length,
      renderedMarkerCount: 0,
      paginationContract: 'this_page_only',
      dropReasons: const {},
      coincidentCoordGroups: 0,
    ).debugDump();
    return snap;
  }

  ({double lat, double lng, String label}) _nearestArea(double lat, double lng) {
    final areas = [seonggeon, hwangseong, dongcheon];
    areas.sort((a, b) {
      final da = (a.lat - lat) * (a.lat - lat) + (a.lng - lng) * (a.lng - lng);
      final db = (b.lat - lat) * (b.lat - lat) + (b.lng - lng) * (b.lng - lng);
      return da.compareTo(db);
    });
    return areas.first;
  }

  List<CompetitorShop> _seedShops(
    ({double lat, double lng, String label}) area,
    String trade,
    double originLat,
    double originLng,
  ) {
    const offsets = <(double, double, String, String)>[
      (0.002, 0.001, 'demo-skin-1', MarketTrade.skin),
      (-0.0015, 0.0022, 'demo-skin-2', MarketTrade.skin),
      (0.0031, -0.001, 'demo-hair-1', MarketTrade.hair),
      (-0.0024, -0.0018, 'demo-nail-1', MarketTrade.nail),
      (0.0012, 0.0034, 'demo-barber-1', MarketTrade.barber),
      (0.004, 0.0004, 'demo-lash-1', MarketTrade.lash),
      (-0.0033, 0.002, 'demo-tattoo-1', MarketTrade.tattoo),
      (0.0008, -0.0026, 'demo-wax-1', MarketTrade.waxing),
      (0.0027, 0.0029, 'demo-makeup-1', MarketTrade.makeup),
      (-0.004, 0.0011, 'demo-mixed-1', MarketTrade.mixed),
      (0.0055, -0.003, 'demo-skin-3', MarketTrade.skin),
      (-0.006, 0.004, 'demo-hair-2', MarketTrade.hair),
    ];
    final out = <CompetitorShop>[];
    for (final o in offsets) {
      if (trade != MarketTrade.mixed && o.$4 != trade) continue;
      final lat = area.lat + o.$1;
      final lng = area.lng + o.$2;
      final dist = _haversineM(originLat, originLng, lat, lng);
      out.add(
        CompetitorShop(
          id: '${area.label}-${o.$3}',
          name: '${MarketTrade.labelOf(o.$4)} 데모샵 ${o.$3.split('-').last}',
          trade: o.$4,
          lat: lat,
          lng: lng,
          address: '${area.label} 데모 주소',
          distanceM: dist,
        ),
      );
    }
    return out;
  }

  static int _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return (r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))).round();
  }
}

double _rad(double d) => d * math.pi / 180;

extension IndicatorMetaCopy on IndicatorMeta {
  IndicatorMeta copyUnavailable({
    String? source,
    String? periodLabel,
    String? geoUnit,
    String? nextAction,
    String? comparisonWarning,
    bool? available,
  }) {
    return IndicatorMeta(
      source: source ?? this.source,
      periodLabel: periodLabel ?? this.periodLabel,
      updatedOn: updatedOn,
      geoUnit: geoUnit ?? this.geoUnit,
      available: available ?? this.available,
      nextAction: nextAction ?? this.nextAction,
      comparisonWarning: comparisonWarning ?? this.comparisonWarning,
    );
  }
}

/// Live: 공공데이터 직접 호출. 실패 시 Demo로 바꾸지 않는다.
/// 캐시가 있으면 CACHED/STALE, 없으면 UNAVAILABLE.
class PublicMarketProvider implements MarketDataProvider {
  PublicMarketProvider({
    required this.shop,
    this.readCache,
    PublicDataClient? client,
    MarketQueryCache? cache,
  })  : _client = client ?? PublicDataClient(),
        _cache = cache ?? MarketQueryCache();

  final Shop shop;
  final MarketSnapshot? Function()? readCache;
  final PublicDataClient _client;
  final MarketQueryCache _cache;

  @override
  Future<MarketSnapshot> load({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    String addressLabel = '',
  }) async {
    if (Env.useDemoMarketData) {
      return DemoMarketProvider().load(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        trade: trade,
        addressLabel: addressLabel,
      );
    }

    if (!MarketFetchPolicy.allowDirectPublicData(isWeb: kIsWeb)) {
      return _unavailable(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        trade: trade,
        addressLabel: addressLabel,
        errorCode: 'web_cors_unverified',
        userMessage:
            '웹에서는 공공 상가 직접 조회를 아직 확인하지 못했어요. Windows 또는 앱에서 같은 위치를 조회하세요.',
      );
    }

    final radiusM = (radiusKm * 1000).round().clamp(100, 10000);
    final cacheKey = MarketQueryCache.key(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      trade: trade,
    );
    String? lastError;
    int? lastStatus;
    String? lastUser;

    if (_client.keyConfigured) {
      final direct = await _client.fetchStoresInRadius(
        lat: lat,
        lng: lng,
        radiusM: radiusM,
      );
      lastStatus = direct.httpStatus;
      lastError = direct.errorCode;
      lastUser = direct.userMessage;
      if (direct.ok) {
        final live = _fromCompetitors(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          trade: trade,
          addressLabel: addressLabel,
          all: direct.items,
          httpStatus: direct.httpStatus,
          source: '소상공인시장진흥공단 상가(상권)정보',
          cacheKey: cacheKey,
          parseAudit: direct.audit,
        );
        await _cache.persistPut(cacheKey, live);
        return live;
      }
    } else {
      lastError = 'missing_service_key';
      lastUser = '공공데이터 키가 없어 상가를 조회하지 못했습니다.';
    }

    final fromMem = _cache.memoryGet(cacheKey);
    final fromDisk = fromMem ?? await _cache.persistGet(cacheKey);
    final cached = fromDisk ?? readCache?.call();
    if (cached != null) {
      final snap = cached.copyWithStatus(_cache.freshnessOf(cached));
      debugPrint(
        '[SORI_STORE_AUDIT] ${{
          'source': 'CACHE',
          'category': trade,
          'lat': lat,
          'lng': lng,
          'radiusM': radiusM,
          'stateCount': snap.competitors.length,
        }}',
      );
      return snap;
    }

    return _unavailable(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      trade: trade,
      addressLabel: addressLabel,
      errorCode: lastError ?? 'unavailable',
      httpStatus: lastStatus,
      userMessage: lastUser,
    );
  }

  MarketSnapshot _fromCompetitors({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    required String addressLabel,
    required List<CompetitorShop> all,
    required int httpStatus,
    required String source,
    String? cacheKey,
    StoreLoadAudit? parseAudit,
  }) {
    final exact = <CompetitorShop>[];
    final similar = <CompetitorShop>[];
    var tradeMismatch = 0;
    for (final s in all) {
      if (PublicDataClient.matchesTrade(trade, s)) {
        exact.add(s);
      } else if (PublicDataClient.matchesSimilar(trade, s)) {
        similar.add(s.copyWith(similarMatch: true));
      } else {
        tradeMismatch += 1;
      }
    }
    int byDistance(CompetitorShop a, CompetitorShop b) {
      if (a.hasCoords != b.hasCoords) return a.hasCoords ? -1 : 1;
      return a.distanceM.compareTo(b.distanceM);
    }
    exact.sort(byDistance);
    similar.sort(byDistance);
    final filtered = [...exact, ...similar];
    final drops = <String, int>{
      ...?parseAudit?.dropReasons,
      if (tradeMismatch > 0) 'client_trade_mismatch': tradeMismatch,
      if (similar.isNotEmpty) 'client_similar_kept': similar.length,
    };
    final coordOk = filtered.where((s) => s.hasCoords).length;
    final radiusM = (radiusKm * 1000).round();
    final audit = (parseAudit ??
            StoreLoadAudit(
              source: 'LIVE',
              category: trade,
              lat: lat,
              lng: lng,
              radiusM: radiusM,
              httpStatus: httpStatus,
              resultCode: '',
              resultMsg: '',
              responseTotalCount: all.length,
              rawItemCount: all.length,
              normalizedCount: all.length,
              afterFilterCount: filtered.length,
              afterCoordCount: coordOk,
              afterDedupeCount: all.length,
              stateCount: filtered.length,
              renderedMarkerCount: 0,
              paginationContract: 'this_page_only',
              dropReasons: const {},
              coincidentCoordGroups: 0,
            ))
        .copyWith(
          source: 'LIVE',
          category: trade,
          lat: lat,
          lng: lng,
          radiusM: radiusM,
          afterFilterCount: filtered.length,
          afterCoordCount: coordOk,
          stateCount: filtered.length,
          dropReasons: drops,
        );
    audit.debugDump();
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    final liveEmpty = filtered.isEmpty;
    return MarketSnapshot(
      status: liveEmpty
          ? MarketDataStatus.liveEmpty
          : MarketDataStatus.live,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: filtered,
      population: null,
      footIndex: null,
      marketTrendPct: null,
      shopCountChangePct: null,
      httpStatus: httpStatus,
      fetchedAt: DateTime.now().toUtc(),
      competitionMeta: IndicatorMeta(
        source: source,
        periodLabel: '원문 기준일 미확인',
        updatedOn: today,
        geoUnit: '선택 위치 ${radiusKm.toStringAsFixed(0)}km 반경 기준',
        available: filtered.isNotEmpty,
        nextAction: liveEmpty ? '업종이나 반경을 바꿔 다시 조회하세요.' : null,
        comparisonWarning:
            '공공 상가업소 데이터를 바탕으로 표시됩니다. 업소의 영업 상태·업종·주소·좌표는 실제 현황과 다를 수 있습니다. 개별 업체의 매출이나 예약 가능 여부는 제공하지 않습니다.',
      ),
      populationMeta: const IndicatorMeta(
        source: '행정안전부 주민등록 인구',
        periodLabel: '기준연도 정보를 확인하지 못했습니다',
        updatedOn: '',
        geoUnit: '행정동 집계 · 반경 원과 합산하지 않음',
        available: false,
        nextAction: '선택 위치의 행정동 인구 기준을 확인하지 못했어요.',
        comparisonWarning:
            '행안부·SGIS 상세 요청 계약이 없어 지금 LIVE 연결하지 않습니다. 반경 3km 인구로 합산하지 않습니다.',
      ),
      footMeta: const IndicatorMeta(
        source: '유동 지수',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
        nextAction: '이 공공 API는 유동 지수를 제공하지 않습니다.',
      ),
      trendMeta: const IndicatorMeta(
        source: '국세청 사업자현황_100대 생활업종',
        periodLabel: '매출 20분위 원자료 없음',
        updatedOn: '',
        geoUnit: '시군구 가동사업자 수 · 반경 원과 합산하지 않음',
        available: false,
        nextAction: '선택 업종의 공식 지역 매출 비교 기준을 확인하지 못했어요.',
        comparisonWarning:
            '매출 분위는 제공하지 않습니다. 시군구 가동사업자 수 파일은 자동변환 API 명세 확인 전에 연결하지 않습니다. 개별 상호 매출이 아니며 반경 경쟁과 합산하지 않습니다.',
      ),
      addressLabel: addressLabel,
      cacheKey: cacheKey,
    );
  }

  MarketSnapshot _unavailable({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    required String addressLabel,
    required String errorCode,
    int? httpStatus,
    String? userMessage,
  }) {
    return MarketSnapshot(
      status: MarketDataStatus.unavailable,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: const [],
      errorCode: errorCode,
      httpStatus: httpStatus,
      userMessage: userMessage,
      fetchedAt: DateTime.now().toUtc(),
      competitionMeta: IndicatorMeta(
        source: '소상공인시장진흥공단 상가(상권)정보',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '반경 ${radiusKm.toStringAsFixed(0)}km',
        available: false,
        nextAction: '다시 시도하거나 위치·반경을 바꿔 보세요. 오류 $errorCode',
      ),
      populationMeta: const IndicatorMeta(
        source: '행정안전부 주민등록 인구',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '행정동 집계 · 반경 원과 합산하지 않음',
        available: false,
        nextAction: '선택 위치의 행정동 인구 기준을 확인하지 못했어요.',
      ),
      footMeta: const IndicatorMeta(
        source: '유동 지수',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      trendMeta: const IndicatorMeta(
        source: '국세청 사업자현황_100대 생활업종',
        periodLabel: '매출 20분위 원자료 없음',
        updatedOn: '',
        geoUnit: '시군구 가동사업자 수 · 반경 원과 합산하지 않음',
        available: false,
        nextAction: '선택 업종의 공식 지역 매출 비교 기준을 확인하지 못했어요.',
      ),
      addressLabel: addressLabel,
    );
  }
}

/// 호환 별칭. 자동 Demo 전환 없음.
class LiveMarketProvider extends PublicMarketProvider {
  LiveMarketProvider({required super.shop, super.readCache, super.client});
}

class FallbackMarketProvider extends PublicMarketProvider {
  FallbackMarketProvider({Shop? shop, super.readCache, super.client})
      : super(shop: shop ?? const Shop(id: '', name: '', naverPlaceUrl: ''));
}
