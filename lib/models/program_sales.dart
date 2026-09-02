import '../utils/db_map.dart';
import '../utils/sori_uuid.dart';

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
}

enum ProgramPromoKind {
  extraSession,
  gift,
  instantDiscount,
  nextVisitCredit;

  String get dbValue => switch (this) {
        ProgramPromoKind.extraSession => 'extra_session',
        ProgramPromoKind.gift => 'gift',
        ProgramPromoKind.instantDiscount => 'instant_discount',
        ProgramPromoKind.nextVisitCredit => 'next_visit_credit',
      };

  static ProgramPromoKind fromDb(String? raw) {
    return switch (raw) {
      'extra_session' => ProgramPromoKind.extraSession,
      'gift' => ProgramPromoKind.gift,
      'instant_discount' => ProgramPromoKind.instantDiscount,
      'next_visit_credit' => ProgramPromoKind.nextVisitCredit,
      _ => ProgramPromoKind.gift,
    };
  }

  /// 원장 화면에만 쓴다. dbValue 를 그대로 노출하지 않는다.
  String get labelKo => switch (this) {
        ProgramPromoKind.extraSession => '횟수 추가',
        ProgramPromoKind.gift => '사은품 증정',
        ProgramPromoKind.instantDiscount => '즉시 할인',
        ProgramPromoKind.nextVisitCredit => '다음 방문 크레딧',
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

  static int payable(int listPriceKrw, Iterable<ProgramPromotion> promos) {
    final discount = promos.fold<int>(0, (sum, p) => sum + p.discountKrw);
    final next = listPriceKrw - discount;
    return next < 0 ? 0 : next;
  }

  static int membershipVisits(
    int packageVisits,
    Iterable<ProgramPromotion> promos,
  ) =>
      packageVisits + promos.fold<int>(0, (sum, p) => sum + p.extraVisits);

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
  final bool isActive;
  final int sortOrder;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? createdAt;

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
    bool? isActive,
    int? sortOrder,
    DateTime? validFrom,
    DateTime? validUntil,
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
        'is_active': isActive,
        'sort_order': sortOrder,
        'valid_from': validFrom?.toUtc().toIso8601String(),
        'valid_until': validUntil?.toUtc().toIso8601String(),
      };

  factory ProgramPromotion.fromMap(Map<String, dynamic> map) {
    return ProgramPromotion(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      kind: ProgramPromoKind.fromDb(DbMap.asTextOrNull(map['kind'])),
      title: DbMap.asText(map['title']),
      subtitle: DbMap.asText(map['subtitle']),
      valueKrw: DbMap.asInt(map['value_krw'] ?? map['valueKrw']),
      extraVisits: DbMap.asInt(map['extra_visits'] ?? map['extraVisits']),
      discountKrw: DbMap.asInt(map['discount_krw'] ?? map['discountKrw']),
      isActive: DbMap.asBool(map['is_active'] ?? map['isActive'], true),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
      validFrom: DbMap.asDateTime(map['valid_from'] ?? map['validFrom']),
      validUntil: DbMap.asDateTime(map['valid_until'] ?? map['validUntil']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

class ProgramQuote {
  const ProgramQuote({
    required this.id,
    required this.shopId,
    required this.left,
    required this.right,
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
  final ProgramPackageSnapshot right;
  final List<String> promotionIds;
  final int listPriceKrw;
  final int benefitValueKrw;
  final int payableKrw;
  final ProgramQuoteStatus status;
  final DateTime? presentedAt;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  ProgramPackageSnapshot get chosen {
    if (chosenPackageId == right.id) return right;
    return left;
  }

  bool get isCrossCategory => left.categoryId != right.categoryId;

  /// 같은 혜택을 여러 장 붙인 횟수. UI 칩의 `×N`.
  Map<String, int> get promotionQty => ProgramPromoStack.qtyById(promotionIds);

  List<String> get uniquePromotionIds =>
      ProgramPromoStack.uniqueInOrder(promotionIds);

  ProgramQuote copyWith({
    String? id,
    String? customerId,
    String? chosenPackageId,
    List<String>? promotionIds,
    int? listPriceKrw,
    int? benefitValueKrw,
    int? payableKrw,
    ProgramQuoteStatus? status,
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
      rightPackageId: rightPackageId,
      chosenPackageId: chosenPackageId ?? this.chosenPackageId,
      left: left,
      right: right,
      promotionIds: promotionIds ?? this.promotionIds,
      listPriceKrw: listPriceKrw ?? this.listPriceKrw,
      benefitValueKrw: benefitValueKrw ?? this.benefitValueKrw,
      payableKrw: payableKrw ?? this.payableKrw,
      status: status ?? this.status,
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
          'right': right.toMap(),
        },
        'list_price_krw': listPriceKrw,
        'benefit_value_krw': benefitValueKrw,
        'payable_krw': payableKrw,
        'status': status.dbValue,
        'presented_at': presentedAt?.toUtc().toIso8601String(),
        'accepted_at': acceptedAt?.toUtc().toIso8601String(),
      };

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
          : const ProgramPackageSnapshot(
              id: '',
              name: '',
              categoryId: '',
              categoryName: '',
              visitCount: 1,
              listPriceKrw: 0,
            ),
      promotionIds: promotionIds,
      listPriceKrw: DbMap.asInt(map['list_price_krw'] ?? map['listPriceKrw']),
      benefitValueKrw:
          DbMap.asInt(map['benefit_value_krw'] ?? map['benefitValueKrw']),
      payableKrw: DbMap.asInt(map['payable_krw'] ?? map['payableKrw']),
      status: ProgramQuoteStatus.fromDb(DbMap.asTextOrNull(map['status'])),
      presentedAt: DbMap.asDateTime(map['presented_at'] ?? map['presentedAt']),
      acceptedAt: DbMap.asDateTime(map['accepted_at'] ?? map['acceptedAt']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
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
  });

  final List<ProgramCategory> categories;
  final List<ProgramPackage> packages;
  final List<ProgramPromotion> promotions;
  final List<ProgramQuote> quotes;
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
      ],
    );
  }
}
