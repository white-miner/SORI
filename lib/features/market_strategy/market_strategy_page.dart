import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../models/shop.dart';
import '../../services/region_map_gps.dart';
import '../../services/shop_market_service.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tab_indicator.dart';
import '../../theme/sori_tokens.dart';
import '../../widgets/sori_action_buttons.dart';
import 'diagnosis_engine.dart';
import 'market_data_provider.dart';
import 'market_strategy_models.dart';
import 'market_strategy_store.dart';
import 'public_data_client.dart';
import 'target_revenue_calc.dart';

String formatWon(int n) {
  final sign = n < 0 ? '-' : '';
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '$sign$buf원';
}

/// 우리지역 — 요약/지도/비교/전략. 하단 GNB를 늘리지 않는다.
class MarketStrategyPage extends StatefulWidget {
  const MarketStrategyPage({
    super.key,
    required this.store,
    this.provider,
    this.forceDemo = false,
  });

  final SoriStore store;
  final MarketDataProvider? provider;
  final bool forceDemo;

  @override
  State<MarketStrategyPage> createState() => _MarketStrategyPageState();
}

class _MarketStrategyPageState extends State<MarketStrategyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MarketStrategyStore _vault;
  late MarketDataProvider _provider;
  final MapController _mapController = MapController();
  final _summaryScroll = ScrollController();
  final _compareScroll = ScrollController();
  final _strategyScroll = ScrollController();

  final _target = TextEditingController();
  final _fixed = TextEditingController(text: '6000000');
  final _profit = TextEditingController(text: '3000000');
  final _ticket = TextEditingController(text: '90000');
  final _variable = TextEditingController(text: '27000');
  final _days = TextEditingController(text: '25');
  final _actual = TextEditingController();
  final _address = TextEditingController();
  final _rentMemo = TextEditingController();
  final _rate = TextEditingController(text: '30');

  String _trade = MarketTrade.skin;
  double _radiusKm = 3;
  LatLng _center = const LatLng(35.8534, 129.2087);
  MarketSnapshot? _snap;
  bool _mapLoading = false;
  String? _mapError;
  bool _gpsDenied = false;
  final Set<MarketLayer> _layers = {MarketLayer.competition};
  String? _calcError;
  TargetRevenueResult? _preview;
  CompetitorShop? _selected;
  double _mapZoom = 13;
  double _sheetSize = 0.42;
  int _loadGen = 0;
  Timer? _reloadDebounce;
  bool _locationReady = false;
  bool _gpsBusy = false;
  bool _includeSimilar = false;
  bool _useVariableRate = false;
  bool _tilesFailed = false;
  String _sortMode = 'distance';
  String _locationKind = 'pin';
  String _placeLabel = '';
  String? _layerWarn;
  List<({String label, double lat, double lng})> _searchHits = const [];

  Shop get _shop => widget.store.shop;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      unawaited(_vault.saveUiPrefs(tab: _tabs.index));
    });
    _vault = MarketStrategyStore(
      shopId: _shop.id,
      userId: widget.store.session?.id ?? '',
    );
    _provider = widget.provider ??
        (widget.forceDemo || Env.useDemoMarketData
            ? const DemoMarketProvider()
            : PublicMarketProvider(
                shop: _shop,
                readCache: () => _vault.cachedSnapshot,
              ));
    _vault.addListener(_onVault);
    _vault.hydrate().then((_) {
      if (!mounted) return;
      final p = _vault.plan;
      final cached = _vault.cachedSnapshot;
      final skipSetup = widget.forceDemo ||
          widget.provider != null ||
          _vault.locationConfirmed ||
          cached != null;
      setState(() {
        if (p != null) _preview = p;
        if (_vault.lastTrade.isNotEmpty) _trade = _vault.lastTrade;
        if (_vault.lastRadiusKm > 0) _radiusKm = _vault.lastRadiusKm;
        _placeLabel = _vault.placeLabel;
        _locationKind = _vault.locationKind;
        if (cached != null) {
          _center = LatLng(cached.centerLat, cached.centerLng);
          _radiusKm = cached.radiusKm;
          _trade = cached.trade.isEmpty ? _trade : cached.trade;
          if (_placeLabel.isEmpty) _placeLabel = cached.addressLabel;
        }
        _locationReady = skipSetup;
        if (_vault.tabIndex >= 0 && _vault.tabIndex < 4) {
          _tabs.index = _vault.tabIndex;
        }
      });
      if (skipSetup) _reloadMap();
    });
  }

  void _onVault() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vault.removeListener(_onVault);
    _tabs.dispose();
    _summaryScroll.dispose();
    _compareScroll.dispose();
    _strategyScroll.dispose();
    _target.dispose();
    _fixed.dispose();
    _profit.dispose();
    _ticket.dispose();
    _variable.dispose();
    _days.dispose();
    _actual.dispose();
    _address.dispose();
    _rentMemo.dispose();
    _rate.dispose();
    _reloadDebounce?.cancel();
    super.dispose();
  }

  int _n(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(',', '')) ?? 0;

  Future<void> _calculate() async {
    setState(() => _calcError = null);
    try {
      final result = TargetRevenueCalc.compute(
        TargetRevenueInput(
          targetRevenueKrw: _n(_target),
          fixedCostKrw: _n(_fixed),
          targetProfitKrw: _n(_profit),
          averageTicketKrw: _n(_ticket),
          variableCostPerVisitKrw: _useVariableRate ? null : _n(_variable),
          variableRate: _useVariableRate ? _n(_rate) / 100 : null,
          openDaysPerMonth: _n(_days),
          trade: _trade,
        ),
      );
      await _vault.savePlan(result);
      setState(() => _preview = result);
    } on TargetRevenueError catch (e) {
      setState(() => _calcError = '${e.message} (${e.code} · ${e.requestId})');
    }
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), _reloadMap);
  }

  Future<void> _reloadMap() async {
    final gen = ++_loadGen;
    setState(() {
      _mapLoading = true;
      _mapError = null;
    });
    try {
      final snap = await _provider.load(
        lat: _center.latitude,
        lng: _center.longitude,
        radiusKm: _radiusKm,
        trade: _trade,
        addressLabel: _address.text.trim(),
      );
      if (!mounted || gen != _loadGen) return;
      if (snap.status != MarketDataStatus.unavailable) {
        await _vault.cacheSnapshot(snap);
      }
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _snap = snap;
        _mapLoading = false;
        _mapError = snap.status == MarketDataStatus.unavailable
            ? (snap.userMessage ??
                '상권 데이터를 불러오지 못했어요. 주소를 확인한 뒤 다시 시도하세요.')
            : null;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      final cached = _vault.cachedSnapshot;
      setState(() {
        _mapLoading = false;
        if (cached != null) {
          _snap = cached.copyWithStatus(MarketDataStatus.cached);
          _mapError = '인터넷 연결이 없어 저장된 결과를 보여드려요.';
        } else {
          _mapError = '네트워크 연결을 확인한 뒤 다시 시도하세요.';
        }
      });
    }
  }

  Future<void> _confirmPlace({
    required String label,
    required double lat,
    required double lng,
    required String kind,
  }) async {
    setState(() {
      _locationReady = true;
      _center = LatLng(lat, lng);
      _placeLabel = label.trim().isEmpty ? '선택한 위치' : label.trim();
      _locationKind = kind;
      _gpsBusy = false;
      _gpsDenied = false;
      _searchHits = const [];
    });
    await _vault.rememberPlace(
      label: _placeLabel,
      lat: lat,
      lng: lng,
      kind: kind,
    );
    unawaited(_vault.saveUiPrefs(trade: _trade, radiusKm: _radiusKm));
    try {
      _mapController.move(_center, _mapZoom);
    } catch (_) {}
    await _reloadMap();
  }

  Future<void> _searchAddress() async {
    final q = _address.text.trim();
    if (q.isEmpty) {
      setState(() => _mapError = '주소를 입력해 주세요.');
      return;
    }
    setState(() {
      _mapLoading = true;
      _gpsDenied = false;
      _searchHits = const [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'kr',
      });
      final res = await http.get(uri, headers: {'User-Agent': 'sori'});
      if (res.statusCode >= 200 && res.statusCode < 300 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) {
          final hits = <({String label, double lat, double lng})>[];
          for (final row in decoded) {
            if (row is! Map) continue;
            final lat = double.tryParse('${row['lat']}') ?? 0;
            final lng = double.tryParse('${row['lon']}') ?? 0;
            final label = '${row['display_name'] ?? q}'.trim();
            if (lat.abs() < 0.01 || lng.abs() < 0.01) continue;
            hits.add((label: label, lat: lat, lng: lng));
          }
          if (hits.isNotEmpty) {
            setState(() {
              _mapLoading = false;
              _searchHits = hits;
              _mapError = null;
            });
            return;
          }
        }
      }
    } catch (_) {}
    try {
      final n =
          await ShopMarketService.instance.resolveNeighborhoodFromAddress(q);
      if (n != null && n.latitude.abs() > 0.01) {
        await _confirmPlace(
          label: n.displayLabel.isNotEmpty ? n.displayLabel : q,
          lat: n.latitude,
          lng: n.longitude,
          kind: 'address',
        );
        return;
      }
    } catch (_) {}
    setState(() {
      _mapLoading = false;
      _searchHits = const [];
      _mapError = '검색 결과가 없어요. 검색어를 바꾸거나 지도 핀을 옮긴 뒤 「이 위치로 분석」을 누르세요.';
    });
  }

  Future<void> _useGps() async {
    setState(() {
      _gpsDenied = false;
      _gpsBusy = true;
      _mapError = null;
    });
    final result = await RegionMapGps.oneShot();
    if (!mounted || !_gpsBusy) return;
    if (result.outcome != RegionMapGpsOutcome.ok ||
        result.lat == null ||
        result.lng == null) {
      setState(() {
        _gpsBusy = false;
        _gpsDenied = result.outcome == RegionMapGpsOutcome.denied;
        if (!_gpsDenied) {
          _mapError =
              '위치를 읽지 못했습니다. 위치 서비스를 켜거나 주소 검색으로 계속하세요.';
        }
        _locationReady = true;
      });
      _tabs.animateTo(1);
      return;
    }
    await _confirmPlace(
      label: '현재 위치',
      lat: result.lat!,
      lng: result.lng!,
      kind: 'gps',
    );
  }

  void _cancelGps() {
    setState(() {
      _gpsBusy = false;
      _locationReady = true;
    });
    _tabs.animateTo(1);
  }

  void _toggleLayer(MarketLayer layer) {
    setState(() {
      if (_layers.contains(layer)) {
        _layers.remove(layer);
        _layerWarn = null;
      } else {
        if (_layers.length >= 2) {
          _layers.remove(_layers.first);
          _layerWarn = '지도 레이어는 한 번에 2개까지입니다. 겹치면 읽기 어렵습니다.';
        } else {
          _layerWarn = null;
        }
        _layers.add(layer);
      }
    });
  }

  Future<void> _saveCandidate() async {
    final snap = _snap;
    if (snap == null) return;
    try {
      await _vault.addCandidate(
        MarketCandidate(
          id: '',
          label: _displayPlace(),
          lat: _center.latitude,
          lng: _center.longitude,
          radiusKm: _radiusKm,
          trade: _trade,
          competitorCount: snap.competitorCount,
          densityPerKm2: snap.densityPerKm2,
          population: snap.population,
          footIndex: snap.footIndex,
          marketTrendPct: snap.marketTrendPct,
          shopCountChangePct: snap.shopCountChangePct,
          rentMemo: _rentMemo.text.trim(),
          periodLabel: snap.competitionMeta.periodLabel,
          status: snap.status,
        ),
      );
      await _vault.rememberPlace(
        label: _displayPlace(),
        lat: _center.latitude,
        lng: _center.longitude,
        kind: 'candidate',
      );
      setState(() => _locationKind = 'candidate');
      if (mounted) _tabs.animateTo(2);
    } on TargetRevenueError catch (e) {
      setState(() => _mapError = e.message);
    }
  }

  Future<void> _createChecklistActions() async {
    final now = DateTime.now();
    await _vault.addAction(
      StrategyActionPlan(
        id: '',
        title: '가까운 동종 업소 5곳 현장 조사',
        description: '서비스·가격·리뷰·예약 방식을 적어 비교하세요. 우열을 단정하지 않습니다.',
        priority: ActionPriority.high,
        dueOn: now.add(const Duration(days: 7)),
        successMetric: '조사 5곳 완료',
        linkedInsight: '후보지 비교',
        status: ActionPlanStatus.todo,
        horizon: ActionHorizon.thisWeek,
        createdAt: now,
      ),
    );
    if (mounted) _tabs.animateTo(3);
  }

  Future<void> _saveRival(CompetitorShop shop) async {
    await _vault.saveRival(shop);
    if (!mounted) return;
    setState(() => _selected = null);
  }

  Future<void> _openNaverMap(CompetitorShop shop) async {
    final q = Uri.encodeQueryComponent('${shop.name} ${shop.address}'.trim());
    final uri = Uri.parse('https://map.naver.com/p/search/$q');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _mapError = '네이버지도를 열지 못했습니다. 목록에서 주소를 확인하세요.');
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '위치·업종·반경 선택',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: '필터 닫기',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              _tradeChips(),
              Wrap(
                spacing: 6,
                children: [
                  for (final km in const [1.0, 3.0, 5.0, 10.0])
                    ChoiceChip(
                      label: Text('${km.toInt()}km 반경'),
                      selected: _radiusKm == km,
                      onSelected: (_) {
                        setState(() => _radiusKm = km);
                        unawaited(_vault.saveUiPrefs(radiusKm: km, trade: _trade));
                        Navigator.pop(ctx);
                        _reloadMap();
                      },
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '선택 반경은 요청값입니다. 원천 API가 더 짧게 자르면 경쟁 밀도는 실제 조회 반경으로 계산합니다.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
              if (_vault.recentPlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('최근 위치', style: TextStyle(fontWeight: FontWeight.w800)),
                for (final p in _vault.recentPlaces)
                  ListTile(
                    dense: true,
                    title: Text(p.label),
                    subtitle: Text(_kindLabel(p.kind)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmPlace(
                        label: p.label,
                        lat: p.lat,
                        lng: p.lng,
                        kind: p.kind,
                      );
                    },
                  ),
              ],
              const SizedBox(height: 8),
              SoriPrimaryButton(
                label: '이 조건으로 상권 다시 조회',
                onPressed: () {
                  Navigator.pop(ctx);
                  _reloadMap();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadSampleDiagnosis() async {
    await _vault.saveMetrics(
      current: const InternalPeriodMetrics(
        label: '최근 30일',
        revenueKrw: 16200000,
        visitCount: 180,
        customerCount: 180,
        newCustomerCount: 48,
        returningCustomerCount: 132,
        averageTicketKrw: 90000,
        revisitRate: 0.62,
        nextCareBookRate: 0.28,
        discountKrw: 900000,
        variableCostKrw: 5400000,
      ),
      previous: const InternalPeriodMetrics(
        label: '직전 30일',
        revenueKrw: 19800000,
        visitCount: 220,
        customerCount: 220,
        newCustomerCount: 70,
        returningCustomerCount: 150,
        averageTicketKrw: 90000,
        revisitRate: 0.68,
        nextCareBookRate: 0.41,
        discountKrw: 400000,
        variableCostKrw: 5200000,
      ),
      external: const ExternalPeriodMetrics(
        competitorChangePct: 8,
        footChangePct: -6,
        marketIndexChangePct: -3,
      ),
    );
  }

  Future<void> _actionsFromDiagnosis(DiagnosisCard card) async {
    final now = DateTime.now();
    await _vault.addAction(
      StrategyActionPlan(
        id: '',
        title: card.todayAction,
        description: card.possibleReading,
        priority: ActionPriority.high,
        dueOn: now,
        successMetric: card.metric30d,
        linkedInsight: card.title,
        status: ActionPlanStatus.todo,
        horizon: ActionHorizon.today,
        createdAt: now,
      ),
    );
    await _vault.addAction(
      StrategyActionPlan(
        id: '',
        title: card.weekAction,
        description: card.toVerify,
        priority: ActionPriority.mid,
        dueOn: now.add(const Duration(days: 7)),
        successMetric: card.metric30d,
        linkedInsight: card.title,
        status: ActionPlanStatus.todo,
        horizon: ActionHorizon.thisWeek,
        createdAt: now,
      ),
    );
    if (mounted) _tabs.animateTo(3);
  }

  String _statusLabel(MarketDataStatus s) => switch (s) {
        MarketDataStatus.live => 'LIVE',
        MarketDataStatus.liveEmpty => 'LIVE_EMPTY',
        MarketDataStatus.cached => 'CACHED',
        MarketDataStatus.stale => 'STALE',
        MarketDataStatus.demo => 'DEMO',
        MarketDataStatus.unavailable => 'UNAVAILABLE',
      };

  String _layerLabel(MarketLayer layer) => switch (layer) {
        MarketLayer.competition => '경쟁',
        MarketLayer.population => '인구',
        MarketLayer.footTraffic => '유동',
        MarketLayer.marketTrend => '추이',
      };

  String _kindLabel(String kind) => switch (kind) {
        'shop' => '매장 기준',
        'candidate' => '후보지 기준',
        'gps' => '현재 위치',
        'address' => '검색 위치',
        _ => '지도 핀',
      };

  String _displayPlace() {
    if (_placeLabel.trim().isNotEmpty) return _placeLabel.trim();
    final snap = _snap?.addressLabel.trim() ?? '';
    if (snap.isNotEmpty) return snap;
    final addr = _shop.address?.trim() ?? '';
    if (addr.isNotEmpty && _locationKind == 'shop') return addr;
    return '선택한 위치';
  }

  List<CompetitorShop> _visibleShops(MarketSnapshot? snap) {
    if (snap == null || snap.status == MarketDataStatus.unavailable) {
      return const [];
    }
    var list = snap.competitors;
    if (!_includeSimilar) {
      list = [for (final s in list) if (!s.similarMatch) s];
    }
    final copy = [...list];
    copy.sort((a, b) {
      if (a.hasCoords != b.hasCoords) return a.hasCoords ? -1 : 1;
      switch (_sortMode) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'similar':
          return (a.similarMatch == b.similarMatch)
              ? a.distanceM.compareTo(b.distanceM)
              : (a.similarMatch ? 1 : -1);
        default:
          return a.distanceM.compareTo(b.distanceM);
      }
    });
    return copy;
  }

  Widget _buildLocationSetup() {
    final shopLat = _shop.latitude;
    final shopLng = _shop.longitude;
    final hasShop = shopLat != null &&
        shopLng != null &&
        shopLat.abs() > 0.01 &&
        shopLng.abs() > 0.01;
    return ListView(
      key: const Key('our-area-setup'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text(
          '우리지역을 설정하세요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 8),
        const Text('매장 또는 후보지 주변 경쟁을 확인할 수 있어요.'),
        const SizedBox(height: 20),
        if (_gpsBusy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('위치를 찾고 있습니다.'),
          TextButton(onPressed: _cancelGps, child: const Text('취소하고 주소로 찾기')),
          const SizedBox(height: 12),
        ],
        SoriPrimaryButton(
          key: const Key('setup-gps'),
          label: '현재 위치로 시작',
          onPressed: _gpsBusy ? null : _useGps,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('setup-address'),
          onPressed: () {
            setState(() => _locationReady = true);
            _tabs.animateTo(1);
          },
          child: const SizedBox(
            height: 48,
            child: Center(child: Text('주소로 찾기')),
          ),
        ),
        if (hasShop) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _confirmPlace(
              label: (_shop.address ?? _shop.name).trim().isEmpty
                  ? '매장 위치'
                  : (_shop.address ?? _shop.name),
              lat: shopLat,
              lng: shopLng,
              kind: 'shop',
            ),
            child: const SizedBox(
              height: 48,
              child: Center(child: Text('매장 위치로 시작')),
            ),
          ),
        ],
        TextButton(
          key: const Key('setup-later'),
          onPressed: () {
            setState(() => _locationReady = true);
          },
          child: const Text('나중에 설정하기'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.store.session;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('우리지역'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _locationReady
                    ? '${_kindLabel(_locationKind)} · ${_displayPlace()}'
                    : '분석할 위치를 정하세요',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _openFilterSheet,
            child: const Text('위치 변경'),
          ),
        ],
      ),
      body: !_locationReady
          ? _buildLocationSetup()
          : Column(
              children: [
                Material(
                  color: SoriTokens.surface,
                  child: SoriYoutubeTabBar(
                    controller: _tabs,
                    labels: const ['요약', '지도', '비교', '전략'],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _Keep(_buildSummary()),
                      _Keep(_buildMap()),
                      _Keep(_buildCompare()),
                      _Keep(_buildStrategy()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummary() {
    final snap = _snap;
    final plan = _preview ?? _vault.plan;
    final tradeLabel = MarketTrade.labelOf(_trade);
    final shownKm = (snap?.radiusKm ?? _radiusKm).toInt();
    final locLabel = '${_kindLabel(_locationKind)} · ${_displayPlace()}';
    final liveLine = snap == null || _mapLoading
        ? '위치를 확인한 뒤 주변 업소를 불러옵니다.'
        : snap.status == MarketDataStatus.unavailable
            ? '상권 데이터를 불러오지 못했어요'
            : snap.status == MarketDataStatus.liveEmpty
                ? '조건에 맞는 업소를 찾지 못했어요'
                : snap.hasRenderableShops
                    ? (snap.competitorCount > 0
                        ? '$shownKm km 반경 이 응답에서 $tradeLabel ${snap.competitorCount}곳'
                        : '$shownKm km 반경 이 응답에서 유사 포함 ${snap.competitors.length}곳')
                    : '경쟁 업소 데이터를 아직 표시할 수 없습니다.';
    final densityLine = snap == null ||
            snap.status == MarketDataStatus.unavailable ||
            snap.status == MarketDataStatus.liveEmpty ||
            !snap.hasRenderableShops
        ? '경쟁 밀도: 데이터 없음'
        : snap.competitorCount == 0
            ? '경쟁 밀도: 유사 업종은 밀도에 넣지 않아요'
            : '면적당 ${snap.densityPerKm2.toStringAsFixed(1)}곳/km² · 요청 반경 ${shownKm}km';
    final priority = snap == null
        ? const <DiagnosisCard>[]
        : DiagnosisEngine.areaPriority(snap: snap, plan: plan);
    final primary = _summaryPrimary(
      snap: snap,
      plan: plan,
      priority: priority,
    );

    return ListView(
      key: const Key('market-summary-list'),
      controller: _summaryScroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _statusBanner(snap),
        Semantics(
          header: true,
          child: Text(
            liveLine,
            key: const Key('our-area-headline'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          key: const Key('our-area-context'),
          '$locLabel · $tradeLabel · ${shownKm}km · ${_statusLabel(snap?.status ?? MarketDataStatus.unavailable)}',
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
        ),
        Text(densityLine),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const Key('pill-place'),
              label: Text(_displayPlace()),
              onPressed: _openFilterSheet,
            ),
            ActionChip(
              key: const Key('pill-trade'),
              label: Text(tradeLabel),
              onPressed: _openFilterSheet,
            ),
            ActionChip(
              key: const Key('pill-radius'),
              label: Text('${shownKm}km'),
              onPressed: _openFilterSheet,
            ),
          ],
        ),
        if (snap != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('our-area-provenance'),
              onPressed: _openProvenance,
              child: const Text('출처·기간·단위 보기'),
            ),
          ),
        if (plan != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '목표를 맞추려면 하루 평균 ${plan.dailyVisits}명, 월 ${plan.monthlyVisits}회가 필요합니다. 이 숫자가 매출을 보장하지는 않습니다.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.35),
            ),
          )
        else
          _hint('목표 매출을 고객 수로 바꿔보세요. 목표와 객단가를 입력하면 하루 필요 방문을 계산해요.'),
        SizedBox(
          height: 48,
          child: SoriPrimaryButton(
            key: const Key('our-area-primary-cta'),
            label: primary.label,
            onPressed: primary.onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _verbButton('경쟁 지도 보기', () => _tabs.animateTo(1)),
            _verbButton('전략 보기', () => _tabs.animateTo(3)),
          ],
        ),
        if (snap?.status == MarketDataStatus.liveEmpty) ...[
          const SizedBox(height: 8),
          _hint('반경을 넓히거나 업종을 바꿔보세요.'),
          _verbButton('반경 바꾸기', _openFilterSheet),
          _verbButton('주소로 찾기', () => _tabs.animateTo(1)),
        ],
        _card(
          title: '오늘의 우선 행동',
          body: priority.isEmpty
              ? '먼저 지역 또는 목표를 설정하세요. 데이터가 쌓이면 실행할 행동을 정리해드려요.'
              : priority.first.todayAction,
          cta: priority.isEmpty ? '우리지역 설정' : '실행계획에 추가',
          onTap: priority.isEmpty
              ? _openFilterSheet
              : () => _actionsFromDiagnosis(priority.first),
        ),
        _card(
          title: '지역 수요',
          body: snap?.populationMeta.available == true
              ? '주거 인구 ${snap!.population}명 · 행정동 집계 참고'
              : (snap?.populationMeta.nextAction ??
                  '제공 데이터 없음. 선택 위치의 행정동 인구 기준을 확인하지 못했어요.'),
          cta: '근거 보기',
          onTap: _openProvenance,
        ),
        _card(
          title: '지역·업종 매출 수준',
          body: snap?.trendMeta.available == true
              ? '시장 추이 ${snap!.marketTrendPct}%'
              : (snap?.trendMeta.nextAction ??
                  '제공 데이터 없음. 선택 업종의 공식 지역 매출 비교 기준을 확인하지 못했어요.'),
          cta: '근거 보기',
          onTap: _openProvenance,
        ),
        const SizedBox(height: 16),
        _hint('한 달에 얼마를 벌고 싶은지부터 넣고, 하루 업무량으로 번역합니다. 가정일 뿐 매출을 보장하지 않습니다.'),
        _moneyField(_target, '한 달에 얼마를 벌고 싶은가?(원)', 'target-revenue'),
        _moneyField(_ticket, '고객 한 명 평균 결제(원)', 'ticket'),
        _moneyField(_days, '한 달에 며칠 일하는가?(1–31)', 'open-days', isDays: true),
        _moneyField(_actual, '최근 월 실제 방문(회, 선택)', 'actual-visits'),
        _moneyField(_fixed, '월 고정비(원) · 임대료·인건비 등', 'fixed-cost'),
        _moneyField(_profit, '목표 이익(원) · 매출과 다른 숫자', 'target-profit'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('변동비를 비율로 입력'),
          value: _useVariableRate,
          onChanged: (v) => setState(() => _useVariableRate = v),
        ),
        if (_useVariableRate)
          _moneyField(_rate, '변동비율(%)', 'variable-rate')
        else
          _moneyField(_variable, '방문당 변동비(원)', 'variable'),
        if (_calcError != null) _errorBox(_calcError!),
        if (plan != null) _resultCard(plan),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('market-calc'),
          onPressed: _calculate,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(plan == null ? '목표 매출 계산하기' : '목표 다시 계산하기'),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _openCalcBasis,
            child: const Text('계산 기준 보기'),
          ),
        ),
      ],
    );
  }

  ({String label, VoidCallback onPressed}) _summaryPrimary({
    required MarketSnapshot? snap,
    required TargetRevenueResult? plan,
    required List<DiagnosisCard> priority,
  }) {
    if (snap?.status == MarketDataStatus.unavailable) {
      return (label: '다시 시도', onPressed: _reloadMap);
    }
    if (snap?.status == MarketDataStatus.liveEmpty) {
      return (label: '반경 바꾸기', onPressed: _openFilterSheet);
    }
    if (plan == null) {
      return (
        label: '목표 매출 계산',
        onPressed: () => _summaryScroll.animateTo(
          _summaryScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        ),
      );
    }
    if (priority.isNotEmpty) {
      return (
        label: '오늘 할 일 실행계획에 넣기',
        onPressed: () => _actionsFromDiagnosis(priority.first),
      );
    }
    return (label: '경쟁 지도 보기', onPressed: () => _tabs.animateTo(1));
  }

  Future<void> _openProvenance() async {
    final snap = _snap;
    if (snap == null || !mounted) return;
    final m = snap.competitionMeta;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '데이터 출처',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('상태 ${_statusLabel(snap.status)}'),
              Text('출처 ${m.source.isEmpty ? '없음' : m.source}'),
              Text('기간 ${m.periodLabel.isEmpty ? '없음' : m.periodLabel}'),
              Text('갱신 ${m.updatedOn.isEmpty ? '없음' : m.updatedOn}'),
              Text('공간 단위 ${m.geoUnit.isEmpty ? '없음' : m.geoUnit}'),
              Text('업종 매핑 ${MarketTrade.labelOf(snap.trade)}'),
              const SizedBox(height: 8),
              const Text(
                '공공 상가업소 데이터를 바탕으로 표시됩니다. 업소의 영업 상태·업종·주소·좌표는 실제 현황과 다를 수 있습니다. 개별 업체의 매출이나 예약 가능 여부는 제공하지 않습니다.',
              ),
              const SizedBox(height: 8),
              Text(
                '인구 ${snap.populationMeta.available ? snap.populationMeta.source : '제공 데이터 없음'} · ${snap.populationMeta.geoUnit}',
              ),
              Text(
                '매출 수준 제공 데이터 없음 · 매출 20분위 원자료 없음 · 시군구 가동사업자 수는 API 명세 확인 전 미연결',
              ),
              if (m.comparisonWarning != null) Text('한계 ${m.comparisonWarning}'),
              if (m.nextAction != null) Text('다음 ${m.nextAction}'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCalcBasis() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '계산 기준',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('공헌이익 = 객단가 − 방문당 변동비'),
              const Text('필요 매출 = (고정비 + 목표 이익) ÷ 공헌이익률'),
              const Text('월 방문 = (고정비 + 목표 이익) ÷ 공헌이익, 올림'),
              const Text('하루 방문 = 월 방문 ÷ 영업일, 올림'),
              const Text('이 숫자는 가정이며 매출이나 좋은 상권을 보장하지 않습니다.'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    final snap = _snap;
    final shops = _visibleShops(snap);
    final withCoords = [for (final s in shops) if (s.hasCoords) s];
    final clusters = _cluster(withCoords, _mapZoom);
    final prev = StoreLoadAudit.last;
    if (prev != null && prev.renderedMarkerCount != clusters.length) {
      prev
          .copyWith(
            renderedMarkerCount: clusters.length,
            coincidentCoordGroups: _coincidentGroups(withCoords),
          )
          .debugDump();
    }
    return Column(
      children: [
        _statusBanner(snap),
        _storeAuditStrip(),
        if (_gpsDenied)
          _banner(
            '주소로 지역을 찾아볼 수 있어요',
            '위치 권한 없이도 동네를 검색할 수 있어요.',
            SoriTokens.semanticYellow,
          ),
        if (_mapError != null)
          _banner('조회 실패', _mapError!, SoriTokens.systemRed),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: '동네 또는 주소 검색',
                        hintText: '예: 경주시 성건동',
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '주소로 상권 찾기',
                      onPressed: _searchAddress,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '현재 위치로 상권 보기',
                      onPressed: _useGps,
                      icon: const Icon(Icons.my_location),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '업종·반경 필터 열기',
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '데이터 ${_statusLabel(snap?.status ?? MarketDataStatus.unavailable)} · 레이어 ${_layers.length}/2',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final layer in MarketLayer.values)
                    FilterChip(
                      label: Text(_layerLabel(layer)),
                      selected: _layers.contains(layer),
                      onSelected: (_) => _toggleLayer(layer),
                    ),
                ],
              ),
              if (_layerWarn != null)
                Text(_layerWarn!, style: const TextStyle(fontSize: 12)),
              if (_gpsBusy)
                Row(
                  children: [
                    const Expanded(child: LinearProgressIndicator()),
                    TextButton(onPressed: _cancelGps, child: const Text('취소')),
                  ],
                ),
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    label: const Text('정확 매칭만'),
                    selected: !_includeSimilar,
                    onSelected: (_) => setState(() => _includeSimilar = false),
                  ),
                  FilterChip(
                    label: const Text('유사 업종 포함'),
                    selected: _includeSimilar,
                    onSelected: (_) => setState(() => _includeSimilar = true),
                  ),
                  ChoiceChip(
                    label: const Text('거리순'),
                    selected: _sortMode == 'distance',
                    onSelected: (_) => setState(() => _sortMode = 'distance'),
                  ),
                  ChoiceChip(
                    label: const Text('이름순'),
                    selected: _sortMode == 'name',
                    onSelected: (_) => setState(() => _sortMode = 'name'),
                  ),
                  ChoiceChip(
                    label: const Text('유사도순'),
                    selected: _sortMode == 'similar',
                    onSelected: (_) => setState(() => _sortMode = 'similar'),
                  ),
                ],
              ),
              if (_searchHits.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView(
                    children: [
                      for (final h in _searchHits)
                        ListTile(
                          dense: true,
                          title: Text(h.label, maxLines: 2),
                          onTap: () => _confirmPlace(
                            label: h.label.split(',').first,
                            lat: h.lat,
                            lng: h.lng,
                            kind: 'address',
                          ),
                        ),
                    ],
                  ),
                ),
              if (_tilesFailed)
                const Text('지도를 그리지 못했습니다. 아래 목록으로 같은 업소를 확인할 수 있습니다.'),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxHeight;
              const minMap = 80.0;
              final maxSheet = (available - minMap).clamp(140.0, available);
              final sheetH = (available * _sheetSize.clamp(0.28, 0.82))
                  .clamp(140.0, maxSheet);
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _mapZoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                        onPositionChanged: (cam, _) {
                          final z = cam.zoom;
                          if ((z - _mapZoom).abs() > 0.2) {
                            setState(() => _mapZoom = z);
                          }
                        },
                        onTap: (_, p) {
                          setState(() {
                            _center = p;
                            _selected = null;
                          });
                          _scheduleReload();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'sori',
                          errorTileCallback: (_, _, _) {
                            if (!_tilesFailed && mounted) {
                              setState(() => _tilesFailed = true);
                            }
                          },
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _center,
                              radius: _radiusKm * 1000,
                              useRadiusInMeter: true,
                              color: SoriTokens.semanticBlue
                                  .withValues(alpha: 0.12),
                              borderStrokeWidth: 2,
                              borderColor: SoriTokens.semanticBlue,
                            ),
                          ],
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: _center,
                            width: 28,
                            height: 28,
                            child: const Icon(Icons.flag, color: SoriTokens.brand),
                          ),
                          if (_layers.contains(MarketLayer.competition))
                            ..._clusterMarkers(clusters),
                        ]),
                        RichAttributionWidget(
                          attributions: const [
                            TextSourceAttribution('© OpenStreetMap'),
                          ],
                        ),
                      ],
                    ),
              Positioned(
                right: 8,
                top: 8 + MediaQuery.paddingOf(context).top,
                child: Column(
                  children: [
                    _mapCtrl(
                      tooltip: '지도 확대',
                      icon: Icons.add,
                      onTap: () {
                        _mapZoom = (_mapZoom + 1).clamp(5, 18);
                        _mapController.move(_center, _mapZoom);
                        setState(() {});
                      },
                    ),
                    _mapCtrl(
                      tooltip: '지도 축소',
                      icon: Icons.remove,
                      onTap: () {
                        _mapZoom = (_mapZoom - 1).clamp(5, 18);
                        _mapController.move(_center, _mapZoom);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              if (_mapLoading)
                const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: sheetH,
                    child: Material(
            elevation: 8,
            child: Column(
              children: [
                GestureDetector(
                  onVerticalDragUpdate: (d) {
                    final h = MediaQuery.sizeOf(context).height;
                    setState(() {
                      _sheetSize = (_sheetSize - d.delta.dy / h).clamp(0.35, 0.92);
                    });
                  },
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SoriTokens.textTertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          snap == null
                              ? '목록을 불러오는 중'
                              : snap.status == MarketDataStatus.unavailable
                                  ? '공공 데이터를 불러오지 못했습니다 · ${_statusLabel(snap.status)}'
                                  : snap.hasRenderableShops
                                      ? '동종 ${snap.competitorCount}곳 · ${snap.radiusKm.toInt()}km · 면적당 ${snap.densityPerKm2.toStringAsFixed(1)}곳/km² · ${_statusLabel(snap.status)}'
                                      : '동종 업소 없음 · 업종/반경을 바꿔 조회 · ${_statusLabel(snap.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        key: const Key('shop-list-toggle'),
                        onPressed: () => setState(
                          () => _sheetSize = _sheetSize < 0.7 ? 0.9 : 0.42,
                        ),
                        child: Text(_sheetSize < 0.7 ? '목록 보기' : '목록 접기'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const Key('shop-sheet-scroll'),
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '© OpenStreetMap · 지도 핀 대신 아래 목록으로도 같은 업소를 열 수 있습니다.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ),
                      if (shops.any((s) => !s.hasCoords))
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '지도에 표시되지 않은 업소가 있을 수 있어요',
                              style: TextStyle(fontSize: 12, height: 1.3),
                            ),
                          ),
                        ),
                      if (snap != null &&
                          _layers.contains(MarketLayer.population))
                        _metricOrMissing(
                          '주거 인구',
                          snap.population,
                          snap.populationMeta,
                          suffix: '명',
                        ),
                      if (snap != null &&
                          _layers.contains(MarketLayer.footTraffic))
                        _metricOrMissing(
                          '유동 지수',
                          snap.footIndex?.round(),
                          snap.footMeta,
                        ),
                      if (snap != null &&
                          _layers.contains(MarketLayer.marketTrend))
                        _metricOrMissing(
                          '시장 추이',
                          snap.marketTrendPct,
                          snap.trendMeta,
                          suffix: '%',
                        ),
                      if (shops.isEmpty) ...[
                        _empty(
                          snap?.status == MarketDataStatus.unavailable
                              ? '상권 데이터를 불러오지 못했어요'
                              : snap?.status == MarketDataStatus.liveEmpty
                                  ? '조건에 맞는 업소를 찾지 못했어요'
                                  : '목록이 비어 있습니다',
                          snap?.status == MarketDataStatus.unavailable
                              ? '연결을 확인한 뒤 다시 시도하세요.'
                              : '반경을 넓히거나 업종을 바꿔보세요.',
                        ),
                        if (snap?.status == MarketDataStatus.unavailable)
                          TextButton(
                            onPressed: _reloadMap,
                            child: const Text('다시 시도'),
                          ),
                        if (snap?.status == MarketDataStatus.liveEmpty)
                          TextButton(
                            onPressed: _openFilterSheet,
                            child: const Text('반경 바꾸기'),
                          ),
                      ],
                      if (shops.isNotEmpty)
                        for (final s in shops)
                          ListTile(
                            selected: _selected?.id == s.id,
                            title: Text(
                              s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${s.matchBadge} · ${MarketTrade.labelOf(s.trade)} · ${s.hasCoords ? '${s.distanceM}m' : '지도 좌표 없음'} · ${s.address}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            onTap: () => setState(() => _selected = s),
                            trailing: IconButton(
                              tooltip: '경쟁 조사에 저장',
                              onPressed: () => _saveRival(s),
                              icon: const Icon(Icons.bookmark_add_outlined),
                            ),
                          ),
                      if (_selected != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selected!.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _selected = null),
                                    child: const Text('선택 닫기'),
                                  ),
                                ],
                              ),
                              Text(
                                '${_selected!.matchBadge} · ${MarketTrade.labelOf(_selected!.trade)} · ${_selected!.hasCoords ? '${_selected!.distanceM}m' : '지도 좌표 없음'}',
                              ),
                              Text(
                                _selected!.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '데이터 기준 ${_snap?.competitionMeta.source ?? ''} · ${_snap?.fetchedAt?.toIso8601String().split('T').first ?? ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: () => _saveRival(_selected!),
                                child: const SizedBox(
                                  height: 48,
                                  child: Center(child: Text('경쟁 조사에 저장')),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openNaverMap(_selected!),
                                child: const Text('네이버지도에서 보기'),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _rentMemo,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: '임대료·주차·접근성 메모',
                              ),
                            ),
                            const SizedBox(height: 6),
                            SoriPrimaryButton(
                              key: const Key('save-candidate'),
                              label: '비교에 추가',
                              onPressed: _saveCandidate,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: OutlinedButton(
                    key: const Key('analyze-here'),
                    onPressed: () => _confirmPlace(
                      label: _displayPlace() == '선택한 위치'
                          ? '지도에서 고른 위치'
                          : _displayPlace(),
                      lat: _center.latitude,
                      lng: _center.longitude,
                      kind: _locationKind == 'shop' ? 'shop' : 'pin',
                    ),
                    child: const SizedBox(
                      height: 48,
                      child: Center(child: Text('이 위치로 분석')),
                    ),
                  ),
                ),
              ],
            ),
          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Marker> _clusterMarkers(List<_Cluster> clusters) {
    return [
      for (final c in clusters)
        Marker(
          key: ValueKey(
            c.shop?.id.isNotEmpty == true
                ? 'store-${c.shop!.id}'
                : 'cluster-${c.center.latitude}-${c.center.longitude}-${c.count}',
          ),
          point: c.center,
          width: c.count > 1 ? 36 : 22,
          height: c.count > 1 ? 36 : 22,
          child: Tooltip(
            message: c.count > 1
                ? '업소 ${c.count}곳 묶음. 확대해 개별 위치를 보세요.'
                : '${c.shop!.name} · ${MarketTrade.labelOf(c.shop!.trade)} · ${c.shop!.distanceM}m',
            child: GestureDetector(
              onTap: () {
                if (c.count > 1) {
                  _mapZoom = (_mapZoom + 2).clamp(5, 18);
                  _mapController.move(c.center, _mapZoom);
                  setState(() {});
                  return;
                }
                setState(() => _selected = c.shop);
              },
              child: c.count > 1
                  ? CircleAvatar(
                      backgroundColor: SoriTokens.brand,
                      child: Text(
                        '${c.count}',
                        style: const TextStyle(
                          color: SoriTokens.onBrand,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.storefront,
                      size: 18,
                      color: _selected?.id == c.shop?.id
                          ? SoriTokens.brand
                          : SoriTokens.primary,
                    ),
            ),
          ),
        ),
    ];
  }

  List<_Cluster> _cluster(List<CompetitorShop> shops, double zoom) {
    // zoom은 호출부가 넘긴다. 클러스터 합침은 쓰지 않는다.
    assert(zoom >= 0);
    return [
      for (final s in shops)
        _Cluster(center: LatLng(s.lat, s.lng), count: 1, shop: s),
    ];
  }

  Widget _buildCompare() {
    final items = _vault.candidates;
    if (items.isEmpty) {
      return _empty(
        '저장된 후보지가 없습니다',
        '지도에서 위치를 고르고 「비교에 추가」를 누르세요. 최대 3곳입니다.',
        cta: '지도에서 지역 추가',
        onCta: () => _tabs.animateTo(1),
      );
    }
    final same = items.every((c) => c.trade == items.first.trade) &&
        items.every((c) => c.radiusKm == items.first.radiusKm);
    return ListView(
      controller: _compareScroll,
      padding: const EdgeInsets.all(16),
      children: [
        _hint('차이와 확인할 현장 항목만 적습니다. 성공·실패·최고 입지라고 단정하지 않습니다.'),
        Text(
          '비교 조건 · ${MarketTrade.labelOf(items.first.trade)} · ${items.first.radiusKm.toInt()}km · ${items.first.periodLabel.isEmpty ? '기간 미확인' : items.first.periodLabel}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (!same)
          _banner(
            '비교 조건 불일치',
            '업종·반경·기간이 다른 후보는 나란히 두지 말고 조건을 맞춘 뒤 비교하세요.',
            SoriTokens.semanticYellow,
          ),
        if (items.length >= 3)
          _banner('후보지 3곳', '더 추가할 수 없습니다. 하나를 지운 뒤 저장하세요.', SoriTokens.semanticYellow),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('항목')),
              for (final c in items) DataColumn(label: Text(c.label)),
            ],
            rows: [
              _cmpRow('동종 업소 수', items.map((c) => '${c.competitorCount}곳')),
              _cmpRow(
                '경쟁 밀도',
                items.map((c) => '${c.densityPerKm2.toStringAsFixed(1)}곳/km²'),
              ),
              _cmpRow(
                '주거 인구',
                items.map(
                  (c) => c.population == null ? '데이터 없음' : '${c.population}명',
                ),
              ),
              _cmpRow(
                '유동 지수',
                items.map(
                  (c) => c.footIndex == null
                      ? '데이터 없음'
                      : c.footIndex!.toStringAsFixed(0),
                ),
              ),
              _cmpRow(
                '업소 수 변화',
                items.map(
                  (c) => c.shopCountChangePct == null
                      ? '데이터 없음'
                      : '${c.shopCountChangePct!.toStringAsFixed(1)}%',
                ),
              ),
              _cmpRow(
                '임대료·주차 메모',
                items.map((c) => c.rentMemo.isEmpty ? '미입력' : c.rentMemo),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(_compareNarrative(items), style: const TextStyle(height: 1.4)),
        const SizedBox(height: 12),
        const Text('현장조사 체크리스트', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final c in items) ...[
          Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 6,
            children: [
              for (final key in FieldSurveyChecks.keys)
                FilterChip(
                  label: Text(FieldSurveyChecks.labels[key] ?? key),
                  selected: (_vault.fieldSurvey[c.id] ?? const []).contains(key),
                  onSelected: (_) => _vault.toggleSurvey(c.id, key),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        SoriPrimaryButton(
          label: '현장 조사 계획 만들기',
          onPressed: _createChecklistActions,
        ),
        const SizedBox(height: 8),
        for (final c in items)
          ListTile(
            title: Text(c.label),
            subtitle: Text(
              '${c.radiusKm.toInt()}km · ${MarketTrade.labelOf(c.trade)} · ${_statusLabel(c.status)}\n임대료 메모: ${c.rentMemo.isEmpty ? '미입력' : c.rentMemo}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: '후보지 삭제',
              onPressed: () => _vault.removeCandidate(c.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }

  String _compareNarrative(List<MarketCandidate> items) {
    if (items.length < 2) {
      return '후보가 1곳입니다. 같은 업종·반경으로 하나 더 저장하면 차이를 볼 수 있습니다.';
    }
    MarketCandidate densest = items.first;
    for (final c in items) {
      if (c.densityPerKm2 > densest.densityPerKm2) densest = c;
    }
    return '${densest.label}의 동종 밀도가 더 높습니다. 유입이 분산될 수 있다는 검증 가설이며, 현장 대기열·가격·주차로 확인해야 합니다.';
  }

  DataRow _cmpRow(String label, Iterable<String> values) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        for (final v in values) DataCell(Text(v)),
      ],
    );
  }

  Widget _buildStrategy() {
    final cur = _vault.currentMetrics;
    final prev = _vault.previousMetrics;
    final snap = _snap;
    final plan = _preview ?? _vault.plan;
    final areaCards = snap == null
        ? const <DiagnosisCard>[]
        : DiagnosisEngine.areaPriority(snap: snap, plan: plan);
    DiagnosisOutcome? outcome;
    if (cur != null && prev != null) {
      outcome = DiagnosisEngine.diagnose(
        current: cur,
        previous: prev,
        external: _vault.externalMetrics,
      );
    }
    return ListView(
      key: const Key('market-strategy-list'),
      controller: _strategyScroll,
      padding: const EdgeInsets.all(16),
      children: [
        _statusBanner(snap),
        _hint('확인된 신호만 적습니다. 데이터가 부족하면 가설을 만들지 않습니다.'),
        if (areaCards.isEmpty && (outcome == null || outcome.cards.isEmpty))
          _empty(
            '먼저 지역 또는 목표를 설정하세요',
            '데이터가 쌓이면 실행할 행동을 정리해드려요.',
            cta: '우리지역 설정',
            onCta: _openFilterSheet,
          ),
        for (final card in [...areaCards, ...?outcome?.cards])
          _diagnosisCard(card),
        if (outcome != null && outcome.missing.isNotEmpty)
          _banner(
            '필요한 데이터',
            '비어 있는 항목: ${outcome.missing.join(', ')}',
            SoriTokens.semanticYellow,
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('market-sample-diagnosis'),
          onPressed: _loadSampleDiagnosis,
          child: const Text('내부 매출 샘플로 진단 규칙 보기'),
        ),
        const Divider(height: 32),
        Text(
          '실행계획 ${_vault.actions.length}건',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (_vault.actions.isEmpty)
          _hint('전략 카드에서 「실행계획에 추가」를 누르면 오늘·이번 주 할 일이 쌓입니다.')
        else ...[
          _actionGroup('오늘', ActionHorizon.today),
          _actionGroup('이번 주', ActionHorizon.thisWeek),
          _actionGroup('30일 측정', ActionHorizon.d30),
        ],
      ],
    );
  }

  Widget _diagnosisCard(DiagnosisCard card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _kv('확인된 신호', card.observation),
            _kv('근거', card.evidence),
            _kv('가능한 해석', card.possibleReading),
            _kv('현장에서 확인할 것', card.toVerify),
            _kv('오늘 할 행동', card.todayAction),
            _kv('이번 주 할 행동', card.weekAction),
            _kv('30일 성공 지표', card.metric30d),
            _kv('데이터 한계', card.limitation),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openProvenance,
                child: const Text('근거 보기'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('diagnosis-to-actions-${card.id}'),
                onPressed: () => _actionsFromDiagnosis(card),
                child: const Text('실행계획에 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionGroup(String title, ActionHorizon horizon) {
    final items = [
      for (final a in _vault.actions)
        if (a.horizon == horizon) a,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final a in items) _actionTile(a),
      ],
    );
  }

  Widget _actionTile(StrategyActionPlan a) {
    return Card(
      child: ListTile(
        title: Text(a.title),
        subtitle: Text(
          '${a.description}\n상태: ${a.status.name} · ${a.horizon.name}'
          '${a.outcomeMemo.isEmpty ? '' : '\n성과: ${a.outcomeMemo}'}',
        ),
        isThreeLine: true,
        trailing: FittedBox(
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '건너뛰기',
              onPressed: () => _vault.updateAction(
                a.copyWith(status: ActionPlanStatus.skipped),
              ),
              icon: const Icon(Icons.skip_next_outlined),
            ),
            IconButton(
              tooltip: '진행 중',
              onPressed: () => _vault.updateAction(
                a.copyWith(status: ActionPlanStatus.inProgress),
              ),
              icon: const Icon(Icons.play_circle_outline),
            ),
            IconButton(
              tooltip: '완료 처리',
              onPressed: () => _vault.updateAction(
                a.copyWith(status: ActionPlanStatus.done),
              ),
              icon: const Icon(Icons.check_circle_outline),
            ),
            IconButton(
              tooltip: '성과 기록',
              onPressed: () => _recordOutcome(a),
              icon: const Icon(Icons.edit_note),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordOutcome(StrategyActionPlan a) async {
    final memo = TextEditingController(text: a.outcomeMemo);
    final value = TextEditingController(
      text: a.outcomeValue?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('성과 기록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: memo,
              decoration: const InputDecoration(labelText: '성과 메모'),
            ),
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '성과 수치'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              _vault.updateAction(
                a.copyWith(
                  outcomeMemo: memo.text.trim(),
                  outcomeValue: double.tryParse(value.text.trim()),
                  status: ActionPlanStatus.done,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _tradeChips() {
    return Wrap(
      spacing: 6,
      children: [
        for (final key in MarketTrade.keys)
          ChoiceChip(
            label: Text(MarketTrade.labelOf(key)),
            selected: _trade == key,
            onSelected: (_) {
              setState(() => _trade = key);
              _reloadMap();
            },
          ),
      ],
    );
  }

  Widget _moneyField(
    TextEditingController c,
    String label,
    String key, {
    bool isDays = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        key: Key(key),
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          helperText: !isDays && _n(c) > 0 ? formatWon(_n(c)) : null,
        ),
        onChanged: isDays
            ? (v) {
                final n = int.tryParse(v) ?? 0;
                if (n > 31) c.text = '31';
              }
            : null,
      ),
    );
  }

  Widget _resultCard(TargetRevenueResult r) {
    final extra = _n(_actual) > 0
        ? TargetRevenueCalc.additionalMonthlyVisits(
            requiredMonthlyVisits: r.monthlyVisits,
            actualMonthlyVisits: _n(_actual),
          )
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '하루 ${r.dailyVisits}명 × ${formatWon(r.input.averageTicketKrw)} × ${r.input.openDaysPerMonth}일 규모가 필요합니다.',
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text('필요 매출 ${formatWon(r.requiredRevenueKrw)}'),
            Text('공헌이익 ${formatWon(r.contributionKrw)}'),
            Text('공헌이익률 ${(r.contributionRate * 100).round()}%'),
            Text('월 필요 방문 ${r.monthlyVisits}회'),
            Text('하루 필요 방문 ${r.dailyVisits}회'),
            if (extra != null)
              Text(
                '현재 방문보다 월 $extra회, 하루 약 ${(extra / r.input.openDaysPerMonth).ceil()}회가 더 필요합니다.',
              ),
            const Text('이 숫자는 가정이며 매출을 보장하지 않습니다.'),
          ],
        ),
      ),
    );
  }

  int _coincidentGroups(List<CompetitorShop> shops) {
    final buckets = <String, int>{};
    for (final s in shops) {
      final key =
          '${s.lat.toStringAsFixed(5)},${s.lng.toStringAsFixed(5)}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets.values.where((n) => n > 1).length;
  }

  Widget _storeAuditStrip() {
    final a = StoreLoadAudit.last;
    if (a == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Text(
        '${a.source} · ${a.category.isEmpty ? '—' : a.category} · '
        'total ${a.responseTotalCount ?? '—'} → raw ${a.rawItemCount} → '
        'norm ${a.normalizedCount} → filter ${a.afterFilterCount} → '
        'coords ${a.afterCoordCount} → dedupe ${a.afterDedupeCount} → '
        'state ${a.stateCount} → markers ${a.renderedMarkerCount}'
        '${a.paginationContract == 'contractUnknown' ? ' · 페이지계약 미확정' : ''}'
        '${a.dropReasons.isEmpty ? '' : ' · drop ${a.dropReasons}'}'
        '${a.coincidentCoordGroups > 0 ? ' · 동일좌표 ${a.coincidentCoordGroups}그룹' : ''}',
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: SoriTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _statusBanner(MarketSnapshot? snap) {
    if (snap == null) return const SizedBox.shrink();
    if (snap.status == MarketDataStatus.demo || widget.forceDemo) {
      return _banner(
        'DEMO',
        '데모 데이터입니다. 명시적 시드이며 실제 공공 데이터가 아닙니다.',
        Colors.orange,
      );
    }
    if (snap.status == MarketDataStatus.cached) {
      return _banner(
        'CACHED',
        '마지막으로 확인한 데이터 · ${snap.fetchedAt?.toIso8601String().split('T').first ?? '저장본'}',
        SoriTokens.semanticYellow,
      );
    }
    if (snap.status == MarketDataStatus.stale) {
      return Column(
        children: [
          _banner(
            'STALE',
            '저장된 결과가 오래되었습니다. 연결되면 최신 데이터로 업데이트할 수 있어요.',
            SoriTokens.semanticYellow,
          ),
          TextButton(onPressed: _reloadMap, child: const Text('다시 시도')),
        ],
      );
    }
    if (snap.status == MarketDataStatus.unavailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            'UNAVAILABLE',
            snap.userMessage ??
                '상권 데이터를 불러오지 못했어요. 연결을 확인한 뒤 다시 시도하세요.',
            SoriTokens.systemRed,
          ),
          TextButton(onPressed: _reloadMap, child: const Text('다시 시도')),
        ],
      );
    }
    if (snap.status == MarketDataStatus.liveEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            'LIVE_EMPTY',
            '조건에 맞는 업소를 찾지 못했어요. 반경을 넓히거나 업종을 바꿔보세요. · ${snap.competitionMeta.geoUnit} · 동종 0곳',
            SoriTokens.semanticYellow,
          ),
          TextButton(onPressed: _openFilterSheet, child: const Text('반경 바꾸기')),
        ],
      );
    }
    if (snap.status == MarketDataStatus.live) {
      final a = StoreLoadAudit.last;
      final pageNote = a?.paginationContract == 'contractUnknown'
          ? '추가 페이지 계약 미확정 · 이 응답만'
          : '이 응답';
      return _banner(
        'LIVE',
        '${snap.competitionMeta.source} · $pageNote · ${MarketTrade.labelOf(snap.trade)} '
        'total ${a?.responseTotalCount ?? '—'} → raw ${a?.rawItemCount ?? '—'} → '
        'norm ${a?.normalizedCount ?? '—'} → filter ${a?.afterFilterCount ?? snap.competitors.length} → '
        'coords ${a?.afterCoordCount ?? '—'} → dedupe ${a?.afterDedupeCount ?? '—'} → '
        'state ${a?.stateCount ?? snap.competitors.length} → markers ${a?.renderedMarkerCount ?? 0}',
        SoriTokens.semanticGreen,
      );
    }
    return _banner(
      _statusLabel(snap.status),
      '${snap.competitionMeta.source} · ${snap.competitionMeta.geoUnit}',
      SoriTokens.semanticYellow,
    );
  }

  Widget _verbButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }

  Widget _mapCtrl({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: SoriTokens.surface,
        elevation: 2,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String body,
    required String cta,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.35)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onTap, child: Text(cta)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(String t) =>
      Text(t, style: const TextStyle(color: Color(0xFF4B5563), height: 1.4));

  Widget _errorBox(String t) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: const Color(0xFFFFEBEE),
        child: Text(t, style: const TextStyle(color: SoriTokens.systemRed)),
      ),
    );
  }

  Widget _banner(String title, String body, Color color) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(10),
      child: Text(
        '$title — $body',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _empty(
    String title,
    String body, {
    String? cta,
    VoidCallback? onCta,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (cta != null && onCta != null)
            TextButton(onPressed: onCta, child: Text(cta)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$k  ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  Widget _metaLine(IndicatorMeta m) {
    final warn = m.comparisonWarning;
    return Text(
      '출처 ${m.source.isEmpty ? '없음' : m.source} · 기간 ${m.periodLabel.isEmpty ? '없음' : m.periodLabel} · 갱신 ${m.updatedOn.isEmpty ? '없음' : m.updatedOn} · 단위 ${m.geoUnit.isEmpty ? '없음' : m.geoUnit}${warn == null ? '' : ' · $warn'}',
      style: const TextStyle(fontSize: 11, height: 1.35),
    );
  }

  Widget _metricOrMissing(
    String label,
    num? value,
    IndicatorMeta meta, {
    String suffix = '',
  }) {
    if (!meta.available || value == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
        child: Text(
          '$label: 제공 데이터 없음. ${meta.nextAction ?? '다른 출처를 확인하세요.'}',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label $value$suffix · ${_statusLabel(_snap?.status ?? MarketDataStatus.unavailable)}',
          ),
          _metaLine(meta),
        ],
      ),
    );
  }
}

class _Cluster {
  const _Cluster({required this.center, required this.count, this.shop});
  final LatLng center;
  final int count;
  final CompetitorShop? shop;
}

class _Keep extends StatefulWidget {
  const _Keep(this.child);
  final Widget child;
  @override
  State<_Keep> createState() => _KeepState();
}

class _KeepState extends State<_Keep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
