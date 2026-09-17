/// 경영 대시보드 ZONE 1·2 순수 계산 (PRD v7.6 Phase 1).
/// Store·Flutter 의존 없음.

class ShopBizProfile {
  const ShopBizProfile({
    this.category = '',
    this.address = '',
    this.admCd = '',
    this.monthlyFixedCostKrw = 0,
    this.materialRatePct = 15,
    this.targetOwnerPayKrw = 0,
    this.openDaysPerWeek = 5,
    this.hoursPerDay = 8,
    this.cardFeeRatePct = 2.5,
  });

  final String category;
  final String address;
  /// 행정기관코드(행정동) — 인구 API용. 예: 1111051500
  final String admCd;
  /// 월 고정비 합계 (임대·관리·보험 등).
  final int monthlyFixedCostKrw;
  /// 평균 재료비 비율 (% of 매출).
  final double materialRatePct;
  /// 목표 월 소득 = 대표 인건비 기준선.
  final int targetOwnerPayKrw;
  final int openDaysPerWeek;
  final double hoursPerDay;
  /// 카드 수수료 가정 (%). 온보딩에 없고 기본 2.5.
  final double cardFeeRatePct;

  bool get isComplete =>
      category.trim().isNotEmpty &&
      monthlyFixedCostKrw > 0 &&
      targetOwnerPayKrw > 0 &&
      openDaysPerWeek > 0 &&
      hoursPerDay > 0;

  /// 월 투입시간 ≈ 주 영업일 × 일 시간 × 4.33주.
  double get monthlyHours => openDaysPerWeek * hoursPerDay * 4.33;

  ShopBizProfile copyWith({
    String? category,
    String? address,
    String? admCd,
    int? monthlyFixedCostKrw,
    double? materialRatePct,
    int? targetOwnerPayKrw,
    int? openDaysPerWeek,
    double? hoursPerDay,
    double? cardFeeRatePct,
  }) {
    return ShopBizProfile(
      category: category ?? this.category,
      address: address ?? this.address,
      admCd: admCd ?? this.admCd,
      monthlyFixedCostKrw: monthlyFixedCostKrw ?? this.monthlyFixedCostKrw,
      materialRatePct: materialRatePct ?? this.materialRatePct,
      targetOwnerPayKrw: targetOwnerPayKrw ?? this.targetOwnerPayKrw,
      openDaysPerWeek: openDaysPerWeek ?? this.openDaysPerWeek,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      cardFeeRatePct: cardFeeRatePct ?? this.cardFeeRatePct,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'address': address,
        'admCd': admCd,
        'monthlyFixedCostKrw': monthlyFixedCostKrw,
        'materialRatePct': materialRatePct,
        'targetOwnerPayKrw': targetOwnerPayKrw,
        'openDaysPerWeek': openDaysPerWeek,
        'hoursPerDay': hoursPerDay,
        'cardFeeRatePct': cardFeeRatePct,
      };

  factory ShopBizProfile.fromJson(Map<String, dynamic>? map) {
    if (map == null) return const ShopBizProfile();
    double asD(dynamic v, [double f = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? f;
    }

    int asI(dynamic v, [int f = 0]) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse('$v') ?? f;
    }

    return ShopBizProfile(
      category: '${map['category'] ?? ''}',
      address: '${map['address'] ?? ''}',
      admCd: '${map['admCd'] ?? map['adm_cd'] ?? ''}',
      monthlyFixedCostKrw: asI(map['monthlyFixedCostKrw']),
      materialRatePct: asD(map['materialRatePct'], 15),
      targetOwnerPayKrw: asI(map['targetOwnerPayKrw']),
      openDaysPerWeek: asI(map['openDaysPerWeek'], 5),
      hoursPerDay: asD(map['hoursPerDay'], 8),
      cardFeeRatePct: asD(map['cardFeeRatePct'], 2.5),
    );
  }
}

enum BizMaturityStage {
  /// 진짜 영업이익 < 0
  survival,
  /// 인건비는 확보, 사업 이익 ≈ 0
  selfEmployed,
  /// 사업 이익 흑자
  managing,
  /// 재투자 여유 (사업이익 ≥ 인건비의 50%)
  expanding,
}

class BizZone12Snapshot {
  const BizZone12Snapshot({
    required this.revenueKrw,
    required this.materialCostKrw,
    required this.cardFeeKrw,
    required this.fixedCostKrw,
    required this.ownerPayKrw,
    required this.businessProfitKrw,
    required this.hourlyYieldKrw,
    required this.monthlyHours,
    required this.bepRevenueKrw,
    required this.safetyMarginPct,
    required this.bepDayOfMonth,
    required this.daysInMonth,
    required this.stage,
    required this.minWageMultiple,
  });

