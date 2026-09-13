enum MarketDataStatus { live, liveEmpty, cached, stale, demo, unavailable }

enum MarketLayer { competition, population, footTraffic, marketTrend }

enum ActionPlanStatus { todo, inProgress, done, skipped }

enum ActionHorizon { today, thisWeek, d30 }

enum ActionPriority { high, mid, low }

abstract final class MarketTrade {
  static const hair = 'hair';
  static const barber = 'barber';
  static const nail = 'nail';
  static const skin = 'skin';
  static const makeup = 'makeup';
  static const lash = 'lash';
  static const tattoo = 'tattoo';
  static const waxing = 'waxing';
  static const mixed = 'mixed';

  static const keys = <String>[
    hair,
    barber,
    nail,
    skin,
    makeup,
    lash,
    tattoo,
    waxing,
    mixed,
  ];

  static const labels = <String, String>{
    hair: '헤어',
    barber: '바버',
    nail: '네일',
    skin: '피부·에스테틱',
    makeup: '메이크업',
    lash: '속눈썹·눈썹',
    tattoo: '타투',
    waxing: '왁싱',
    mixed: '복합뷰티',
  };

  static String labelOf(String key) => labels[key] ?? key;
}

class IndicatorMeta {
  const IndicatorMeta({
    required this.source,
    required this.periodLabel,
    required this.updatedOn,
    required this.geoUnit,
    this.available = true,
    this.nextAction,
    this.comparisonWarning,
  });

  final String source;
  final String periodLabel;
  final String updatedOn;
  final String geoUnit;
  final bool available;
  final String? nextAction;
  final String? comparisonWarning;

  Map<String, dynamic> toJson() => {
        'source': source,
        'periodLabel': periodLabel,
        'updatedOn': updatedOn,
        'geoUnit': geoUnit,
        'available': available,
        'nextAction': nextAction,
        'comparisonWarning': comparisonWarning,
      };

  factory IndicatorMeta.fromJson(Map<String, dynamic> map) {
    return IndicatorMeta(
      source: '${map['source'] ?? ''}',
      periodLabel: '${map['periodLabel'] ?? ''}',
      updatedOn: '${map['updatedOn'] ?? ''}',
      geoUnit: '${map['geoUnit'] ?? ''}',
      available: map['available'] != false,
      nextAction: map['nextAction']?.toString(),
      comparisonWarning: map['comparisonWarning']?.toString(),
    );
  }
}

class CompetitorShop {
  const CompetitorShop({
    required this.id,
    required this.name,
    required this.trade,
    required this.lat,
    required this.lng,
    required this.address,
    required this.distanceM,
    this.similarMatch = false,
    this.rawTradeLabel = '',
    this.hasCoords = true,
    this.needsReview = false,
  });

  final String id;
  final String name;
  final String trade;
  final double lat;
  final double lng;
  final String address;
  final int distanceM;
  final bool similarMatch;
  final String rawTradeLabel;
  final bool hasCoords;
  final bool needsReview;

  String get matchBadge => needsReview
      ? '분류 확인 필요'
      : similarMatch
          ? '유사 업종 포함'
          : '정확 매칭';

