import '../utils/db_map.dart';
import '../utils/sori_uuid.dart';
import 'customer_membership.dart';

/// PRD v7.1 — 내부 역할. 고객 화면에는 쓰지 않는다.
enum ProgramPackageTier {
  anchor,
  target,
  decoy;

  String get dbValue => name;

  static ProgramPackageTier fromDb(String? raw) {
    return ProgramPackageTier.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramPackageTier.target,
    );
  }
}

enum ProgramLineKind {
  step,
  device,
  ampoule,
  perk;

  String get dbValue => name;

  static ProgramLineKind fromDb(String? raw) {
    return ProgramLineKind.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramLineKind.perk,
    );
  }

  /// 원장 화면 전용. dbValue 를 그대로 노출하지 않는다.
  String get labelKo => switch (this) {
        ProgramLineKind.step => '관리 내용',
        ProgramLineKind.device => '사용 기기',
        ProgramLineKind.ampoule => '제품·앰플',
        ProgramLineKind.perk => '추가 혜택',
      };
}

enum ProgramPromoKind {
  extraSession,
  gift,
  instantDiscount,
  percentDiscount,
  nextVisitCredit;

  String get dbValue => switch (this) {
        ProgramPromoKind.extraSession => 'extra_session',
        ProgramPromoKind.gift => 'gift',
        ProgramPromoKind.instantDiscount => 'instant_discount',
        ProgramPromoKind.percentDiscount => 'percent_discount',
        ProgramPromoKind.nextVisitCredit => 'next_visit_credit',
      };

  static ProgramPromoKind fromDb(String? raw) {
    return switch (raw) {
      'extra_session' => ProgramPromoKind.extraSession,
      'gift' => ProgramPromoKind.gift,
      'instant_discount' => ProgramPromoKind.instantDiscount,
      'percent_discount' => ProgramPromoKind.percentDiscount,
      'next_visit_credit' => ProgramPromoKind.nextVisitCredit,
      _ => ProgramPromoKind.gift,
    };
  }

  /// 원장 화면에만 쓴다. dbValue 를 그대로 노출하지 않는다.
  String get labelKo => switch (this) {
        ProgramPromoKind.extraSession => '횟수 추가',
        ProgramPromoKind.gift => '사은품 증정',
        ProgramPromoKind.instantDiscount => '즉시 할인',
        ProgramPromoKind.percentDiscount => '퍼센트 할인',
        ProgramPromoKind.nextVisitCredit => '다음 방문 크레딧',
      };

  /// 미래가치 — 오늘의 회원권이 아니라 고객 쿠폰으로 떨어진다.
  bool get isFutureCredit => this == ProgramPromoKind.nextVisitCredit;
}

/// 수기 결제 상태. SORI 에 PG 는 없다 (Q3(a) — 막지 않고 보이게 한다).
enum ProgramPaymentStatus {
  unpaid,
  partial,
  paid,
  refunded;

  String get dbValue => name;

  static ProgramPaymentStatus fromDb(String? raw) {
    return ProgramPaymentStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramPaymentStatus.unpaid,
    );
  }

  String get labelKo => switch (this) {
        ProgramPaymentStatus.unpaid => '미결제',
        ProgramPaymentStatus.partial => '일부 결제',
        ProgramPaymentStatus.paid => '결제 완료',
        ProgramPaymentStatus.refunded => '환불',
      };

  bool get isSettled => this == ProgramPaymentStatus.paid;
}

enum ProgramPaymentMethod {
  cash,
  card,
  transfer,
  etc;

  String get dbValue => name;

  static ProgramPaymentMethod fromDb(String? raw) {
    return ProgramPaymentMethod.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramPaymentMethod.cash,
    );
  }

  String get labelKo => switch (this) {
        ProgramPaymentMethod.cash => '현금',
        ProgramPaymentMethod.card => '카드',
        ProgramPaymentMethod.transfer => '이체',
        ProgramPaymentMethod.etc => '기타',
      };
}

enum ProgramCouponStatus {
  issued,
  used,
  expired,
  voided;

  /// DB 는 'void' 를 쓴다. Dart 예약어라 enum 이름만 voided 로 둔다.
  String get dbValue =>
      this == ProgramCouponStatus.voided ? 'void' : name;

  static ProgramCouponStatus fromDb(String? raw) {
    return switch (raw) {
      'used' => ProgramCouponStatus.used,
      'expired' => ProgramCouponStatus.expired,
      'void' => ProgramCouponStatus.voided,
      _ => ProgramCouponStatus.issued,
    };
  }

  String get labelKo => switch (this) {
        ProgramCouponStatus.issued => '미사용',
        ProgramCouponStatus.used => '사용 완료',
        ProgramCouponStatus.expired => '기한 만료',
        ProgramCouponStatus.voided => '무효',
      };
}

enum ProgramQuoteStatus {
  draft,
  presented,
  accepted,
  abandoned;

  String get dbValue => name;

  static ProgramQuoteStatus fromDb(String? raw) {
    return ProgramQuoteStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramQuoteStatus.draft,
    );
  }
}

/// 세일즈 산수 SSOT — SQL `::int` 와 같이 양수는 0 쪽으로 자른다.
abstract final class ProgramPricing {
  static int unitPrice(int listPriceKrw, int visitCount) {
    if (visitCount <= 0) return 0;
    return listPriceKrw ~/ visitCount;
  }

  static int benefitValue(Iterable<ProgramPromotion> promos) =>
      promos.fold<int>(0, (sum, p) => sum + p.valueKrw);

  /// Q4(a) — 정액 할인 합계를 먼저 빼고, 남은 금액에 퍼센트를 적용한다.
  /// 순서를 뒤집으면 9장까지 겹치는 스택에서 결제액이 0으로 수렴한다.
  static int payable(int listPriceKrw, Iterable<ProgramPromotion> promos) {
    final flat = promos.fold<int>(0, (sum, p) => sum + p.discountKrw);
    var next = listPriceKrw - flat;
    if (next <= 0) return 0;

    final percent = percentOffTotal(promos);
    if (percent <= 0) return next;
    next = (next * (100 - percent) / 100).floor();
    return next < 0 ? 0 : next;
  }

  /// 퍼센트 할인은 합산 후 100 에서 자른다. 100 을 넘겨 음수 결제액을 만들지 않는다.
  static double percentOffTotal(Iterable<ProgramPromotion> promos) {
    final sum = promos.fold<double>(0, (acc, p) => acc + p.percentOff);
    if (sum <= 0) return 0;
    return sum > 100 ? 100 : sum;
  }

  /// 회원권 횟수는 '오늘의 혜택'만 더한다. 다음 방문 크레딧은 쿠폰으로 분기한다.
  static int membershipVisits(
    int packageVisits,
    Iterable<ProgramPromotion> promos,
  ) =>
      packageVisits +
      promos
          .where((p) => !p.kind.isFutureCredit)
          .fold<int>(0, (sum, p) => sum + p.extraVisits);

