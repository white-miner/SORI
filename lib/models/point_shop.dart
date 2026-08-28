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

  /// 오프라인/메모리 시드 (075 Split & Micro).
  static const catalogBump = PointShopItem(
    id: 'item-boost-bump',
    sku: 'boost_bump_4h',
    title: '피드 끌어올리기 · 4시간',
    description: '카테고리 피드 상단 재정렬',
    pricePoints: 5,
    durationHours: 4,
    badge: '추천',
  );

  static const catalogSpotlight12h = PointShopItem(
    id: 'item-boost-spot-12h',
    sku: 'boost_spotlight_12h',
    title: '스포트라이트 · 12시간',
    description: 'Home+커뮤니티 인터리브 슬롯',
    pricePoints: 9,
    durationHours: 12,
  );

  static const catalogBoosters = <PointShopItem>[
    catalogBump,
    catalogSpotlight12h,
    PointShopItem(
      id: 'item-boost-spot-24h',
      sku: 'boost_spotlight_24h',
      title: '스포트라이트 · 24시간',
      description: 'Home+커뮤니티 인터리브 슬롯 24시간',
      pricePoints: 15,
      durationHours: 24,
      badge: '인기',
    ),
    PointShopItem(
      id: 'item-boost-spot-7d',
      sku: 'boost_spotlight_7d',
      title: '스포트라이트 · 7일',
      description: 'Home+커뮤니티 인터리브 슬롯 7일',
      pricePoints: 59,
      durationHours: 168,
    ),
  ];

  static const catalogSpecialGold = PointShopItem(
    id: 'item-special-gold',
    sku: 'boost_special_gold_24h',
    title: '스페셜 후원 · 골드 24시간',
    description: '기존 부스트 위 골드 오로라 · 피드 가중치',
    category: 'supporter_gift',
    pricePoints: 39,
    durationHours: 24,
    badge: '골드',
  );

  static const catalogSpecialPlatinum = PointShopItem(
    id: 'item-special-platinum',
    sku: 'boost_special_platinum_7d',
    title: '스페셜 후원 · 플래티넘 7일',
    description: '마이페이지 히어로 + 플래티넘 오로라',
    category: 'supporter_gift',
    pricePoints: 149,
    durationHours: 168,
    badge: '플래티넘',
  );

  static const catalogSpecialGifts = <PointShopItem>[
    catalogSpecialGold,
    catalogSpecialPlatinum,
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
    this.source = 'shop_ad',
    this.paidByCustomerId,
    this.paidByWalletId,
    this.fanDisplayName = '',
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

  /// shop_ad | fan_boost
  final String source;
  final String? paidByCustomerId;
  final String? paidByWalletId;
  final String fanDisplayName;

  bool get isFanBoost => source == 'fan_boost';

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
      source: DbMap.asText(map['source'], 'shop_ad'),
      paidByCustomerId: DbMap.asTextOrNull(
        map['paid_by_customer_id'] ?? map['paidByCustomerId'],
      ),
      paidByWalletId: DbMap.asTextOrNull(
        map['paid_by_wallet_id'] ?? map['paidByWalletId'],
      ),
      fanDisplayName: DbMap.asText(
        map['fan_display_name'] ?? map['fanDisplayName'],
      ),
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
    this.raw,
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

  /// Full RPC payload (ai_fill, fan_gift, etc.).
  final Map<String, dynamic>? raw;

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
      raw: map,
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