  CompetitorShop copyWith({bool? similarMatch, bool? needsReview}) {
    return CompetitorShop(
      id: id,
      name: name,
      trade: trade,
      lat: lat,
      lng: lng,
      address: address,
      distanceM: distanceM,
      similarMatch: similarMatch ?? this.similarMatch,
      rawTradeLabel: rawTradeLabel,
      hasCoords: hasCoords,
      needsReview: needsReview ?? this.needsReview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trade': trade,
        'lat': lat,
        'lng': lng,
        'address': address,
        'distanceM': distanceM,
        'similarMatch': similarMatch,
        'rawTradeLabel': rawTradeLabel,
        'hasCoords': hasCoords,
        'needsReview': needsReview,
      };

  factory CompetitorShop.fromJson(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble() ?? 0;
    final lng = (map['lng'] as num?)?.toDouble() ?? 0;
    final hasCoords = map.containsKey('hasCoords')
        ? map['hasCoords'] == true
        : lat.abs() >= 0.01 && lng.abs() >= 0.01;
    return CompetitorShop(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      trade: '${map['trade'] ?? ''}',
      lat: lat,
      lng: lng,
      address: '${map['address'] ?? ''}',
      distanceM: (map['distanceM'] as num?)?.round() ?? 0,
      similarMatch: map['similarMatch'] == true,
      rawTradeLabel: '${map['rawTradeLabel'] ?? ''}',
      hasCoords: hasCoords,
      needsReview: map['needsReview'] == true,
    );
  }
}

class RecentPlace {
  const RecentPlace({
    required this.label,
    required this.lat,
    required this.lng,
    this.kind = 'pin',
  });

  final String label;
  final double lat;
  final double lng;
  final String kind;

  Map<String, dynamic> toJson() => {
        'label': label,
        'lat': lat,
        'lng': lng,
        'kind': kind,
      };

  factory RecentPlace.fromJson(Map<String, dynamic> map) {
    return RecentPlace(
      label: '${map['label'] ?? ''}',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      kind: '${map['kind'] ?? 'pin'}',
    );
  }
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.status,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.trade,
    required this.competitors,
    this.population,
    this.footIndex,
    this.marketTrendPct,
    this.shopCountChangePct,
    required this.competitionMeta,
    required this.populationMeta,
    required this.footMeta,
    required this.trendMeta,
    this.addressLabel = '',
    this.errorCode,
    this.httpStatus,
    this.fetchedAt,
    this.userMessage,
    this.cacheKey,
  });

  final MarketDataStatus status;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final String trade;
  final List<CompetitorShop> competitors;
  final int? population;
  final double? footIndex;
  final double? marketTrendPct;
  final double? shopCountChangePct;
  final IndicatorMeta competitionMeta;
  final IndicatorMeta populationMeta;
  final IndicatorMeta footMeta;
  final IndicatorMeta trendMeta;
  final String addressLabel;
  final String? errorCode;
  final int? httpStatus;
  final DateTime? fetchedAt;
  final String? userMessage;
  final String? cacheKey;

  int get competitorCount => competitors
      .where((s) => !s.similarMatch && !s.needsReview && s.hasCoords)
      .length;

  bool get hasRenderableShops =>
      competitors.isNotEmpty && status != MarketDataStatus.unavailable;

  MarketSnapshot copyWithStatus(MarketDataStatus next) {
    return MarketSnapshot(
      status: next,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: competitors,
      population: population,
      footIndex: footIndex,
      marketTrendPct: marketTrendPct,
      shopCountChangePct: shopCountChangePct,
      competitionMeta: competitionMeta,
      populationMeta: populationMeta,
      footMeta: footMeta,
      trendMeta: trendMeta,
      addressLabel: addressLabel,
      errorCode: errorCode,
      httpStatus: httpStatus,
      fetchedAt: fetchedAt,
      userMessage: userMessage,
      cacheKey: cacheKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusKm': radiusKm,
        'trade': trade,
        'competitors': [for (final c in competitors) c.toJson()],
        'population': population,
        'footIndex': footIndex,
        'marketTrendPct': marketTrendPct,
        'shopCountChangePct': shopCountChangePct,
        'competitionMeta': competitionMeta.toJson(),
        'populationMeta': populationMeta.toJson(),
        'footMeta': footMeta.toJson(),
        'trendMeta': trendMeta.toJson(),
        'addressLabel': addressLabel,
        'errorCode': errorCode,
        'httpStatus': httpStatus,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'userMessage': userMessage,
        'cacheKey': cacheKey,
      };

  factory MarketSnapshot.fromJson(Map<String, dynamic> map) {
    final competitors = [
      for (final c in (map['competitors'] as List? ?? const []))
        if (c is Map) CompetitorShop.fromJson(Map<String, dynamic>.from(c)),
    ];
    var status = MarketDataStatus.values.firstWhere(
      (s) => s.name == '${map['status']}',
      orElse: () => MarketDataStatus.unavailable,
    );
    if (status == MarketDataStatus.live && competitors.isEmpty) {
      status = MarketDataStatus.liveEmpty;
    }
    return MarketSnapshot(
      status: status,
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 0,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? 0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 1,
      trade: '${map['trade'] ?? ''}',
      competitors: competitors,
      population: (map['population'] as num?)?.round(),
      footIndex: (map['footIndex'] as num?)?.toDouble(),
      marketTrendPct: (map['marketTrendPct'] as num?)?.toDouble(),
      shopCountChangePct: (map['shopCountChangePct'] as num?)?.toDouble(),
      competitionMeta: map['competitionMeta'] is Map
          ? IndicatorMeta.fromJson(
              Map<String, dynamic>.from(map['competitionMeta'] as Map),
            )
          : const IndicatorMeta(
              source: '',
              periodLabel: '',
              updatedOn: '',
              geoUnit: '',
              available: false,
            ),
      populationMeta: map['populationMeta'] is Map
          ? IndicatorMeta.fromJson(
              Map<String, dynamic>.from(map['populationMeta'] as Map),
            )
          : const IndicatorMeta(
              source: '',
              periodLabel: '',
              updatedOn: '',
              geoUnit: '',
              available: false,
            ),
      footMeta: map['footMeta'] is Map
          ? IndicatorMeta.fromJson(
              Map<String, dynamic>.from(map['footMeta'] as Map),
            )
          : const IndicatorMeta(
              source: '',
              periodLabel: '',
              updatedOn: '',
              geoUnit: '',
              available: false,
            ),
      trendMeta: map['trendMeta'] is Map
          ? IndicatorMeta.fromJson(
              Map<String, dynamic>.from(map['trendMeta'] as Map),
            )
          : const IndicatorMeta(
              source: '',
              periodLabel: '',
              updatedOn: '',
              geoUnit: '',
              available: false,
            ),
      addressLabel: '${map['addressLabel'] ?? ''}',
      errorCode: map['errorCode']?.toString(),
      httpStatus: (map['httpStatus'] as num?)?.round(),
      fetchedAt: DateTime.tryParse('${map['fetchedAt'] ?? ''}'),
      userMessage: map['userMessage']?.toString(),
      cacheKey: map['cacheKey']?.toString(),
    );
  }

  /// 동종 업소 수 / 원면적(km²).
  double get densityPerKm2 {
    final area = mathPi * radiusKm * radiusKm;
    if (area <= 0) return 0;
    return competitorCount / area;
  }

  static const mathPi = 3.141592653589793;
}