  /// 수락 시 고객 쿠폰으로 떨어질 혜택만 추린다 (S7).
  static List<ProgramPromotion> futureCredits(
    Iterable<ProgramPromotion> promos,
  ) =>
      promos.where((p) => p.kind.isFutureCredit).toList();

  /// 견적에 붙은 프로모션 id 목록을 카탈로그 행으로 펼친다. 같은 id가 두 번이면 두 장.
  static List<ProgramPromotion> stacked(
    Iterable<String> promotionIds,
    Iterable<ProgramPromotion> catalog,
  ) {
    final byId = {for (final p in catalog) p.id: p};
    return [
      for (final id in promotionIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 3,000,000 — 앵커 숫자의 시선 단위.
  static String formatKrw(int amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().toString();
    final buf = StringBuffer(sign);
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static String packageUnitLine(int unitPriceKrw, int visitCount) =>
      '$visitCount회 시 1회 ${formatKrw(unitPriceKrw)}원';

  static String? walkInLine(int walkInPriceKrw) {
    if (walkInPriceKrw <= 0) return null;
    return '단품 1회 ${formatKrw(walkInPriceKrw)}원';
  }

  static bool unitBeatsWalkIn(int unitPriceKrw, int walkInPriceKrw) =>
      walkInPriceKrw > 0 && unitPriceKrw < walkInPriceKrw;

  /// numeric(5,2) 는 드라이버에 따라 num / String 으로 온다. 0~100 으로 자른다.
  static double asPercent(dynamic raw) {
    if (raw == null) return 0;
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    if (value <= 0) return 0;
    return value > 100 ? 100 : value;
  }
}

/// 견적 프로모션 스택. 같은 카탈로그 혜택을 여러 장 붙일 수 있다.
abstract final class ProgramPromoStack {
  static const maxQtyPerPromo = 9;

  static Map<String, int> qtyById(Iterable<String> ids) {
    final out = <String, int>{};
    for (final id in ids) {
      final n = id.trim();
      if (n.isEmpty) continue;
      out[n] = (out[n] ?? 0) + 1;
    }
    return out;
  }

  static List<String> uniqueInOrder(Iterable<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      final n = id.trim();
      if (n.isEmpty || !seen.add(n)) continue;
      out.add(n);
    }
    return out;
  }

  static List<String> expand(
    Map<String, int> qty, {
    Iterable<String>? order,
  }) {
    final keys = [
      ...uniqueInOrder(order ?? const <String>[]),
    ];
    for (final id in qty.keys) {
      if (!keys.contains(id)) keys.add(id);
    }
    return [
      for (final id in keys)
        for (var i = 0; i < (qty[id] ?? 0).clamp(0, maxQtyPerPromo); i++) id,
    ];
  }

  static List<String> clamp(Iterable<String> ids) {
    final qty = qtyById(ids);
    for (final id in qty.keys.toList()) {
      final n = qty[id] ?? 0;
      if (n > maxQtyPerPromo) qty[id] = maxQtyPerPromo;
      if (n <= 0) qty.remove(id);
    }
    return expand(qty, order: ids);
  }

  static List<Map<String, dynamic>> junctionRows({
    required String quoteId,
    required List<String> promotionIds,
    required bool includeQty,
  }) {
    final qty = qtyById(promotionIds);
    final order = uniqueInOrder(promotionIds);
    var sort = 0;
    return [
      for (final id in order)
        {
          'quote_id': quoteId,
          'promotion_id': id,
          'sort_order': sort++,
          if (includeQty) 'qty': qty[id] ?? 1,
        },
    ];
  }
}

/// 패키지 뱃지 색. Timer Green · 신규 Violet · 세일 Red 는 팔레트에 넣지 않는다.
abstract final class ProgramAccent {
  static const charcoal = '1C1C1E';
  static const swatches = <String>[
    '1C1C1E',
    '3A3A3C',
    '5C6B73',
    '8B7355',
    '9A6B4F',
    '6B4F5B',
    '3D4F5F',
    '4A5C4E',
  ];

  static String normalize(String? raw) {
    final hex = (raw ?? '').replaceAll('#', '').trim().toUpperCase();
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(hex)) {
      if (hex == '34C759' || hex == '8B5CF6' || hex == 'FF3B30') {
        return charcoal;
      }
      return hex;
    }
    return charcoal;
  }

  static int argbOf(String? raw) {
    final hex = normalize(raw);
    return int.parse('FF$hex', radix: 16);
  }
}

class ProgramCategory {
  const ProgramCategory({
    required this.id,
    required this.shopId,
    required this.name,
    this.subtitle = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String subtitle;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProgramCategory copyWith({
    String? id,
    String? name,
    String? subtitle,
    int? sortOrder,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return ProgramCategory(
      id: id ?? this.id,
      shopId: shopId,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'name': name,
        'subtitle': subtitle,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  factory ProgramCategory.fromMap(Map<String, dynamic> map) {
    return ProgramCategory(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      name: DbMap.asText(map['name']),
      subtitle: DbMap.asText(map['subtitle']),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
      isActive: DbMap.asBool(map['is_active'] ?? map['isActive'], true),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: DbMap.asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class ProgramPackageLine {
  const ProgramPackageLine({
    required this.id,
    required this.packageId,
    required this.kind,
    required this.label,
    this.minutes,
    this.shopMenuId,
    this.sortOrder = 0,
  });

  final String id;
  final String packageId;
  final ProgramLineKind kind;
  final String label;
  final int? minutes;
  final String? shopMenuId;
  final int sortOrder;

  ProgramPackageLine copyWith({
    String? id,
    String? packageId,
    ProgramLineKind? kind,
    String? label,
    int? minutes,
    String? shopMenuId,
    int? sortOrder,
    bool clearMinutes = false,
  }) {
    return ProgramPackageLine(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      minutes: clearMinutes ? null : (minutes ?? this.minutes),
      shopMenuId: shopMenuId ?? this.shopMenuId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'package_id': packageId,
        'kind': kind.dbValue,
        'label': label,
        'minutes': minutes,
        'shop_menu_id': DbMap.nullIfBlank(shopMenuId),
        'sort_order': sortOrder,
      };

  factory ProgramPackageLine.fromMap(Map<String, dynamic> map) {
    final mins = map['minutes'];
    return ProgramPackageLine(
      id: DbMap.asText(map['id']),
      packageId: DbMap.asText(map['package_id'] ?? map['packageId']),
      kind: ProgramLineKind.fromDb(DbMap.asTextOrNull(map['kind'])),
      label: DbMap.asText(map['label']),
      minutes: mins == null ? null : DbMap.asInt(mins),
      shopMenuId: DbMap.asTextOrNull(map['shop_menu_id'] ?? map['shopMenuId']),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
    );
  }
}

class ProgramPackage {
  const ProgramPackage({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.name,
    required this.visitCount,
    required this.listPriceKrw,
    this.tier = ProgramPackageTier.target,
    this.isActive = true,
    this.sortOrder = 0,
    this.lines = const [],
    this.accentHex = ProgramAccent.charcoal,
    this.walkInPriceKrw = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String categoryId;
  final String name;
  final int visitCount;
  final int listPriceKrw;
  final ProgramPackageTier tier;
  final bool isActive;
  final int sortOrder;
  final List<ProgramPackageLine> lines;
  final String accentHex;
  final int walkInPriceKrw;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get unitPriceKrw =>
      ProgramPricing.unitPrice(listPriceKrw, visitCount);

  int get stepMinutes => lines
      .where((l) => l.kind == ProgramLineKind.step)
      .fold<int>(0, (sum, l) => sum + (l.minutes ?? 0));

  ProgramPackage copyWith({
    String? id,
    String? categoryId,
    String? name,
    int? visitCount,
    int? listPriceKrw,
    ProgramPackageTier? tier,
    bool? isActive,
    int? sortOrder,
    List<ProgramPackageLine>? lines,
    String? accentHex,
    int? walkInPriceKrw,
    DateTime? updatedAt,
  }) {
    return ProgramPackage(
      id: id ?? this.id,
      shopId: shopId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      visitCount: visitCount ?? this.visitCount,
      listPriceKrw: listPriceKrw ?? this.listPriceKrw,
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      lines: lines ?? this.lines,
      accentHex: accentHex ?? this.accentHex,
      walkInPriceKrw: walkInPriceKrw ?? this.walkInPriceKrw,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'category_id': categoryId,
        'name': name,
        'visit_count': visitCount,
        'list_price_krw': listPriceKrw,
        'tier': tier.dbValue,
        'is_active': isActive,
        'sort_order': sortOrder,
        'accent_hex': ProgramAccent.normalize(accentHex),
        'walk_in_price_krw': walkInPriceKrw < 0 ? 0 : walkInPriceKrw,
      };

  factory ProgramPackage.fromMap(
    Map<String, dynamic> map, {
    List<ProgramPackageLine> lines = const [],
  }) {
    return ProgramPackage(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      categoryId: DbMap.asText(map['category_id'] ?? map['categoryId']),
      name: DbMap.asText(map['name']),
      visitCount: DbMap.asInt(map['visit_count'] ?? map['visitCount'], 1)
          .clamp(1, 999),
      listPriceKrw: DbMap.asInt(
        map['list_price_krw'] ?? map['listPriceKrw'],
      ).clamp(0, 999999999),
      tier: ProgramPackageTier.fromDb(DbMap.asTextOrNull(map['tier'])),
      isActive: DbMap.asBool(map['is_active'] ?? map['isActive'], true),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
      lines: lines,
      accentHex: ProgramAccent.normalize(
        DbMap.asTextOrNull(map['accent_hex'] ?? map['accentHex']),
      ),
      walkInPriceKrw: DbMap.asInt(
        map['walk_in_price_krw'] ?? map['walkInPriceKrw'],
      ).clamp(0, 999999999),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: DbMap.asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  ProgramPackageSnapshot toSnapshot({required String categoryName}) {
    return ProgramPackageSnapshot(
      id: id,
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      visitCount: visitCount,
      listPriceKrw: listPriceKrw,
      lines: List<ProgramPackageLine>.from(lines),
      accentHex: accentHex,
      walkInPriceKrw: walkInPriceKrw,
    );
  }

  /// 카테고리 보드의 앵커 — 최고가, 동점이면 sort_order → created_at.
  static ProgramPackage? boardAnchor(Iterable<ProgramPackage> packages) {
    final active = packages.where((p) => p.isActive).toList();
    if (active.isEmpty) return null;
    active.sort(_anchorOrder);
    return active.first;
  }

  static int _anchorOrder(ProgramPackage a, ProgramPackage b) {
    final byPrice = b.listPriceKrw.compareTo(a.listPriceKrw);
    if (byPrice != 0) return byPrice;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return at.compareTo(bt);
  }

  /// Expand 나열: 앵커가 맨 위, 나머지는 sort_order.
  static int expandOrder(
    ProgramPackage a,
    ProgramPackage b, {
    required String? anchorId,
  }) {
    final aAnchor = a.id == anchorId;
    final bAnchor = b.id == anchorId;
    if (aAnchor != bAnchor) return aAnchor ? -1 : 1;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return b.listPriceKrw.compareTo(a.listPriceKrw);
  }
}

/// 비교 화면에 얼린 패키지. 원가가 뒤에서 바뀌어도 이 숫자는 안 움직인다.
class ProgramPackageSnapshot {
  const ProgramPackageSnapshot({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.visitCount,
    required this.listPriceKrw,
    this.lines = const [],
    this.accentHex = ProgramAccent.charcoal,
    this.walkInPriceKrw = 0,
  });

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final int visitCount;
  final int listPriceKrw;
  final List<ProgramPackageLine> lines;
  final String accentHex;
  final int walkInPriceKrw;

  int get unitPriceKrw =>
      ProgramPricing.unitPrice(listPriceKrw, visitCount);

  int get stepMinutes => lines
      .where((l) => l.kind == ProgramLineKind.step)
      .fold<int>(0, (sum, l) => sum + (l.minutes ?? 0));

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'category_name': categoryName,
        'visit_count': visitCount,
        'list_price_krw': listPriceKrw,
        'accent_hex': ProgramAccent.normalize(accentHex),
        'walk_in_price_krw': walkInPriceKrw,
        'lines': lines.map((e) => e.toMap()).toList(),
      };

  factory ProgramPackageSnapshot.fromMap(Map<String, dynamic> map) {
    final rawLines = map['lines'];
    final lines = <ProgramPackageLine>[];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(
            ProgramPackageLine.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ProgramPackageSnapshot(
      id: DbMap.asText(map['id']),
      name: DbMap.asText(map['name']),
      categoryId: DbMap.asText(map['category_id'] ?? map['categoryId']),
      categoryName: DbMap.asText(map['category_name'] ?? map['categoryName']),
      visitCount: DbMap.asInt(map['visit_count'] ?? map['visitCount'], 1),
      listPriceKrw: DbMap.asInt(map['list_price_krw'] ?? map['listPriceKrw']),
      lines: lines,
      accentHex: ProgramAccent.normalize(
        DbMap.asTextOrNull(map['accent_hex'] ?? map['accentHex']),
      ),
      walkInPriceKrw: DbMap.asInt(
        map['walk_in_price_krw'] ?? map['walkInPriceKrw'],
      ),
    );
  }
}

/// 혜택 적용 범위 (112). global 이면 target 은 반드시 비어 있다.
enum ProgramPromoScope {
  global,
  category,
  package;

  String get dbValue => name;

  static ProgramPromoScope fromDb(String? raw) {
    return ProgramPromoScope.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramPromoScope.global,
    );
  }

  String get labelKo => switch (this) {
        ProgramPromoScope.global => '전체',
        ProgramPromoScope.category => '카테고리 전용',
        ProgramPromoScope.package => '패키지 전용',
      };
}

/// R4 — [범위] + [종류] + [값] 조립 문장. 원장 타이핑을 이 한 줄이 대신한다.
abstract final class ProgramPromoComposer {
  static String preview({
    required ProgramPromoScope scope,
    required ProgramPromoKind kind,
    String targetName = '',
    int extraVisits = 1,
    int discountKrw = 0,
    double percentOff = 0,
    int giftQty = 1,
    int valueKrw = 0,
  }) {
    final range = switch (scope) {
      ProgramPromoScope.global => '모든 관리 서비스',
      ProgramPromoScope.category =>
        targetName.trim().isEmpty ? '카테고리' : targetName.trim(),
      ProgramPromoScope.package =>
        targetName.trim().isEmpty ? '패키지' : targetName.trim(),
    };
    final benefit = switch (kind) {
      ProgramPromoKind.percentDiscount =>
        '${_pct(percentOff)}% 할인',
      ProgramPromoKind.instantDiscount =>
        '${ProgramPricing.formatKrw(discountKrw)}원 할인',
      ProgramPromoKind.extraSession => '+${extraVisits < 1 ? 1 : extraVisits}회',
      ProgramPromoKind.gift => giftQty > 0 ? '사은품 ${giftQty}개' : '사은품 증정',
      ProgramPromoKind.nextVisitCredit => percentOff > 0
          ? '다음 구매 ${_pct(percentOff)}% 할인'
          : discountKrw > 0
              ? '다음 구매 ${ProgramPricing.formatKrw(discountKrw)}원 할인'
              : '다음 방문 크레딧',
    };
    return '$range / $benefit';
  }

  static String _pct(double n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);
}

class ProgramPromotion {
  const ProgramPromotion({
    required this.id,
    required this.shopId,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.valueKrw = 0,
    this.extraVisits = 0,
    this.discountKrw = 0,
    this.percentOff = 0,
    this.giftQty = 0,
    this.scope = ProgramPromoScope.global,
    this.targetId,
    this.isActive = true,
    this.sortOrder = 0,
    this.validFrom,
    this.validUntil,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final ProgramPromoKind kind;
  final String title;
  final String subtitle;
  final int valueKrw;
  final int extraVisits;
  final int discountKrw;
  final double percentOff;
  final int giftQty;
  final ProgramPromoScope scope;
  final String? targetId;
  final bool isActive;
  final int sortOrder;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? createdAt;

  /// 이 혜택이 해당 패키지 견적에 붙을 수 있는가 (C6/S2).
  bool appliesTo({required String packageId, required String categoryId}) {
    return switch (scope) {
      ProgramPromoScope.global => true,
      ProgramPromoScope.category => targetId == categoryId,
      ProgramPromoScope.package => targetId == packageId,
    };
  }

  bool isLiveAt(DateTime now) {
    if (!isActive) return false;
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return true;
  }

  ProgramPromotion copyWith({
    String? id,
    ProgramPromoKind? kind,
    String? title,
    String? subtitle,
    int? valueKrw,
    int? extraVisits,
    int? discountKrw,
    double? percentOff,
    int? giftQty,
    ProgramPromoScope? scope,
    String? targetId,
    bool? isActive,
    int? sortOrder,
    DateTime? validFrom,
    DateTime? validUntil,
    bool clearTarget = false,
    bool clearValidFrom = false,
    bool clearValidUntil = false,
  }) {
    return ProgramPromotion(
      id: id ?? this.id,
      shopId: shopId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      valueKrw: valueKrw ?? this.valueKrw,
      extraVisits: extraVisits ?? this.extraVisits,
      discountKrw: discountKrw ?? this.discountKrw,
      percentOff: percentOff ?? this.percentOff,
      giftQty: giftQty ?? this.giftQty,
      scope: scope ?? this.scope,
      targetId: clearTarget ? null : (targetId ?? this.targetId),
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      validFrom: clearValidFrom ? null : (validFrom ?? this.validFrom),
      validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'kind': kind.dbValue,
        'title': title,
        'subtitle': subtitle,
        'value_krw': valueKrw,
        'extra_visits': extraVisits,
        'discount_krw': discountKrw,
        'percent_off': percentOff,
        'gift_qty': giftQty,
        'scope': scope.dbValue,
        'target_id': scope == ProgramPromoScope.global
            ? null
            : DbMap.nullIfBlank(targetId),
        'is_active': isActive,
        'sort_order': sortOrder,
        'valid_from': validFrom?.toUtc().toIso8601String(),
        'valid_until': validUntil?.toUtc().toIso8601String(),
      };

  /// 112 미적용 DB 로 저장할 때 벗겨 낼 키. 스키마 진화 폴백에 쓴다.
  static const v72Columns = <String>[
    'percent_off',
    'gift_qty',
    'scope',
    'target_id',
  ];

  factory ProgramPromotion.fromMap(Map<String, dynamic> map) {
    final scope = ProgramPromoScope.fromDb(DbMap.asTextOrNull(map['scope']));
    final target = DbMap.asTextOrNull(map['target_id'] ?? map['targetId']);
    return ProgramPromotion(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      kind: ProgramPromoKind.fromDb(DbMap.asTextOrNull(map['kind'])),
      title: DbMap.asText(map['title']),
      subtitle: DbMap.asText(map['subtitle']),
      valueKrw: DbMap.asInt(map['value_krw'] ?? map['valueKrw']),
      extraVisits: DbMap.asInt(map['extra_visits'] ?? map['extraVisits']),
      discountKrw: DbMap.asInt(map['discount_krw'] ?? map['discountKrw']),
      percentOff: ProgramPricing.asPercent(
        map['percent_off'] ?? map['percentOff'],
      ),
      giftQty: DbMap.asInt(map['gift_qty'] ?? map['giftQty']),
      scope: scope,
      targetId: scope == ProgramPromoScope.global ? null : target,
      isActive: DbMap.asBool(map['is_active'] ?? map['isActive'], true),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
      validFrom: DbMap.asDateTime(map['valid_from'] ?? map['validFrom']),
      validUntil: DbMap.asDateTime(map['valid_until'] ?? map['validUntil']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

/// S7 — 고객이 들고 가는 미래가치. 회원권(횟수)과 다른 자산이다 (114).
class ProgramCustomerCoupon {
  const ProgramCustomerCoupon({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.title,
    this.issuedQuoteId,
    this.promotionId,
    this.percentOff = 0,
    this.discountKrw = 0,
    this.extraVisits = 0,
    this.giftQty = 0,
    this.status = ProgramCouponStatus.issued,
    this.issuedAt,
    this.expiresAt,
    this.usedAt,
    this.usedQuoteId,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String title;
  final String? issuedQuoteId;
  final String? promotionId;
  final double percentOff;
  final int discountKrw;
  final int extraVisits;
  final int giftQty;
  final ProgramCouponStatus status;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? usedQuoteId;

  bool get isUnused => status == ProgramCouponStatus.issued;

  bool isExpiredAt(DateTime now) =>
      expiresAt != null && now.isAfter(expiresAt!);

  /// 배지·칩 한 줄. "20% 할인" / "+1회" / "사은품 2개".
  String get benefitLine {
    if (percentOff > 0) {
      final p = percentOff == percentOff.roundToDouble()
          ? percentOff.round().toString()
          : percentOff.toStringAsFixed(1);
      return '$p% 할인';
    }
    if (discountKrw > 0) return '${ProgramPricing.formatKrw(discountKrw)}원 할인';
    if (extraVisits > 0) return '+$extraVisits회';
    if (giftQty > 0) return '사은품 $giftQty개';
    return title;
  }

  ProgramCustomerCoupon copyWith({
    String? id,
    ProgramCouponStatus? status,
    DateTime? usedAt,
    String? usedQuoteId,
  }) {
    return ProgramCustomerCoupon(
      id: id ?? this.id,
      shopId: shopId,
      customerId: customerId,
      title: title,
      issuedQuoteId: issuedQuoteId,
      promotionId: promotionId,
      percentOff: percentOff,
      discountKrw: discountKrw,
      extraVisits: extraVisits,
      giftQty: giftQty,
      status: status ?? this.status,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      usedAt: usedAt ?? this.usedAt,
      usedQuoteId: usedQuoteId ?? this.usedQuoteId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'customer_id': customerId,
        'issued_quote_id': DbMap.nullIfBlank(issuedQuoteId),
        'promotion_id': DbMap.nullIfBlank(promotionId),
        'title': title,
        'percent_off': percentOff,
        'discount_krw': discountKrw,
        'extra_visits': extraVisits,
        'gift_qty': giftQty,
        'status': status.dbValue,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'used_at': usedAt?.toUtc().toIso8601String(),
        'used_quote_id': DbMap.nullIfBlank(usedQuoteId),
      };

  factory ProgramCustomerCoupon.fromMap(Map<String, dynamic> map) {
    return ProgramCustomerCoupon(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      customerId: DbMap.asText(map['customer_id'] ?? map['customerId']),
      title: DbMap.asText(map['title']),
      issuedQuoteId:
          DbMap.asTextOrNull(map['issued_quote_id'] ?? map['issuedQuoteId']),
      promotionId: DbMap.asTextOrNull(map['promotion_id'] ?? map['promotionId']),
      percentOff: ProgramPricing.asPercent(
        map['percent_off'] ?? map['percentOff'],
      ),
      discountKrw: DbMap.asInt(map['discount_krw'] ?? map['discountKrw']),
      extraVisits: DbMap.asInt(map['extra_visits'] ?? map['extraVisits']),
      giftQty: DbMap.asInt(map['gift_qty'] ?? map['giftQty']),
      status: ProgramCouponStatus.fromDb(DbMap.asTextOrNull(map['status'])),
      issuedAt: DbMap.asDateTime(map['issued_at'] ?? map['issuedAt']),
      expiresAt: DbMap.asDateTime(map['expires_at'] ?? map['expiresAt']),
      usedAt: DbMap.asDateTime(map['used_at'] ?? map['usedAt']),
      usedQuoteId:
          DbMap.asTextOrNull(map['used_quote_id'] ?? map['usedQuoteId']),
    );
  }

  /// 견적에 붙은 미래가치 혜택 1장을 고객 쿠폰으로 찍어 낸다.
  factory ProgramCustomerCoupon.fromPromotion({
    required String id,
    required ProgramPromotion promo,
    required String customerId,
    required String quoteId,
    DateTime? issuedAt,
  }) {
    return ProgramCustomerCoupon(
      id: id,
      shopId: promo.shopId,
      customerId: customerId,
      title: promo.title,
      issuedQuoteId: quoteId,
      promotionId: promo.id,
      percentOff: promo.percentOff,
      discountKrw: promo.discountKrw,
      extraVisits: promo.extraVisits,
      giftQty: promo.giftQty,
      expiresAt: promo.validUntil,
      issuedAt: issuedAt ?? DateTime.now(),
    );
  }
}

class ProgramQuote {
  const ProgramQuote({
    required this.id,
    required this.shopId,
    required this.left,
    this.right,
    this.authorId,
    this.customerId,
    this.leftPackageId,
    this.rightPackageId,
    this.chosenPackageId,
    this.promotionIds = const [],
    this.listPriceKrw = 0,
    this.benefitValueKrw = 0,
    this.payableKrw = 0,
    this.status = ProgramQuoteStatus.draft,
    this.paymentStatus = ProgramPaymentStatus.unpaid,
    this.paidKrw = 0,
    this.paymentMethod,
    this.paidAt,
    this.presentedAt,
    this.acceptedAt,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String? authorId;
  final String? customerId;
  final String? leftPackageId;
  final String? rightPackageId;
  final String? chosenPackageId;
  final ProgramPackageSnapshot left;

  /// 단건 상담이면 null. 비교 진입 시에만 두 번째 스냅샷이 생긴다 (R2).
  final ProgramPackageSnapshot? right;
  final List<String> promotionIds;
  final int listPriceKrw;
  final int benefitValueKrw;
  final int payableKrw;
  final ProgramQuoteStatus status;
  final ProgramPaymentStatus paymentStatus;
  final int paidKrw;
  final ProgramPaymentMethod? paymentMethod;
  final DateTime? paidAt;
  final DateTime? presentedAt;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  bool get isSingle => right == null;

  /// Q5(a) — 수락분은 항상, 이탈분은 90일간 리드로 남긴다. 삭제하지 않는다.
  static const leadRetention = Duration(days: 90);

  bool isVisibleLeadAt([DateTime? now]) {
    if (status == ProgramQuoteStatus.accepted) return true;
    final t = createdAt ?? presentedAt;
    if (t == null) return true;
    return (now ?? DateTime.now()).difference(t) <= leadRetention;
  }

  ProgramPackageSnapshot get chosen {
    final r = right;
    if (r != null && chosenPackageId == r.id) return r;
    return left;
  }

  bool get isCrossCategory {
    final r = right;
    return r != null && left.categoryId != r.categoryId;
  }

  /// Q3(a) — 못 받은 돈. 0 이면 미수 배지를 띄우지 않는다.
  int get outstandingKrw {
    final due = payableKrw - paidKrw;
    return due < 0 ? 0 : due;
  }

  bool get isUnpaid =>
      status == ProgramQuoteStatus.accepted && outstandingKrw > 0;

  /// 같은 혜택을 여러 장 붙인 횟수. UI 칩의 `×N`.
  Map<String, int> get promotionQty => ProgramPromoStack.qtyById(promotionIds);

  List<String> get uniquePromotionIds =>
      ProgramPromoStack.uniqueInOrder(promotionIds);

  ProgramQuote copyWith({
    String? id,
    String? customerId,
    String? chosenPackageId,
    ProgramPackageSnapshot? right,
    String? rightPackageId,
    List<String>? promotionIds,
    int? listPriceKrw,
    int? benefitValueKrw,
    int? payableKrw,
    ProgramQuoteStatus? status,
    ProgramPaymentStatus? paymentStatus,
    int? paidKrw,
    ProgramPaymentMethod? paymentMethod,
    DateTime? paidAt,
    DateTime? presentedAt,
    DateTime? acceptedAt,
    bool clearCustomer = false,
  }) {
    return ProgramQuote(
      id: id ?? this.id,
      shopId: shopId,
      authorId: authorId,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      leftPackageId: leftPackageId,
      rightPackageId: rightPackageId ?? this.rightPackageId,
      chosenPackageId: chosenPackageId ?? this.chosenPackageId,
      left: left,
      right: right ?? this.right,
      promotionIds: promotionIds ?? this.promotionIds,
      listPriceKrw: listPriceKrw ?? this.listPriceKrw,
      benefitValueKrw: benefitValueKrw ?? this.benefitValueKrw,
      payableKrw: payableKrw ?? this.payableKrw,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidKrw: paidKrw ?? this.paidKrw,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      presentedAt: presentedAt ?? this.presentedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'author_id': DbMap.nullIfBlank(authorId),
        'customer_id': DbMap.nullIfBlank(customerId),
        'left_package_id': DbMap.nullIfBlank(leftPackageId),
        'right_package_id': DbMap.nullIfBlank(rightPackageId),
        'chosen_package_id': DbMap.nullIfBlank(chosenPackageId),
        'snapshot': {
          'left': left.toMap(),
          if (right != null) 'right': right!.toMap(),
        },
        'list_price_krw': listPriceKrw,
        'benefit_value_krw': benefitValueKrw,
        'payable_krw': payableKrw,
        'status': status.dbValue,
        'payment_status': paymentStatus.dbValue,
        'paid_krw': paidKrw,
        'paid_at': paidAt?.toUtc().toIso8601String(),
        'presented_at': presentedAt?.toUtc().toIso8601String(),
        'accepted_at': acceptedAt?.toUtc().toIso8601String(),
      };

  /// 113 미적용 DB 로 저장할 때 벗겨 낼 키.
  static const v72Columns = <String>[
    'payment_status',
    'paid_krw',
    'paid_at',
  ];

  factory ProgramQuote.fromMap(
    Map<String, dynamic> map, {
    List<String> promotionIds = const [],
  }) {
    final snapRaw = map['snapshot'];
    Map<String, dynamic> snap = const {};
    if (snapRaw is Map) snap = Map<String, dynamic>.from(snapRaw);
    final leftRaw = snap['left'];
    final rightRaw = snap['right'];
    return ProgramQuote(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      authorId: DbMap.asTextOrNull(map['author_id'] ?? map['authorId']),
      customerId: DbMap.asTextOrNull(map['customer_id'] ?? map['customerId']),
      leftPackageId:
          DbMap.asTextOrNull(map['left_package_id'] ?? map['leftPackageId']),
      rightPackageId:
          DbMap.asTextOrNull(map['right_package_id'] ?? map['rightPackageId']),
      chosenPackageId:
          DbMap.asTextOrNull(map['chosen_package_id'] ?? map['chosenPackageId']),
      left: leftRaw is Map
          ? ProgramPackageSnapshot.fromMap(Map<String, dynamic>.from(leftRaw))
          : const ProgramPackageSnapshot(
              id: '',
              name: '',
              categoryId: '',
              categoryName: '',
              visitCount: 1,
              listPriceKrw: 0,
            ),
      right: rightRaw is Map
          ? ProgramPackageSnapshot.fromMap(Map<String, dynamic>.from(rightRaw))
          : null,
      promotionIds: promotionIds,
      listPriceKrw: DbMap.asInt(map['list_price_krw'] ?? map['listPriceKrw']),
      benefitValueKrw:
          DbMap.asInt(map['benefit_value_krw'] ?? map['benefitValueKrw']),
      payableKrw: DbMap.asInt(map['payable_krw'] ?? map['payableKrw']),
      status: ProgramQuoteStatus.fromDb(DbMap.asTextOrNull(map['status'])),
      paymentStatus: ProgramPaymentStatus.fromDb(
        DbMap.asTextOrNull(map['payment_status'] ?? map['paymentStatus']),
      ),
      paidKrw: DbMap.asInt(map['paid_krw'] ?? map['paidKrw']),
      paidAt: DbMap.asDateTime(map['paid_at'] ?? map['paidAt']),
      presentedAt: DbMap.asDateTime(map['presented_at'] ?? map['presentedAt']),
      acceptedAt: DbMap.asDateTime(map['accepted_at'] ?? map['acceptedAt']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

/// 수락 RPC 의 반환. 회원권·쿠폰·결제가 한 트랜잭션으로 닫힌 결과다 (116).
class ProgramAcceptResult {
  const ProgramAcceptResult({
    required this.quote,
    this.membershipId,
    this.coupons = const [],
  });

  final ProgramQuote quote;
  final String? membershipId;
  final List<ProgramCustomerCoupon> coupons;

  factory ProgramAcceptResult.fromRpc(Map<String, dynamic> raw) {
    final quoteRaw = raw['quote'];
    final quoteMap = quoteRaw is Map
        ? Map<String, dynamic>.from(quoteRaw)
        : raw;
    final couponsRaw = raw['coupons'];
    final coupons = <ProgramCustomerCoupon>[];
    if (couponsRaw is List) {
      for (final item in couponsRaw) {
        if (item is Map) {
          coupons.add(
            ProgramCustomerCoupon.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ProgramAcceptResult(
      quote: ProgramQuote.fromMap(quoteMap),
      membershipId: DbMap.asTextOrNull(raw['membership_id']),
      coupons: coupons,
    );
  }
}

/// 보드 한 칸 = 카테고리 + 활성 패키지 (앵커 파생 포함).
class ProgramCategoryBoard {
  const ProgramCategoryBoard({
    required this.category,
    required this.packages,
    this.anchor,
  });

  final ProgramCategory category;
  final List<ProgramPackage> packages;
  final ProgramPackage? anchor;

  factory ProgramCategoryBoard.assemble({
    required ProgramCategory category,
    required Iterable<ProgramPackage> allPackages,
  }) {
    final active = allPackages
        .where((p) => p.categoryId == category.id && p.isActive)
        .toList();
    final anchor = ProgramPackage.boardAnchor(active);
    active.sort(
      (a, b) => ProgramPackage.expandOrder(a, b, anchorId: anchor?.id),
    );
    return ProgramCategoryBoard(
      category: category,
      packages: active,
      anchor: anchor,
    );
  }
}

class ProgramBoardSnapshot {
  const ProgramBoardSnapshot({
    this.categories = const [],
    this.packages = const [],
    this.promotions = const [],
    this.quotes = const [],
    this.coupons = const [],
    this.memberships = const [],
  });

  final List<ProgramCategory> categories;
  final List<ProgramPackage> packages;
  final List<ProgramPromotion> promotions;
  final List<ProgramQuote> quotes;
  final List<ProgramCustomerCoupon> coupons;
  final List<ProgramMembership> memberships;
}

/// 메모리/E2E용 윤곽 디코이 산수. 운영 메뉴(`shop_menus`)와 id가 겹치지 않는다.
abstract final class ProgramDemoSeed {
  static const contourId = '00000000-0000-4000-8000-00000000c001';
  static const weddingId = '00000000-0000-4000-8000-00000000c002';
  static const pkgA = '00000000-0000-4000-8000-00000000a001';
  static const pkgB = '00000000-0000-4000-8000-00000000a002';
  static const pkgC = '00000000-0000-4000-8000-00000000a003';
  static const pkgWedding = '00000000-0000-4000-8000-00000000a004';
  static const promoExtra = '00000000-0000-4000-8000-00000000p001';
  static const promoGift = '00000000-0000-4000-8000-00000000p002';
  static const promoCredit = '00000000-0000-4000-8000-00000000p003';

  static ProgramBoardSnapshot forShop(String shopId) {
    final sid = shopId.trim().isEmpty ? 'shop-demo' : shopId.trim();
    final now = DateTime(2026, 9, 2, 10);

    ProgramPackageLine line({
      required String packageId,
      required ProgramLineKind kind,
      required String label,
      int? minutes,
      int sort = 0,
    }) {
      return ProgramPackageLine(
        id: newUuidV4(),
        packageId: packageId,
        kind: kind,
        label: label,
        minutes: minutes,
        sortOrder: sort,
      );
    }

    final pkgALines = [
      line(
        packageId: pkgA,
        kind: ProgramLineKind.step,
        label: '고주파 온열',
        minutes: 20,
      ),
      line(
        packageId: pkgA,
        kind: ProgramLineKind.step,
        label: '원장 수기 윤곽',
        minutes: 25,
        sort: 1,
      ),
      line(
        packageId: pkgA,
        kind: ProgramLineKind.device,
        label: 'EMS 리프팅 기기',
        sort: 2,
      ),
      line(
        packageId: pkgA,
        kind: ProgramLineKind.ampoule,
        label: '프리미엄 팩',
        sort: 3,
      ),
    ];
    final pkgBLines = [
      line(
        packageId: pkgB,
        kind: ProgramLineKind.step,
        label: '고주파 온열',
        minutes: 15,
      ),
      line(
        packageId: pkgB,
        kind: ProgramLineKind.step,
        label: '수기 윤곽',
        minutes: 20,
        sort: 1,
      ),
      line(
        packageId: pkgB,
        kind: ProgramLineKind.device,
        label: 'EMS 리프팅 기기',
        sort: 2,
      ),
    ];
    final pkgCLines = [
      line(
        packageId: pkgC,
        kind: ProgramLineKind.step,
        label: '순환 관리',
        minutes: 20,
      ),
      line(
        packageId: pkgC,
        kind: ProgramLineKind.ampoule,
        label: '수분 앰플',
        sort: 1,
      ),
    ];

    return ProgramBoardSnapshot(
      categories: [
        ProgramCategory(
          id: contourId,
          shopId: sid,
          name: '윤곽 관리',
          subtitle: '가장 높은 기준점',
          sortOrder: 0,
          createdAt: now,
        ),
        ProgramCategory(
          id: weddingId,
          shopId: sid,
          name: '웨딩신부 관리',
          subtitle: '본식 라인 고정',
          sortOrder: 1,
          createdAt: now,
        ),
      ],
      packages: [
        ProgramPackage(
          id: pkgA,
          shopId: sid,
          categoryId: contourId,
          name: 'A패키지',
          visitCount: 10,
          listPriceKrw: 3000000,
          tier: ProgramPackageTier.anchor,
          sortOrder: 0,
          lines: pkgALines,
          accentHex: ProgramAccent.charcoal,
          walkInPriceKrw: 350000,
          createdAt: now,
        ),
        ProgramPackage(
          id: pkgB,
          shopId: sid,
          categoryId: contourId,
          name: 'B패키지',
          visitCount: 6,
          listPriceKrw: 1500000,
          tier: ProgramPackageTier.target,
          sortOrder: 1,
          lines: pkgBLines,
          accentHex: '8B7355',
          walkInPriceKrw: 350000,
          createdAt: now.add(const Duration(minutes: 1)),
        ),
        ProgramPackage(
          id: pkgC,
          shopId: sid,
          categoryId: contourId,
          name: 'C패키지',
          visitCount: 3,
          listPriceKrw: 1000000,
          tier: ProgramPackageTier.decoy,
          sortOrder: 2,
          lines: pkgCLines,
          accentHex: '5C6B73',
          walkInPriceKrw: 350000,
          createdAt: now.add(const Duration(minutes: 2)),
        ),
        ProgramPackage(
          id: pkgWedding,
          shopId: sid,
          categoryId: weddingId,
          name: '웨딩 시그니처',
          visitCount: 8,
          listPriceKrw: 2500000,
          tier: ProgramPackageTier.anchor,
          sortOrder: 0,
          createdAt: now,
          accentHex: '6B4F5B',
          walkInPriceKrw: 400000,
          lines: [
            line(
              packageId: pkgWedding,
              kind: ProgramLineKind.step,
              label: '본식 리허설 케어',
              minutes: 40,
            ),
          ],
        ),
      ],
      promotions: [
        ProgramPromotion(
          id: promoExtra,
          shopId: sid,
          kind: ProgramPromoKind.extraSession,
          title: '+1회 추가',
          subtitle: '같은 구성으로 한 번 더',
          valueKrw: 300000,
          extraVisits: 1,
          sortOrder: 0,
        ),
        ProgramPromotion(
          id: promoGift,
          shopId: sid,
          kind: ProgramPromoKind.gift,
          title: '10만 원 상당 수분 크림',
          subtitle: '오늘 가져가시는 홈케어',
          valueKrw: 100000,
          sortOrder: 1,
        ),
        ProgramPromotion(
          id: promoCredit,
          shopId: sid,
          kind: ProgramPromoKind.nextVisitCredit,
          title: '다음 패키지 20% 할인',
          subtitle: '재방문 시 쿠폰으로 드립니다',
          valueKrw: 200000,
          percentOff: 20,
          sortOrder: 2,
        ),
      ],
    );
  }
}

/// 단건 요약 / 비교 화면을 닫을 때 보드가 다음 동작을 안다.
enum ProgramConsultResult {
  closed,
  accepted,
  addCompare,
}

enum ProgramMembershipStatus {
  active,
  refunded,
  superseded,
  expired,
  voided;

  String get dbValue => name;

  static ProgramMembershipStatus fromDb(String? raw) {
    return ProgramMembershipStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProgramMembershipStatus.active,
    );
  }
}

enum ProgramRefundBasis {
  listUnit,
  packageUnit;

  String get dbValue =>
      this == ProgramRefundBasis.listUnit ? 'list_unit' : 'package_unit';

  static ProgramRefundBasis? fromDb(String? raw) {
    return switch (raw) {
      'list_unit' => ProgramRefundBasis.listUnit,
      'package_unit' => ProgramRefundBasis.packageUnit,
      _ => null,
    };
  }
}

/// Q2(a) — 회원권 자산. jsonb 미러의 진실 원본이다.
class ProgramMembership {
  const ProgramMembership({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.serviceName,
    required this.totalVisits,
    this.usedVisits = 0,
    this.paidKrw = 0,
    this.perSessionKrw = 0,
    this.sourceQuoteId,
    this.status = ProgramMembershipStatus.active,
    this.refundedKrw = 0,
    this.refundedAt,
    this.refundBasis,
    this.supersededBy,
    this.creditAppliedKrw = 0,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String? sourceQuoteId;
  final String serviceName;
  final int totalVisits;
  final int usedVisits;
  final int paidKrw;
  final int perSessionKrw;
  final ProgramMembershipStatus status;
  final int refundedKrw;
  final DateTime? refundedAt;
  final ProgramRefundBasis? refundBasis;
  final String? supersededBy;
  final int creditAppliedKrw;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  int get remainingVisits => (totalVisits - usedVisits).clamp(0, 999);

  bool get isUsable =>
      status == ProgramMembershipStatus.active && remainingVisits > 0;

  int get remainingValueKrw =>
      (perSessionKrw > 0 ? perSessionKrw : 0) * remainingVisits;

  /// E1 — 소진분은 빼고 나머지를 돌려준다.
  int refundAmount({
    ProgramRefundBasis basis = ProgramRefundBasis.packageUnit,
    int? listUnitKrw,
  }) {
    final unit = basis == ProgramRefundBasis.listUnit
        ? (listUnitKrw ?? perSessionKrw)
        : perSessionKrw;
    final left = paidKrw - unit * usedVisits;
    return left < 0 ? 0 : left;
  }

  CustomerMembership toCustomerTicket() => CustomerMembership(
        id: id,
        serviceName: serviceName,
        totalVisits: totalVisits,
        usedVisits: usedVisits,
        paidAmount: paidKrw,
        perSessionValue: perSessionKrw,
        expiresAt: expiresAt,
      );

  ProgramMembership copyWith({
    String? id,
    int? usedVisits,
    ProgramMembershipStatus? status,
    int? refundedKrw,
    DateTime? refundedAt,
    ProgramRefundBasis? refundBasis,
    String? supersededBy,
    int? creditAppliedKrw,
    DateTime? expiresAt,
  }) {
    return ProgramMembership(
      id: id ?? this.id,
      shopId: shopId,
      customerId: customerId,
      sourceQuoteId: sourceQuoteId,
      serviceName: serviceName,
      totalVisits: totalVisits,
      usedVisits: usedVisits ?? this.usedVisits,
      paidKrw: paidKrw,
      perSessionKrw: perSessionKrw,
      status: status ?? this.status,
      refundedKrw: refundedKrw ?? this.refundedKrw,
      refundedAt: refundedAt ?? this.refundedAt,
      refundBasis: refundBasis ?? this.refundBasis,
      supersededBy: supersededBy ?? this.supersededBy,
      creditAppliedKrw: creditAppliedKrw ?? this.creditAppliedKrw,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'customer_id': customerId,
        'source_quote_id': DbMap.nullIfBlank(sourceQuoteId),
        'service_name': serviceName,
        'total_visits': totalVisits,
        'used_visits': usedVisits,
        'paid_krw': paidKrw,
        'per_session_krw': perSessionKrw,
        'status': status.dbValue,
        'refunded_krw': refundedKrw,
        'refunded_at': refundedAt?.toUtc().toIso8601String(),
        'refund_basis': refundBasis?.dbValue,
        'superseded_by': DbMap.nullIfBlank(supersededBy),
        'credit_applied_krw': creditAppliedKrw,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        if (createdAt != null)
          'created_at': createdAt!.toUtc().toIso8601String(),
      };

  factory ProgramMembership.fromMap(Map<String, dynamic> map) {
    return ProgramMembership(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      customerId: DbMap.asText(map['customer_id'] ?? map['customerId']),
      sourceQuoteId:
          DbMap.asTextOrNull(map['source_quote_id'] ?? map['sourceQuoteId']),
      serviceName: DbMap.asText(map['service_name'] ?? map['serviceName']),
      totalVisits: DbMap.asInt(map['total_visits'] ?? map['totalVisits'], 1),
      usedVisits: DbMap.asInt(map['used_visits'] ?? map['usedVisits']),
      paidKrw: DbMap.asInt(map['paid_krw'] ?? map['paidKrw']),
      perSessionKrw: DbMap.asInt(map['per_session_krw'] ?? map['perSessionKrw']),
      status: ProgramMembershipStatus.fromDb(
        DbMap.asTextOrNull(map['status']),
      ),
      refundedKrw: DbMap.asInt(map['refunded_krw'] ?? map['refundedKrw']),
      refundedAt: DbMap.asDateTime(map['refunded_at'] ?? map['refundedAt']),
      refundBasis: ProgramRefundBasis.fromDb(
        DbMap.asTextOrNull(map['refund_basis'] ?? map['refundBasis']),
      ),
      supersededBy:
          DbMap.asTextOrNull(map['superseded_by'] ?? map['supersededBy']),
      creditAppliedKrw:
          DbMap.asInt(map['credit_applied_krw'] ?? map['creditAppliedKrw']),
      expiresAt: DbMap.asDateTime(map['expires_at'] ?? map['expiresAt']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }

  /// E7 — 만료 임박 → 잔여 적은 순 → 구매 오래된 순.
  static int deductOrder(ProgramMembership a, ProgramMembership b) {
    final ae = a.expiresAt;
    final be = b.expiresAt;
    if (ae != null && be != null) {
      final byExp = ae.compareTo(be);
      if (byExp != 0) return byExp;
    } else if (ae != null) {
      return -1;
    } else if (be != null) {
      return 1;
    }
    final byRemain = a.remainingVisits.compareTo(b.remainingVisits);
    if (byRemain != 0) return byRemain;
    final ac = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bc = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ac.compareTo(bc);
  }
}

/// R9 — 원격 수락이 실패한 견적. 연결되면 같은 인자로 다시 보낸다.
class ProgramAcceptOutboxItem {
  const ProgramAcceptOutboxItem({
    required this.quoteId,
    required this.customerId,
    this.paymentStatus = ProgramPaymentStatus.unpaid,
    this.paidKrw = 0,
    this.method = ProgramPaymentMethod.cash,
  });

  final String quoteId;
  final String customerId;
  final ProgramPaymentStatus paymentStatus;
  final int paidKrw;
  final ProgramPaymentMethod method;

  Map<String, dynamic> toMap() => {
        'quote_id': quoteId,
        'customer_id': customerId,
        'payment_status': paymentStatus.dbValue,
        'paid_krw': paidKrw,
        'method': method.dbValue,
      };

  factory ProgramAcceptOutboxItem.fromMap(Map<String, dynamic> map) {
    return ProgramAcceptOutboxItem(
      quoteId: DbMap.asText(map['quote_id'] ?? map['quoteId']),
      customerId: DbMap.asText(map['customer_id'] ?? map['customerId']),
      paymentStatus: ProgramPaymentStatus.fromDb(
        DbMap.asTextOrNull(map['payment_status'] ?? map['paymentStatus']),
      ),
      paidKrw: DbMap.asInt(map['paid_krw'] ?? map['paidKrw']),
      method: ProgramPaymentMethod.fromDb(
        DbMap.asTextOrNull(map['method']),
      ),
    );
  }
}
