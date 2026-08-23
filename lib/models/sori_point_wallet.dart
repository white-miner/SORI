import '../utils/db_map.dart';

/// 이원화 지갑 — Echo(E, 출금불가, 1E=₩100) + 정산금(₩, 출금가능).
class SoriPointWallet {
  const SoriPointWallet({
    required this.id,
    required this.shopId,
    this.freeBalance = 0,
    this.paidBalance = 0,
    this.settlementBalance = 0,
    this.settlementPending = 0,
    this.settlementPaidLifetime = 0,
    this.ownerUserId,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String? ownerUserId;

  /// Free Echo (활동, 출금 불가).
  final int freeBalance;

  /// Paid Echo (IAP, 출금 불가).
  final int paidBalance;

  /// 출금 가능 정산금 (KRW).
  final int settlementBalance;
  final int settlementPending;
  final int settlementPaidLifetime;
  final DateTime? updatedAt;

  /// Echo 합계만 (정산금 제외 — 총자산 합산 금지).
  int get pointTotal => freeBalance + paidBalance;

  /// 페그: 1 Echo = ₩100.
  static const int krwPerEcho = 100;

  int get echoKrwValue => pointTotal * krwPerEcho;

  @Deprecated('Use pointTotal — never sum with settlement')
  int get totalBalance => pointTotal;

  factory SoriPointWallet.fromMap(Map<String, dynamic> map) {
    return SoriPointWallet(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      ownerUserId: DbMap.asTextOrNull(
        map['owner_user_id'] ?? map['ownerUserId'],
      ),
      freeBalance: DbMap.asInt(
        map['point_free_balance'] ??
            map['pointFreeBalance'] ??
            map['free_balance'] ??
            map['freeBalance'],
      ),
      paidBalance: DbMap.asInt(
        map['point_paid_balance'] ??
            map['pointPaidBalance'] ??
            map['paid_balance'] ??
            map['paidBalance'],
      ),
      settlementBalance: DbMap.asInt(
        map['settlement_balance'] ?? map['settlementBalance'],
      ),
      settlementPending: DbMap.asInt(
        map['settlement_pending'] ?? map['settlementPending'],
      ),
      settlementPaidLifetime: DbMap.asInt(
        map['settlement_paid_lifetime'] ?? map['settlementPaidLifetime'],
      ),
      updatedAt: DbMap.asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  SoriPointWallet copyWith({
    int? freeBalance,
    int? paidBalance,
    int? settlementBalance,
    int? settlementPending,
    int? settlementPaidLifetime,
  }) {
    return SoriPointWallet(
      id: id,
      shopId: shopId,
      ownerUserId: ownerUserId,
      freeBalance: freeBalance ?? this.freeBalance,
      paidBalance: paidBalance ?? this.paidBalance,
      settlementBalance: settlementBalance ?? this.settlementBalance,
      settlementPending: settlementPending ?? this.settlementPending,
      settlementPaidLifetime:
          settlementPaidLifetime ?? this.settlementPaidLifetime,
      updatedAt: updatedAt,
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
        map['balance_point_free_after'] ??
            map['balance_free_after'] ??
            map['balanceFreeAfter'],
      ),
      balancePaidAfter: DbMap.asInt(
        map['balance_point_paid_after'] ??
            map['balance_paid_after'] ??
            map['balancePaidAfter'],
      ),
    );
  }
}

class SettlementTransaction {
  const SettlementTransaction({
    required this.id,
    required this.shopId,
    required this.amount,
    required this.kind,
    this.status = 'posted',
    this.note = '',
    this.balanceAfter = 0,
    this.bankAccountMask = '',
    this.createdAt,
  });

  final String id;
  final String shopId;
  final int amount;
  final String kind;
  final String status;
  final String note;
  final int balanceAfter;
  final String bankAccountMask;
  final DateTime? createdAt;

  factory SettlementTransaction.fromMap(Map<String, dynamic> map) {
    return SettlementTransaction(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      amount: DbMap.asInt(map['amount']),
      kind: DbMap.asText(map['kind']),
      status: DbMap.asText(map['status'], 'posted'),
      note: DbMap.asText(map['note']),
      balanceAfter: DbMap.asInt(
        map['balance_after'] ?? map['balanceAfter'],
      ),
      bankAccountMask: DbMap.asText(
        map['bank_account_mask'] ?? map['bankAccountMask'],
      ),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
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
    this.creatorCurrency = 'point',
    this.post,
  });

  final bool ok;
  final bool alreadyUnlocked;
  final int pointsSpent;
  final int creatorShare;
  final String creatorCurrency;
  final Map<String, dynamic>? post;

  factory PostUnlockResult.fromMap(Map<String, dynamic> map) {
    final postRaw = map['post'];
    return PostUnlockResult(
      ok: map['ok'] == true,
      alreadyUnlocked: map['already_unlocked'] == true,
      pointsSpent: DbMap.asInt(map['points_spent'] ?? map['pointsSpent']),
      creatorShare: DbMap.asInt(map['creator_share'] ?? map['creatorShare']),
      creatorCurrency: DbMap.asText(
        map['creator_currency'] ?? map['creatorCurrency'],
        'point',
      ),
      post: postRaw is Map
          ? Map<String, dynamic>.from(postRaw)
          : null,
    );
  }
}

/// 충전 패키지 (IAP) — Echo, 1E = ₩100 페그.
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

  /// Echo 표기 별칭.
  int get echo => points;

  static const catalog = <PointPack>[
    PointPack(sku: 'sori_e_55', points: 55, priceLabel: '₩5,500'),
    PointPack(
      sku: 'sori_e_120',
      points: 120,
      priceLabel: '₩11,000',
      badge: '인기',
    ),
    PointPack(
      sku: 'sori_e_330',
      points: 330,
      priceLabel: '₩27,500',
      badge: '헤비',
    ),
  ];
}