abstract final class FieldSurveyChecks {
  static const keys = <String>[
    'price',
    'menu',
    'review',
    'booking',
    'parking',
    'access',
    'traffic',
  ];

  static const labels = <String, String>{
    'price': '가격',
    'menu': '메뉴',
    'review': '리뷰',
    'booking': '예약 방식',
    'parking': '주차',
    'access': '접근성',
    'traffic': '시간대 유동',
  };
}

class MarketCandidate {
  const MarketCandidate({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.trade,
    required this.competitorCount,
    required this.densityPerKm2,
    this.population,
    this.footIndex,
    this.marketTrendPct,
    this.shopCountChangePct,
    this.rentMemo = '',
    this.periodLabel = '',
    this.status = MarketDataStatus.demo,
  });

  final String id;
  final String label;
  final double lat;
  final double lng;
  final double radiusKm;
  final String trade;
  final int competitorCount;
  final double densityPerKm2;
  final int? population;
  final double? footIndex;
  final double? marketTrendPct;
  final double? shopCountChangePct;
  final String rentMemo;
  final String periodLabel;
  final MarketDataStatus status;

  MarketCandidate copyWith({String? rentMemo, String? label}) {
    return MarketCandidate(
      id: id,
      label: label ?? this.label,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitorCount: competitorCount,
      densityPerKm2: densityPerKm2,
      population: population,
      footIndex: footIndex,
      marketTrendPct: marketTrendPct,
      shopCountChangePct: shopCountChangePct,
      rentMemo: rentMemo ?? this.rentMemo,
      periodLabel: periodLabel,
      status: status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'trade': trade,
        'competitorCount': competitorCount,
        'densityPerKm2': densityPerKm2,
        'population': population,
        'footIndex': footIndex,
        'marketTrendPct': marketTrendPct,
        'shopCountChangePct': shopCountChangePct,
        'rentMemo': rentMemo,
        'periodLabel': periodLabel,
        'status': status.name,
      };

  factory MarketCandidate.fromJson(Map<String, dynamic> map) {
    return MarketCandidate(
      id: '${map['id'] ?? ''}',
      label: '${map['label'] ?? ''}',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 1,
      trade: '${map['trade'] ?? MarketTrade.skin}',
      competitorCount: (map['competitorCount'] as num?)?.round() ?? 0,
      densityPerKm2: (map['densityPerKm2'] as num?)?.toDouble() ?? 0,
      population: (map['population'] as num?)?.round(),
      footIndex: (map['footIndex'] as num?)?.toDouble(),
      marketTrendPct: (map['marketTrendPct'] as num?)?.toDouble(),
      shopCountChangePct: (map['shopCountChangePct'] as num?)?.toDouble(),
      rentMemo: '${map['rentMemo'] ?? ''}',
      periodLabel: '${map['periodLabel'] ?? ''}',
      status: MarketDataStatus.values.firstWhere(
        (s) => s.name == '${map['status']}',
        orElse: () => MarketDataStatus.demo,
      ),
    );
  }
}

class InternalPeriodMetrics {
  const InternalPeriodMetrics({
    required this.label,
    required this.revenueKrw,
    required this.visitCount,
    required this.customerCount,
    required this.newCustomerCount,
    required this.returningCustomerCount,
    required this.averageTicketKrw,
    required this.revisitRate,
    required this.nextCareBookRate,
    required this.discountKrw,
    required this.variableCostKrw,
  });

