import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/sori_uuid.dart';
import 'market_strategy_models.dart';
import 'target_revenue_calc.dart';

/// 샵+사용자 스코프 로컬 SSOT. Supabase는 Expand 동기화(실패해도 로컬 유지).
class MarketStrategyStore extends ChangeNotifier {
  MarketStrategyStore({required this.shopId, required this.userId});

  final String shopId;
  final String userId;

  TargetRevenueResult? plan;
  List<MarketCandidate> candidates = const [];
  List<StrategyActionPlan> actions = const [];
  InternalPeriodMetrics? currentMetrics;
  InternalPeriodMetrics? previousMetrics;
  ExternalPeriodMetrics? externalMetrics;
  MarketSnapshot? cachedSnapshot;
  List<CompetitorShop> savedRivals = const [];
  List<RecentPlace> recentPlaces = const [];
  Map<String, List<String>> fieldSurvey = const {};
  String placeLabel = '';
  String locationKind = 'pin';
  bool locationConfirmed = false;
  int tabIndex = 0;
  String lastTrade = MarketTrade.skin;
  double lastRadiusKm = 3;
  bool loading = false;
  String? lastError;

  String get _scope {
    final shop = shopId.trim().isEmpty ? 'local-shop' : shopId.trim();
    final user = userId.trim().isEmpty ? 'local-user' : userId.trim();
    return '${shop}__$user';
  }