  final int revenueKrw;
  final int materialCostKrw;
  final int cardFeeKrw;
  final int fixedCostKrw;
  final int ownerPayKrw;
  final int businessProfitKrw;
  final int hourlyYieldKrw;
  final double monthlyHours;
  final int bepRevenueKrw;
  final double safetyMarginPct;
  final int? bepDayOfMonth;
  final int daysInMonth;
  final BizMaturityStage stage;
  /// 시간당 수익 ÷ 시간당 최저임금(참고 상수).
  final double? minWageMultiple;

  int get variableCostKrw => materialCostKrw + cardFeeKrw;

  /// 워터폴 잔액 추적용 단계 (매출에서 차감 후 잔액).
  List<({String label, int amountKrw, bool isOwnerPay})> get waterfallSteps {
    return [
      (label: '매출', amountKrw: revenueKrw, isOwnerPay: false),
      (label: '재료비', amountKrw: -materialCostKrw, isOwnerPay: false),
      (label: '카드수수료', amountKrw: -cardFeeKrw, isOwnerPay: false),
      (label: '고정비', amountKrw: -fixedCostKrw, isOwnerPay: false),
      (label: '대표 인건비', amountKrw: -ownerPayKrw, isOwnerPay: true),
      (label: '사업 이익', amountKrw: businessProfitKrw, isOwnerPay: false),
    ];
  }
}

/// 2026 시간당 최저임금 참고값 (앱 내 하드코드 · 공식 고시 대체 아님).
const int kBizReferenceMinWageHourlyKrw = 10320;

abstract final class BizMath {
  static BizZone12Snapshot? compute({
    required ShopBizProfile profile,
    required int? monthRevenueKrw,
    DateTime? now,
  }) {
    if (!profile.isComplete) return null;
    final revenue = monthRevenueKrw;
    if (revenue == null || revenue < 0) return null;

    final clock = now ?? DateTime.now();
    final daysInMonth = DateTime(clock.year, clock.month + 1, 0).day;

    final material = (revenue * (profile.materialRatePct / 100)).round();
    final card = (revenue * (profile.cardFeeRatePct / 100)).round();
    final fixed = profile.monthlyFixedCostKrw;
    final owner = profile.targetOwnerPayKrw;
    final hours = profile.monthlyHours;

    // 시간당 수익: 인건비 차감 전 (설계안 1-1).
    final afterOps = revenue - material - card - fixed;
    final hourly = hours > 0 ? (afterOps / hours).round() : 0;

    // 진짜 영업이익: 인건비 계상 후 (설계안 1-2).
    final businessProfit = afterOps - owner;

    // BEP: 고정비+대표인건비 포함 (와이어 확정).
    final cmRate = 1.0 - (profile.materialRatePct + profile.cardFeeRatePct) / 100;
    int bep;
    if (cmRate <= 0.01) {
      bep = revenue;
    } else {
      bep = ((fixed + owner) / cmRate).ceil();
    }

    double safety = 0;
    if (revenue > 0) {
      safety = (revenue - bep) / revenue * 100;
    }

    int? bepDay;
    if (revenue > 0 && bep > 0) {
      final raw = (bep / revenue) * daysInMonth;
      bepDay = raw.ceil().clamp(1, daysInMonth);
      if (bep > revenue) bepDay = null; // 미도달
    }

    final stage = _stage(businessProfit: businessProfit, ownerPay: owner);

    double? multiple;
    if (hourly != 0) {
      multiple = hourly / kBizReferenceMinWageHourlyKrw;
    }

    return BizZone12Snapshot(
      revenueKrw: revenue,
      materialCostKrw: material,
      cardFeeKrw: card,
      fixedCostKrw: fixed,
      ownerPayKrw: owner,
      businessProfitKrw: businessProfit,
      hourlyYieldKrw: hourly,
      monthlyHours: hours,
      bepRevenueKrw: bep,
      safetyMarginPct: safety,
      bepDayOfMonth: bepDay,
      daysInMonth: daysInMonth,
      stage: stage,
      minWageMultiple: multiple,
    );
  }

  static BizMaturityStage _stage({
    required int businessProfit,
    required int ownerPay,
  }) {
    if (businessProfit < 0) return BizMaturityStage.survival;
    if (businessProfit == 0) return BizMaturityStage.selfEmployed;
    if (ownerPay > 0 && businessProfit >= (ownerPay * 0.5).round()) {
      return BizMaturityStage.expanding;
    }
    return BizMaturityStage.managing;
  }

  static String stageLabel(BizMaturityStage s) => switch (s) {
        BizMaturityStage.survival => '생존',
        BizMaturityStage.selfEmployed => '자립',
        BizMaturityStage.managing => '경영',
        BizMaturityStage.expanding => '확장',
      };
}