  final String label;
  final int revenueKrw;
  final int visitCount;
  final int customerCount;
  final int newCustomerCount;
  final int returningCustomerCount;
  final int averageTicketKrw;
  final double revisitRate;
  final double nextCareBookRate;
  final int discountKrw;
  final int variableCostKrw;

  int get contributionKrw => revenueKrw - variableCostKrw;

  Map<String, dynamic> toJson() => {
        'label': label,
        'revenueKrw': revenueKrw,
        'visitCount': visitCount,
        'customerCount': customerCount,
        'newCustomerCount': newCustomerCount,
        'returningCustomerCount': returningCustomerCount,
        'averageTicketKrw': averageTicketKrw,
        'revisitRate': revisitRate,
        'nextCareBookRate': nextCareBookRate,
        'discountKrw': discountKrw,
        'variableCostKrw': variableCostKrw,
      };

  factory InternalPeriodMetrics.fromJson(Map<String, dynamic> map) {
    return InternalPeriodMetrics(
      label: '${map['label'] ?? ''}',
      revenueKrw: (map['revenueKrw'] as num?)?.round() ?? 0,
      visitCount: (map['visitCount'] as num?)?.round() ?? 0,
      customerCount: (map['customerCount'] as num?)?.round() ?? 0,
      newCustomerCount: (map['newCustomerCount'] as num?)?.round() ?? 0,
      returningCustomerCount:
          (map['returningCustomerCount'] as num?)?.round() ?? 0,
      averageTicketKrw: (map['averageTicketKrw'] as num?)?.round() ?? 0,
      revisitRate: (map['revisitRate'] as num?)?.toDouble() ?? 0,
      nextCareBookRate: (map['nextCareBookRate'] as num?)?.toDouble() ?? 0,
      discountKrw: (map['discountKrw'] as num?)?.round() ?? 0,
      variableCostKrw: (map['variableCostKrw'] as num?)?.round() ?? 0,
    );
  }
}

class ExternalPeriodMetrics {
  const ExternalPeriodMetrics({
    this.competitorChangePct,
    this.footChangePct,
    this.marketIndexChangePct,
  });

