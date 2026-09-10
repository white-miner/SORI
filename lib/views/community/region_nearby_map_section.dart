import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/shop_market_service.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';

/// PRD v7.8 C2 — 우리 지역 상단 4:3 맵 + 업종·반경 칩.
class RegionNearbyMapSection extends StatefulWidget {
  const RegionNearbyMapSection({super.key, required this.store});

  final SoriStore store;

  @override
  State<RegionNearbyMapSection> createState() => _RegionNearbyMapSectionState();
}

class _RegionNearbyMapSectionState extends State<RegionNearbyMapSection> {
  static const _chips = <({String key, String label})>[
    (key: 'all', label: '전체'),
    (key: 'skin', label: '피부샵'),
    (key: 'nail', label: '네일샵'),
    (key: 'hair', label: '미용실'),
    (key: 'barber', label: '바버샵'),
    (key: 'tattoo', label: '타투샵'),
    (key: 'semi_permanent', label: '반영구화장샵'),
  ];

  static const _radiiKm = <double>[0.5, 1.0, 2.0];

  String _chip = 'all';
  double _radiusKm = 1.0;
  bool _loading = true;
  String? _error;
  ShopMarketInsight? _insight;
  ShopMarketStoreItem? _selected;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    final shop = widget.store.shop;
    final insight = await ShopMarketService.instance.fetch(
      shop: shop,
      category: '전체',
      fallbackAddress: shop.address?.trim(),
      radiusM: (_radiusKm * 1000).round(),
    );
    if (!mounted) return;
    LatLng? center;
    final clat = insight.centerLatitude;
    final clng = insight.centerLongitude;
    if (clat != null && clng != null && clat.abs() > 0.01) {
      center = LatLng(clat, clng);
    } else if (shop.latitude != null &&
        shop.longitude != null &&
        shop.latitude!.abs() > 0.01) {
      center = LatLng(shop.latitude!, shop.longitude!);
    }

    setState(() {
      _insight = insight;
      _center = center;
      _loading = false;
      if (!insight.storesOk) {
        _error = ShopMarketService.friendlyReason(insight.storesError);
      } else if (center == null) {
        _error = '내 위치·주소를 아직 몰라요. 샵 주소나 경영 프로필 주소를 넣어 주세요.';
      }
    });
  }

  List<ShopMarketStoreItem> get _filtered {
    final items = _insight?.storeItems ?? const [];
    if (_chip == 'all') return items;
    return items.where((e) => e.chipKey == _chip).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mapH = width * 3 / 4; // 4:3 → height = width * 3/4

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: mapH.clamp(180, 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMap(),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in _chips) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(c.label),
                    selected: _chip == c.key,
                    onSelected: (_) => setState(() {
                      _chip = c.key;
                      _selected = null;
                    }),
                    selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _chip == c.key
                          ? SoriTokens.primary
                          : SoriTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              '반경',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            for (final km in _radiiKm) ...[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1)}km'),
                  selected: _radiusKm == km,
                  onSelected: (_) {
                    if (_radiusKm == km) return;
                    setState(() => _radiusKm = km);
                    _reload();
                  },
                  selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: _loading ? null : _reload,
              child: const Text('다시 보기'),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '반경 ${_radiusKm < 1 ? '${(_radiusKm * 1000).round()}m' : '${_radiusKm}km'} · '
              '표시 ${_filtered.length}곳'
              '${_insight == null ? '' : ' (전체 ${_insight!.totalInRadius}곳 중)'}',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_selected != null) _SelectedCard(item: _selected!),
        const SizedBox(height: 4),
        const Text(
          '출처: 소상공인시장진흥공단 상가(상권)정보 · 추정·참고용',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final center = _center;
    if (_loading && center == null) {
      return const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (center == null) {
      return const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '지도 중심을 아직 잡을 수 없어요',
              style: TextStyle(color: SoriTokens.textSecondary),
            ),
          ),
        ),
      );
    }

    final markers = <Marker>[
      Marker(
        point: center,
        width: 36,
        height: 36,
        child: const Icon(Icons.my_location, color: SoriTokens.primary, size: 28),
      ),
      for (final s in _filtered)
        Marker(
          point: LatLng(s.latitude, s.longitude),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => setState(() => _selected = s),
            child: Icon(
              Icons.location_on,
              color: _selected?.name == s.name &&
                      _selected?.distanceM == s.distanceM
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB),
              size: 30,
            ),
          ),
        ),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: _radiusKm <= 0.5 ? 15.2 : (_radiusKm <= 1 ? 14.2 : 13.2),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sori.app',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: _radiusKm * 1000,
              useRadiusInMeter: true,
              color: SoriTokens.primary.withValues(alpha: 0.08),
              borderStrokeWidth: 1.5,
              borderColor: SoriTokens.primary.withValues(alpha: 0.45),
            ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.item});

  final ShopMarketStoreItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (item.categoryLabel.isNotEmpty) item.categoryLabel,
              '${item.distanceM}m',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.address,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '개별 점포 실매출은 제공되지 않습니다. (공공·추정)',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
