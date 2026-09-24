import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/shop_market_service.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/our_area_category.dart';
import 'region_map_tile_candidates.dart';

/// Community-first market overview. This screen is intentionally limited to
/// public, area-level indicators; management decisions belong to My Page.
class CommunityMarketAnalysisPage extends StatefulWidget {
  const CommunityMarketAnalysisPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CommunityMarketAnalysisPage> createState() =>
      _CommunityMarketAnalysisPageState();
}

class _CommunityMarketAnalysisPageState
    extends State<CommunityMarketAnalysisPage> {
  static const _radii = <int>[500, 1000, 2000];
  int _radiusM = 1000;
  String _category = OurAreaCategory.skin;
  ShopMarketInsight? _insight;
  ShopMarketInsight? _populationInsight;
  FranchiseSalesSummary? _franchiseSales;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() { _loading = true; _franchiseSales = null; });
    final shop = widget.store.shop;
    try {
      ShopMarketInsight? population;
      var latitude = shop.latitude;
      var longitude = shop.longitude;
      if (latitude == null || longitude == null) {
        population = await ShopMarketService.instance.fetch(
          shop: shop,
          category: '전체',
          radiusM: _radiusM,
          fallbackAddress: shop.address,
        );
        latitude = population.centerLatitude;
        longitude = population.centerLongitude;
      }
      final result = latitude != null && longitude != null
          ? await ShopMarketService.instance.fetchNearby(
              latitude: latitude,
              longitude: longitude,
              radiusM: _radiusM,
            )
          : ShopMarketInsight.unavailable(reason: 'shop_coords_missing');
      if (mounted && request == _request) {
        setState(() {
          _insight = result;
          _populationInsight = population;
          _loading = false;
        });
      }
      final address = (shop.address ?? '').trim();
      if (address.isNotEmpty) {
        final sale = await ShopMarketService.instance.fetchFranchiseSales(address);
        if (mounted && request == _request) setState(() => _franchiseSales = sale);
      }
      if (population == null) {
        final nextPopulation = await ShopMarketService.instance.fetch(
          shop: shop,
          category: '전체',
          radiusM: _radiusM,
          fallbackAddress: shop.address,
        );
        if (mounted && request == _request) {
          setState(() => _populationInsight = nextPopulation);
        }
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _insight = ShopMarketInsight.unavailable(reason: 'market_unavailable'));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insight = _insight;
    final available = insight?.storesOk == true && insight?.storesComplete == true;
    final beauty = available ? insight!.storeItems.where((s) => s.chipKey != 'other').toList() : <ShopMarketStoreItem>[];
    final total = beauty.length;
    final same = beauty.where((s) => s.chipKey == _category).length;
    final population = _populationInsight?.populationOk == true ? _populationInsight!.popTotal : null;
    return ColoredBox(
      color: SoriTokens.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          children: [
            const Text('상권분석', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('내 주변 뷰티 상권을 한눈에 비교하세요.', style: TextStyle(color: SoriTokens.textSecondary)),
            const SizedBox(height: 16),
            _analysisMap(insight, beauty.where((s) => s.chipKey == _category).toList()),
            const SizedBox(height: 18),
            const Text('이 지역의 흐름', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_loading)
              const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
            else ...[
              if (!available)
                _glassPanel(child: const Text('상권 데이터를 불러오지 못했습니다. 화면을 아래로 당겨 다시 시도해 주세요.')),
              Row(children: [
                Expanded(child: _metricCard('주변 샵', available ? '$total곳' : '—', '반경 ${_radiusM >= 1000 ? '${_radiusM ~/ 1000}km' : '${_radiusM}m'}')),
                const SizedBox(width: 10),
                Expanded(child: _metricCard('동종업종', available ? '$same곳' : '—', '선택 업종 기준')),
              ]),
              const SizedBox(height: 10),
              _wideMetric('배후인구', population != null ? '$population명' : '현재 제공되지 않음', '공공데이터 기준 · 행정동 단위'),
              const SizedBox(height: 16),
              if (available) _visualSummary(total: total, same: same),
              const SizedBox(height: 12),
              _salesPanel(),
              const SizedBox(height: 18),
              _sourceNote(insight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _glassPanel({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8))]),
        child: child,
      );

  Widget _analysisMap(ShopMarketInsight? insight, List<ShopMarketStoreItem> items) {
    final shop = widget.store.shop;
    final lat = insight?.centerLatitude ?? shop.latitude;
    final lng = insight?.centerLongitude ?? shop.longitude;
    if (lat == null || lng == null) {
      return _glassPanel(child: const SizedBox(height: 190, child: Center(child: Text('지도 중심 위치를 확인할 수 없습니다.'))));
    }
    final center = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(children: [
          FlutterMap(
            key: ValueKey('analysis-map-$_radiusM'),
            options: MapOptions(initialCenter: center, initialZoom: _radiusM >= 2000 ? 13 : 14),
            children: [
              TileLayer(
                urlTemplate: RegionMapTileCatalog.spec(RegionMapTileCatalog.productionDefault).urlTemplate,
                userAgentPackageName: 'com.sori.app',
              ),
              CircleLayer(circles: [CircleMarker(point: center, radius: _radiusM.toDouble(), useRadiusInMeter: true, color: SoriTokens.brand.withValues(alpha: .08), borderColor: SoriTokens.brand.withValues(alpha: .45), borderStrokeWidth: 2)]),
              MarkerLayer(markers: [
                Marker(point: center, width: 44, height: 44, child: const _AnalysisMarker(selected: true)),
                for (final item in items.where((s) => s.latitude.abs() > .01 && s.longitude.abs() > .01))
                  Marker(point: LatLng(item.latitude, item.longitude), width: 28, height: 28, child: const _AnalysisMarker()),
              ]),
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(top: 12, left: 12, right: 12, child: _mapFilters()),
          if (_loading)
            const Positioned.fill(child: Center(child: CircularProgressIndicator())),
          Positioned(bottom: 14, left: 14, child: _mapBadge(
            insight?.storesOk == true && insight?.storesComplete == true
                ? '${OurAreaCategory.labelOf(_category)} ${items.length}곳'
                : '조회 대기',
          )),
          Positioned(bottom: 14, right: 14, child: _mapBadge('반경 ${_radiusM >= 1000 ? '${_radiusM ~/ 1000}km' : '${_radiusM}m'}')),
        ]),
      ),
    );
  }

  Widget _mapFilters() => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xDEFFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xAFFFFFFF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            const Icon(Icons.tune_rounded, size: 18, color: SoriTokens.brand),
            const SizedBox(width: 7),
            const Text('분석 범위', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            for (final radius in _radii) Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _filterPill(
                radius >= 1000 ? '${radius ~/ 1000}km' : '${radius}m',
                selected: _radiusM == radius,
                onTap: () { if (_radiusM == radius) return; setState(() => _radiusM = radius); _load(); },
              ),
            ),
          ])),
          const SizedBox(height: 9),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            const SizedBox(width: 12),
            for (final key in const ['skin', 'hair', 'barber', 'nail', 'tattoo']) Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _filterPill(OurAreaCategory.labelOf(key), selected: _category == key, onTap: () => setState(() => _category = key)),
            ),
            const SizedBox(width: 5),
          ])),
        ]),
      ),
    ),
  );

  Widget _filterPill(String label, {required bool selected, required VoidCallback onTap}) => Material(
    color: selected ? SoriTokens.brand.withValues(alpha: .13) : const Color(0x9FFFFFFF),
    shape: StadiumBorder(side: BorderSide(color: selected ? SoriTokens.brand : const Color(0x66FFFFFF))),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? SoriTokens.brand : SoriTokens.primary))),
    ),
  );

  Widget _mapBadge(String text) => DecoratedBox(decoration: BoxDecoration(color: const Color(0xEFFFFFFF), borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12)]), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))));

  Widget _metricCard(String title, String value, String caption) => _glassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: SoriTokens.textSecondary)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(caption, style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary))]));

  Widget _wideMetric(String title, String value, String caption) => _glassPanel(child: Row(children: [const Icon(Icons.groups_2_outlined, color: SoriTokens.brand, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: SoriTokens.textSecondary)), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text(caption, style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary))]))]));

  Widget _salesPanel() {
    final sale = _franchiseSales;
    if (sale == null) return _wideMetric('가맹점 매출 통계', '조회 중', '공정위 지역별 서비스업 통계');
    if (!sale.ok) return _wideMetric('가맹점 매출 통계', '현재 제공되지 않음',
        '해당 지역의 뷰티 가맹점 통계를 확인할 수 없어요.');
    return _glassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('가맹점 매출 통계', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('${sale.region} · ${sale.year}년 · 서비스업 가맹점',
          style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary)),
      const SizedBox(height: 12),
      for (final row in sale.rows) if (row.amount > 0) Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(row.industry, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${row.amount.toStringAsFixed(row.amount == row.amount.roundToDouble() ? 0 : 1)} ${row.unit}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      const Text('면적단위 평균매출금액 · 주변 반경 또는 개별 샵 매출이 아닙니다.',
          style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary)),
    ]));
  }

  Widget _visualSummary({required int total, required int same}) {
    final ratio = total == 0 ? 0.0 : (same / total).clamp(0.0, 1.0);
    return _glassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('상권 한눈에 보기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 16), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 12, color: SoriTokens.brand, backgroundColor: const Color(0xFFE8E8F0))), const SizedBox(height: 10), Text('전체 주변 샵 중 선택 업종 비중 ${(ratio * 100).round()}%', style: TextStyle(color: SoriTokens.textSecondary)), const SizedBox(height: 18), Text('동종업종 $same곳 · 전체 $total곳', style: const TextStyle(fontWeight: FontWeight.w700))]));
  }

  Widget _sourceNote(ShopMarketInsight? insight) {
    if (insight?.storesOk != true || insight?.storesComplete != true) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('샵 데이터의 출처와 조회 시점을 확인할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary)),
      );
    }
    final checked = insight?.fetchedAt?.toLocal();
    final date = checked == null
        ? '조회 시점 확인 불가'
        : '${checked.year}.${checked.month.toString().padLeft(2, '0')}.${checked.day.toString().padLeft(2, '0')} 조회';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '샵 출처: 소상공인시장진흥공단 상가(상권)정보 · $date\n'
        '거주인구는 행정동 기준으로 반경 내 인구와 다릅니다. '
        '평균매출은 가맹점 기반 통계이며 개별 샵 매출이 아닙니다.',
        style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary, height: 1.45),
      ),
    );
  }
}

class _AnalysisMarker extends StatelessWidget {
  const _AnalysisMarker({this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? SoriTokens.brand : const Color(0xFF94A3B8), border: Border.all(color: Colors.white, width: 3), boxShadow: [if (selected) BoxShadow(color: SoriTokens.brand.withValues(alpha: .38), blurRadius: 14, spreadRadius: 3)]),
        child: Icon(selected ? Icons.my_location_rounded : Icons.storefront_rounded, size: selected ? 22 : 15, color: Colors.white),
      );
}