  final double? competitorChangePct;
  final double? footChangePct;
  final double? marketIndexChangePct;
}

class StrategyActionPlan {
  const StrategyActionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueOn,
    required this.successMetric,
    required this.linkedInsight,
    required this.status,
    required this.horizon,
    this.outcomeMemo = '',
    this.outcomeValue,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final ActionPriority priority;
  final DateTime dueOn;
  final String successMetric;
  final String linkedInsight;
  final ActionPlanStatus status;
  final ActionHorizon horizon;
  final String outcomeMemo;
  final double? outcomeValue;
  final DateTime createdAt;

  StrategyActionPlan copyWith({
    ActionPlanStatus? status,
    String? outcomeMemo,
    double? outcomeValue,
    DateTime? dueOn,
  }) {
    return StrategyActionPlan(
      id: id,
      title: title,
      description: description,
      priority: priority,
      dueOn: dueOn ?? this.dueOn,
      successMetric: successMetric,
      linkedInsight: linkedInsight,
      status: status ?? this.status,
      horizon: horizon,
      outcomeMemo: outcomeMemo ?? this.outcomeMemo,
      outcomeValue: outcomeValue ?? this.outcomeValue,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority.name,
        'dueOn': dueOn.toIso8601String(),
        'successMetric': successMetric,
        'linkedInsight': linkedInsight,
        'status': status.name,
        'horizon': horizon.name,
        'outcomeMemo': outcomeMemo,
        'outcomeValue': outcomeValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StrategyActionPlan.fromJson(Map<String, dynamic> map) {
    ActionPriority pri = ActionPriority.mid;
    for (final p in ActionPriority.values) {
      if (p.name == '${map['priority']}') pri = p;
    }
    ActionPlanStatus st = ActionPlanStatus.todo;
    for (final s in ActionPlanStatus.values) {
      if (s.name == '${map['status']}') st = s;
    }
    ActionHorizon hz = ActionHorizon.thisWeek;
    for (final h in ActionHorizon.values) {
      if (h.name == '${map['horizon']}') hz = h;
    }
    return StrategyActionPlan(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      description: '${map['description'] ?? ''}',
      priority: pri,
      dueOn: DateTime.tryParse('${map['dueOn']}') ?? DateTime.now(),
      successMetric: '${map['successMetric'] ?? ''}',
      linkedInsight: '${map['linkedInsight'] ?? ''}',
      status: st,
      horizon: hz,
      outcomeMemo: '${map['outcomeMemo'] ?? ''}',
      outcomeValue: (map['outcomeValue'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? DateTime.now(),
    );
  }
}

class DiagnosisCard {
  const DiagnosisCard({
    required this.id,
    required this.ruleId,
    required this.title,
    required this.observation,
    required this.evidence,
    required this.possibleReading,
    required this.toVerify,
    required this.todayAction,
    required this.weekAction,
    required this.metric30d,
    required this.limitation,
  });

  final String id;
  final String ruleId;
  final String title;
  final String observation;
  final String evidence;
  final String possibleReading;
  final String toVerify;
  final String todayAction;
  final String weekAction;
  final String metric30d;
  final String limitation;
}

class DiagnosisOutcome {
  const DiagnosisOutcome({
    required this.cards,
    required this.missing,
  });

  final List<DiagnosisCard> cards;
  final List<String> missing;

  bool get hasHypothesis => cards.isNotEmpty;
}