  String get _key => 'market_strategy_v1_$_scope';

  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      await _pullRemote();
    } catch (e) {
      lastError = 'LOAD_FAILED';
      debugPrint('market_strategy hydrate failed');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> savePlan(TargetRevenueResult result) async {
    plan = result;
    await _persist();
  }

  Future<String> addCandidate(MarketCandidate candidate) async {
    if (candidates.length >= 3) {
      throw TargetRevenueError('MAX_CANDIDATES', '후보는 최대 3곳까지 저장할 수 있습니다.');
    }
    for (final c in candidates) {
      final dLat = (c.lat - candidate.lat).abs();
      final dLng = (c.lng - candidate.lng).abs();
      if (dLat < 0.0007 && dLng < 0.0007) {
        throw TargetRevenueError('DUPLICATE_CANDIDATE', '이미 같은 위치가 후보에 있습니다.');
      }
    }
    final id = candidate.id.trim().isEmpty ? newUuidV4() : candidate.id.trim();
    final saved = MarketCandidate(
      id: id,
      label: candidate.label,
      lat: candidate.lat,
      lng: candidate.lng,
      radiusKm: candidate.radiusKm,
      trade: candidate.trade,
      competitorCount: candidate.competitorCount,
      densityPerKm2: candidate.densityPerKm2,
      population: candidate.population,
      footIndex: candidate.footIndex,
      marketTrendPct: candidate.marketTrendPct,
      shopCountChangePct: candidate.shopCountChangePct,
      rentMemo: candidate.rentMemo,
      periodLabel: candidate.periodLabel,
      status: candidate.status,
    );
    candidates = [...candidates, saved];
    await _persist();
    return id;
  }

  Future<void> updateCandidateMemo(String id, String memo) async {
    candidates = [
      for (final c in candidates)
        if (c.id == id) c.copyWith(rentMemo: memo) else c,
    ];
    await _persist();
  }

  Future<void> removeCandidate(String id) async {
    candidates = [for (final c in candidates) if (c.id != id) c];
    await _persist();
  }

  Future<void> saveMetrics({
    required InternalPeriodMetrics current,
    required InternalPeriodMetrics previous,
    ExternalPeriodMetrics? external,
  }) async {
    currentMetrics = current;
    previousMetrics = previous;
    externalMetrics = external;
    await _persist();
  }

  Future<StrategyActionPlan> addAction(StrategyActionPlan plan) async {
    final item = plan.id.isEmpty
        ? StrategyActionPlan(
            id: newUuidV4(),
            title: plan.title,
            description: plan.description,
            priority: plan.priority,
            dueOn: plan.dueOn,
            successMetric: plan.successMetric,
            linkedInsight: plan.linkedInsight,
            status: plan.status,
            horizon: plan.horizon,
            createdAt: plan.createdAt,
          )
        : plan;
    actions = [item, ...actions];
    await _persist();
    return item;
  }

  Future<void> updateAction(StrategyActionPlan plan) async {
    actions = [
      for (final a in actions)
        if (a.id == plan.id) plan else a,
    ];
    await _persist();
  }

  Future<void> saveRival(CompetitorShop shop) async {
    if (savedRivals.any((s) => s.id == shop.id)) return;
    savedRivals = [...savedRivals, shop];
    await _persist();
  }

  Future<void> cacheSnapshot(MarketSnapshot snapshot) async {
    cachedSnapshot = snapshot;
    await _persist();
  }

  Future<void> rememberPlace({
    required String label,
    required double lat,
    required double lng,
    required String kind,
  }) async {
    placeLabel = label.trim().isEmpty ? '선택한 위치' : label.trim();
    locationKind = kind;
    locationConfirmed = true;
    lastTrade = lastTrade.isEmpty ? MarketTrade.skin : lastTrade;
    recentPlaces = [
      RecentPlace(label: placeLabel, lat: lat, lng: lng, kind: kind),
      ...recentPlaces.where(
        (p) => (p.lat - lat).abs() > 0.0007 || (p.lng - lng).abs() > 0.0007,
      ),
    ].take(8).toList();
    await _persist();
  }

  Future<void> saveUiPrefs({
    String? trade,
    double? radiusKm,
    int? tab,
  }) async {
    if (trade != null) lastTrade = trade;
    if (radiusKm != null) lastRadiusKm = radiusKm;
    if (tab != null) tabIndex = tab;
    await _persist();
  }

  Future<void> toggleSurvey(String candidateId, String checkKey) async {
    final cur = [...(fieldSurvey[candidateId] ?? const <String>[])];
    if (cur.contains(checkKey)) {
      cur.remove(checkKey);
    } else {
      cur.add(checkKey);
    }
    fieldSurvey = {...fieldSurvey, candidateId: cur};
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
    await _pushRemote();
  }

  Map<String, dynamic> _toJson() => {
        'plan': plan?.toJson(),
        'candidates': [for (final c in candidates) c.toJson()],
        'actions': [for (final a in actions) a.toJson()],
        'currentMetrics': currentMetrics?.toJson(),
        'previousMetrics': previousMetrics?.toJson(),
        'externalMetrics': {
          'competitorChangePct': externalMetrics?.competitorChangePct,
          'footChangePct': externalMetrics?.footChangePct,
          'marketIndexChangePct': externalMetrics?.marketIndexChangePct,
        },
        'cachedSnapshot': cachedSnapshot?.toJson(),
        'savedRivals': [for (final s in savedRivals) s.toJson()],
        'recentPlaces': [for (final p in recentPlaces) p.toJson()],
        'fieldSurvey': fieldSurvey,
        'placeLabel': placeLabel,
        'locationKind': locationKind,
        'locationConfirmed': locationConfirmed,
        'tabIndex': tabIndex,
        'lastTrade': lastTrade,
        'lastRadiusKm': lastRadiusKm,
      };

  void _applyJson(Map<String, dynamic> map) {
    final p = map['plan'];
    if (p is Map) {
      plan = TargetRevenueResult.fromJson(Map<String, dynamic>.from(p));
    }
    final cands = map['candidates'];
    if (cands is List) {
      candidates = [
        for (final c in cands)
          if (c is Map) MarketCandidate.fromJson(Map<String, dynamic>.from(c)),
      ];
    }
    final acts = map['actions'];
    if (acts is List) {
      actions = [
        for (final a in acts)
          if (a is Map)
            StrategyActionPlan.fromJson(Map<String, dynamic>.from(a)),
      ];
    }
    final cur = map['currentMetrics'];
    if (cur is Map) {
      currentMetrics =
          InternalPeriodMetrics.fromJson(Map<String, dynamic>.from(cur));
    }
    final prev = map['previousMetrics'];
    if (prev is Map) {
      previousMetrics =
          InternalPeriodMetrics.fromJson(Map<String, dynamic>.from(prev));
    }
    final ext = map['externalMetrics'];
    if (ext is Map) {
      externalMetrics = ExternalPeriodMetrics(
        competitorChangePct: (ext['competitorChangePct'] as num?)?.toDouble(),
        footChangePct: (ext['footChangePct'] as num?)?.toDouble(),
        marketIndexChangePct:
            (ext['marketIndexChangePct'] as num?)?.toDouble(),
      );
    }
    final snap = map['cachedSnapshot'];
    if (snap is Map) {
      cachedSnapshot =
          MarketSnapshot.fromJson(Map<String, dynamic>.from(snap));
    }
    final rivals = map['savedRivals'];
    if (rivals is List) {
      savedRivals = [
        for (final s in rivals)
          if (s is Map) CompetitorShop.fromJson(Map<String, dynamic>.from(s)),
      ];
    }
    final recents = map['recentPlaces'];
    if (recents is List) {
      recentPlaces = [
        for (final p in recents)
          if (p is Map) RecentPlace.fromJson(Map<String, dynamic>.from(p)),
      ];
    }
    final survey = map['fieldSurvey'];
    if (survey is Map) {
      fieldSurvey = {
        for (final e in survey.entries)
          '${e.key}': [
            if (e.value is List) ...[for (final v in e.value as List) '$v'],
          ],
      };
    }
    placeLabel = '${map['placeLabel'] ?? placeLabel}';
    locationKind = '${map['locationKind'] ?? locationKind}';
    locationConfirmed = map['locationConfirmed'] == true || locationConfirmed;
    tabIndex = (map['tabIndex'] as num?)?.round() ?? tabIndex;
    lastTrade = '${map['lastTrade'] ?? lastTrade}';
    lastRadiusKm = (map['lastRadiusKm'] as num?)?.toDouble() ?? lastRadiusKm;
  }

  Future<void> _pullRemote() async {
    if (shopId.trim().isEmpty || userId.trim().isEmpty) return;
    try {
      if (!Supabase.instance.isInitialized) return;
      final client = Supabase.instance.client;
      final requestId = 'req-${Random().nextInt(1 << 32)}';
      final res = await client.functions.invoke(
        'market-strategy',
        body: {
          'action': 'load',
          'shop_id': shopId,
          'request_id': requestId,
        },
      );
      final data = res.data;
      if (data is Map && data['ok'] == true && data['payload'] is Map) {
        _applyJson(Map<String, dynamic>.from(data['payload'] as Map));
      }
    } catch (_) {
      // 로컬 유지. 키/토큰/고객값은 로그하지 않는다.
    }
  }

  Future<void> _pushRemote() async {
    if (shopId.trim().isEmpty || userId.trim().isEmpty) return;
    try {
      if (!Supabase.instance.isInitialized) return;
      final client = Supabase.instance.client;
      final requestId = 'req-${Random().nextInt(1 << 32)}';
      await client.functions.invoke(
        'market-strategy',
        body: {
          'action': 'save',
          'shop_id': shopId,
          'request_id': requestId,
          'payload': _toJson(),
        },
      );
    } catch (_) {}
  }
}
