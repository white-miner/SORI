import '../utils/db_map.dart';

/// 포인트 상점 상품 마스터.
class PointShopItem {
  const PointShopItem({
    required this.id,
    required this.sku,
    required this.title,
    this.description = '',
    this.category = 'booster',
    required this.pricePoints,
    this.durationHours = 0,
    this.badge = '',
    this.isActive = true,
  });

  final String id;
  final String sku;
  final String title;
  final String description;
  final String category;
  final int pricePoints;
  final int durationHours;
  final String badge;
  final bool isActive;

  bool get isBooster => category == 'booster';

  factory PointShopItem.fromMap(Map<String, dynamic> map) {
    final meta = map['metadata'];
    var badge = '';
    if (meta is Map) {
      badge = DbMap.asText(meta['badge']);
    }
    return PointShopItem(
      id: DbMap.asText(map['id']),
      sku: DbMap.asText(map['sku']),
      title: DbMap.asText(map['title']),
      description: DbMap.asText(map['description']),
      category: DbMap.asText(map['category'], 'booster'),
      pricePoints: DbMap.asInt(map['price_points'] ?? map['pricePoints']),
      durationHours: DbMap.asInt(
        map['duration_hours'] ?? map['durationHours'],
      ),
      badge: badge,
      isActive: map['is_active'] != false && map['isActive'] != false,
    );
  }

  /// 오프라인/메모리 시드 (055와 동일 가격).
  static const catalogBoosters = <PointShopItem>[
    PointShopItem(
      id: 'item-boost-2h',
      sku: 'boost_local_2h',
      title: '우리 지역 노출 부스터 · 2시간',
      description: 'Home 「우리 지역」탭 최상단 고정 노출 (AD)',
      pricePoints: 300,
      durationHours: 2,
    ),
    PointShopItem(
      id: 'item-boost-1d',
      sku: 'boost_local_1d',
      title: '우리 지역 노출 부스터 · 1일',
      description: 'Home 「우리 지역」탭 최상단 고정 노출 24시간',
      pricePoints: 900,
      durationHours: 24,
      badge: '인기',
    ),
    PointShopItem(
      id: 'item-boost-7d',
      sku: 'boost_local_7d',
      title: '우리 지역 노출 부스터 · 7일',
      description: 'Home 「우리 지역」탭 최상단 고정 노출 7일',
      pricePoints: 4500,
      durationHours: 168,
    ),
  ];
}

class BoostPlacement {
  const BoostPlacement({
    required this.id,
    required this.shopId,
    required this.targetType,
    required this.targetId,
    this.itemSku = '',
    this.postId,
    this.chartId,
    this.regionCode = '',
    this.startsAt,
    this.endsAt,
    this.status = 'active',
    this.pointsSpent = 0,
  });

  final String id;
  final String shopId;
  final String targetType;
  final String targetId;
  final String itemSku;
  final String? postId;
  final String? chartId;
  final String regionCode;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final int pointsSpent;

  bool get isActive {
    if (status != 'active') return false;
    final end = endsAt;
    if (end == null) return true;
    return end.isAfter(DateTime.now());
  }

  String? get pinKey {
    if (chartId != null && chartId!.trim().isNotEmpty) return chartId;
    if (targetType == 'chart') return targetId;
    return postId ?? (targetType == 'community_post' ? targetId : null);
  }

  factory BoostPlacement.fromMap(Map<String, dynamic> map) {
    return BoostPlacement(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      targetType: DbMap.asText(map['target_type'] ?? map['targetType'], 'chart'),
      targetId: DbMap.asText(map['target_id'] ?? map['targetId']),
      itemSku: DbMap.asText(map['item_sku'] ?? map['itemSku']),
      postId: DbMap.asTextOrNull(map['post_id'] ?? map['postId']),
      chartId: DbMap.asTextOrNull(map['chart_id'] ?? map['chartId']),
      regionCode: DbMap.asText(map['region_code'] ?? map['regionCode']),
      startsAt: DbMap.asDateTime(map['starts_at'] ?? map['startsAt']),
      endsAt: DbMap.asDateTime(map['ends_at'] ?? map['endsAt']),
      status: DbMap.asText(map['status'], 'active'),
      pointsSpent: DbMap.asInt(map['points_spent'] ?? map['pointsSpent']),
    );
  }
}

class BoostPurchaseResult {
  const BoostPurchaseResult({
    required this.ok,
    this.sku = '',
    this.pointsSpent = 0,
    this.pointFreeBalance = 0,
    this.pointPaidBalance = 0,
    this.settlementBalance = 0,
    this.placement,
    this.insufficient = false,
    this.have = 0,
    this.need = 0,
    this.message = '',
  });

  final bool ok;
  final String sku;
  final int pointsSpent;
  final int pointFreeBalance;
  final int pointPaidBalance;
  final int settlementBalance;
  final BoostPlacement? placement;
  final bool insufficient;
  final int have;
  final int need;
  final String message;

  int get gap => (need - have).clamp(0, 1 << 30);

  factory BoostPurchaseResult.fromMap(Map<String, dynamic> map) {
    final placementRaw = map['placement'];
    return BoostPurchaseResult(
      ok: map['ok'] == true,
      sku: DbMap.asText(map['sku']),
      pointsSpent: DbMap.asInt(map['points_spent'] ?? map['pointsSpent']),
      pointFreeBalance: DbMap.asInt(
        map['point_free_balance'] ?? map['pointFreeBalance'],
      ),
      pointPaidBalance: DbMap.asInt(
        map['point_paid_balance'] ?? map['pointPaidBalance'],
      ),
      settlementBalance: DbMap.asInt(
        map['settlement_balance'] ?? map['settlementBalance'],
      ),
      placement: placementRaw is Map
          ? BoostPlacement.fromMap(Map<String, dynamic>.from(placementRaw))
          : null,
    );
  }

  static BoostPurchaseResult insufficientPoints({
    required int have,
    required int need,
  }) {
    return BoostPurchaseResult(
      ok: false,
      insufficient: true,
      have: have,
      need: need,
      message: 'insufficient points: have $have, need $need',
    );
  }
}
