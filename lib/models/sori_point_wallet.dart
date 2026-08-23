import '../utils/db_map.dart';

/// SORI 포인트 지갑 (free / paid 분리).
class SoriPointWallet {
  const SoriPointWallet({
    required this.id,
    required this.shopId,
    this.freeBalance = 0,
    this.paidBalance = 0,
    this.ownerUserId,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String? ownerUserId;
  final int freeBalance;
  final int paidBalance;
  final DateTime? updatedAt;

  int get totalBalance => freeBalance + paidBalance;

  factory SoriPointWallet.fromMap(Map<String, dynamic> map) {
    return SoriPointWallet(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      ownerUserId: DbMap.asTextOrNull(
        map['owner_user_id'] ?? map['ownerUserId'],
      ),
      freeBalance: DbMap.asInt(map['free_balance'] ?? map['freeBalance']),
      paidBalance: DbMap.asInt(map['paid_balance'] ?? map['paidBalance']),
      updatedAt: DbMap.asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static const empty = SoriPointWallet(id: '', shopId: '');
}

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.shopId,
    required this.amount,
    required this.bucket,
    required this.kind,
    this.note = '',
    this.createdAt,
    this.balanceFreeAfter = 0,
    this.balancePaidAfter = 0,
  });

  final String id;
  final String shopId;
  final int amount;
  final String bucket;
  final String kind;
  final String note;
  final DateTime? createdAt;
  final int balanceFreeAfter;
  final int balancePaidAfter;

  factory PointTransaction.fromMap(Map<String, dynamic> map) {
    return PointTransaction(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      amount: DbMap.asInt(map['amount']),
      bucket: DbMap.asText(map['bucket'], 'free'),
      kind: DbMap.asText(map['kind']),
      note: DbMap.asText(map['note']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      balanceFreeAfter: DbMap.asInt(
        map['balance_free_after'] ?? map['balanceFreeAfter'],
      ),
      balancePaidAfter: DbMap.asInt(
        map['balance_paid_after'] ?? map['balancePaidAfter'],
      ),
    );
  }
}

/// 잠금 해제 결과.
class PostUnlockResult {
  const PostUnlockResult({
    required this.ok,
    this.alreadyUnlocked = false,
    this.pointsSpent = 0,
    this.creatorShare = 0,
    this.post,
  });

  final bool ok;
  final bool alreadyUnlocked;
  final int pointsSpent;
  final int creatorShare;
  final Map<String, dynamic>? post;

  factory PostUnlockResult.fromMap(Map<String, dynamic> map) {
    final postRaw = map['post'];
    return PostUnlockResult(
      ok: map['ok'] == true,
      alreadyUnlocked: map['already_unlocked'] == true,
      pointsSpent: DbMap.asInt(map['points_spent'] ?? map['pointsSpent']),
      creatorShare: DbMap.asInt(map['creator_share'] ?? map['creatorShare']),
      post: postRaw is Map
          ? Map<String, dynamic>.from(postRaw)
          : null,
    );
  }
}

/// 충전 패키지 (IAP 브릿지용 SKU).
class PointPack {
  const PointPack({
    required this.sku,
    required this.points,
    required this.priceLabel,
    this.badge = '',
  });

  final String sku;
  final int points;
  final String priceLabel;
  final String badge;

  static const catalog = <PointPack>[
    PointPack(sku: 'sori_p_500', points: 500, priceLabel: '₩5,500'),
    PointPack(
      sku: 'sori_p_1200',
      points: 1200,
      priceLabel: '₩11,000',
      badge: '인기',
    ),
    PointPack(
      sku: 'sori_p_3000',
      points: 3000,
      priceLabel: '₩22,000',
      badge: '20% 보너스',
    ),
  ];
}
