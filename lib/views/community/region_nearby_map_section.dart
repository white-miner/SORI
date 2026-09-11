import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/biz_profile_store.dart';
import '../../services/region_content_bookmark_store.dart';
import '../../services/region_map_gps.dart';
import '../../services/shop_market_service.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../shop_settings_page.dart';
import 'region_map_center.dart';
import 'region_map_content_pins.dart';
import 'region_map_tile_candidates.dart';

/// PRD v7.8 C2 — 우리 지역 상단 4:3 맵 + 업종·반경 칩.
/// C.1 GPS · C.2 저장함 · C.S1 베이스맵 비교(운영 기본=OSM 기준선).
class RegionNearbyMapSection extends StatefulWidget {
  const RegionNearbyMapSection({
    super.key,
    required this.store,
    this.radiusKm = 1.0,
    this.onRadiusChanged,
    this.onCenterChanged,
  });

  final SoriStore store;
  final double radiusKm;
  final ValueChanged<double>? onRadiusChanged;
  /// 맵이 잡은 중심 (위도, 경도). 없으면 null 콜백.
  final void Function(double? lat, double? lng)? onCenterChanged;

  @override
  State<RegionNearbyMapSection> createState() => _RegionNearbyMapSectionState();
}

enum _GpsBanner { none, active, denied, failed }

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

  final MapController _mapController = MapController();

  String _chip = 'all';
  bool _loading = true;
  bool _gpsBusy = false;
  String? _error;
  ShopMarketInsight? _insight;
  ShopMarketStoreItem? _selected;
  RegionMapPin? _selectedPin;
  List<RegionMapPin> _contentPins = const [];
  /// Shop/Biz·지오코딩 기준 중심 (GPS 실패해도 유지).
  LatLng? _baseCenter;
  /// 탭으로 잡은 GPS 중심. 디스크에 저장하지 않음.
  LatLng? _gpsCenter;
  _GpsBanner _gpsBanner = _GpsBanner.none;
  RegionMapTileId _tileId = RegionMapTileCatalog.productionDefault;

  double get _radiusKm => widget.radiusKm;

  LatLng? get _viewCenter => _gpsCenter ?? _baseCenter;

  RegionMapTileSpec get _tile => RegionMapTileCatalog.spec(_tileId);

  @override
  void initState() {
    super.initState();
    RegionMapTileCatalog.debugLogKeyPresence();
    _reload();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RegionNearbyMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
      _selectedPin = null;
      _gpsCenter = null;
      _gpsBanner = _GpsBanner.none;
    });
    final shop = widget.store.shop;
    final biz = await BizProfileStore.load(shop.id);
    final bizAddr = biz.address.trim();
    // Content pins need feed caches; ignore failures.
    await Future.wait([
      widget.store.refreshCommunityPosts(force: true),
      widget.store.refreshCommunityHotCases(),
    ]);
    final insight = await ShopMarketService.instance.fetch(
      shop: shop,
      category: '전체',
      fallbackAddress: bizAddr.isEmpty ? null : bizAddr,
      radiusM: (_radiusKm * 1000).round(),
    );
    if (!mounted) return;
    final resolved = RegionMapCenter.resolve(
      insightLat: insight.centerLatitude,
      insightLng: insight.centerLongitude,
      shopLat: shop.latitude,
      shopLng: shop.longitude,
    );
    final center =
        resolved == null ? null : LatLng(resolved.lat, resolved.lng);

    var pins = const <RegionMapPin>[];
    if (center != null) {
      pins = await RegionMapContentPins.loadNear(
        store: widget.store,
        centerLat: center.latitude,
        centerLng: center.longitude,
        radiusKm: _radiusKm,
      );
    }

    setState(() {
      _insight = insight;
      _baseCenter = center;
      _contentPins = pins;
      _loading = false;
      if (center == null) {
        _error = '우리 지역의 글을 보려면 샵 주소를 등록해 주세요.';
      } else if (!insight.storesOk) {
        _error = ShopMarketService.friendlyReason(insight.storesError);
      }
    });
    widget.onCenterChanged?.call(center?.latitude, center?.longitude);
  }

  Future<void> _openAddressSettings() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ShopSettingsPage(),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _onGpsTap() async {
    if (_gpsBusy) return;
    setState(() => _gpsBusy = true);
    final result = await RegionMapGps.oneShot();
    if (!mounted) return;
    setState(() => _gpsBusy = false);

    switch (result.outcome) {
      case RegionMapGpsOutcome.denied:
        setState(() => _gpsBanner = _GpsBanner.denied);
        // Shop/Biz 중심·null 덮어쓰기 금지.
        return;
      case RegionMapGpsOutcome.failed:
        setState(() => _gpsBanner = _GpsBanner.failed);
        return;
      case RegionMapGpsOutcome.ok:
        final lat = result.lat!;
        final lng = result.lng!;
        final point = LatLng(lat, lng);
        final zoom =
            _radiusKm <= 0.5 ? 15.2 : (_radiusKm <= 1 ? 14.2 : 13.2);
        setState(() {
          _gpsCenter = point;
          _gpsBanner = _GpsBanner.active;
          _error = null;
        });
        try {
          _mapController.move(point, zoom);
        } catch (_) {
          // attach 전이면 다음 프레임 build의 initialCenter로 표시.
        }
        widget.onCenterChanged?.call(lat, lng);
        final pins = await RegionMapContentPins.loadNear(
          store: widget.store,
          centerLat: lat,
          centerLng: lng,
          radiusKm: _radiusKm,
        );
        if (!mounted) return;
        setState(() {
          _contentPins = pins;
          _selectedPin = null;
        });
    }
  }

  Future<void> _openSavedSheet() async {
    await RegionContentBookmarkStore.instance.refresh();
    if (!mounted) return;
    final items = RegionContentBookmarkStore.instance.items;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '저장한 지역 콘텐츠',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '글·세미나 상세에서 저장한 항목만 모아요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      '아직 저장한 글·세미나가 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final b = items[i];
                        final title = _bookmarkTitle(b);
                        final kindLabel = b.kind == RegionContentKind.post
                            ? '글'
                            : '세미나';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            b.kind == RegionContentKind.post
                                ? Icons.article_outlined
                                : Icons.event_outlined,
                            color: SoriTokens.primary,
                          ),
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(kindLabel),
                          trailing: IconButton(
                            tooltip: '저장 해제',
                            icon: const Icon(Icons.bookmark_remove_outlined),
                            onPressed: () async {
                              await RegionContentBookmarkStore.instance
                                  .toggle(b.kind, b.targetId);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) await _openSavedSheet();
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _bookmarkTitle(RegionContentBookmark b) {
    final store = widget.store;
    if (b.kind == RegionContentKind.post) {
      for (final p in store.communityPosts) {
        if (p.id == b.targetId) {
          final t = p.title.trim();
          if (t.isNotEmpty) return t;
          final body = p.body.trim();
          if (body.isNotEmpty) {
            return body.length > 40 ? '${body.substring(0, 40)}…' : body;
          }
        }
      }
      return '저장한 글';
    }
    for (final s in store.openSeminarClassesForFeed) {
      if (s.id == b.targetId) {
        final t = s.title.trim();
        if (t.isNotEmpty) return t;
      }
    }
    for (final s in store.seminarClasses) {
      if (s.id == b.targetId) {
        final t = s.title.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return '저장한 세미나';
  }

  void _onMapEvent(MapEvent event) {
    if (_gpsBanner != _GpsBanner.active) return;
    if (event is! MapEventMoveEnd) return;
    // 프로그램 move는 활성 유지 · 사용자 pan/zoom만 해제.
    if (event.source == MapEventSource.mapController) return;
    setState(() => _gpsBanner = _GpsBanner.none);
  }

  List<ShopMarketStoreItem> get _filtered {
    final items = _insight?.storeItems ?? const [];
    if (_chip == 'all') return items;
    return items.where((e) => e.chipKey == _chip).toList();
  }

  String? get _gpsStatusText {
    switch (_gpsBanner) {
      case _GpsBanner.active:
        return '현재 위치 주변을 보고 있어요.';
      case _GpsBanner.denied:
        return '현재 위치 없이 샵 주소 기준으로 보고 있어요.';
      case _GpsBanner.failed:
        return '현재 위치를 확인하지 못했어요. 샵 주소 기준으로 보여드릴게요.';
      case _GpsBanner.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mapH = width * 3 / 4; // 4:3 → height = width * 3/4
    final gpsText = _gpsStatusText;

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
        if (gpsText != null) ...[
          const SizedBox(height: 8),
          Text(
            gpsText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _Cs1TileCompareBar(
          selected: _tileId,
          onSelected: (id) {
            final next = RegionMapTileCatalog.spec(id);
            if (!next.canRender) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${next.label} 키가 없어요. .env에 ${next.keyHint}를 넣고 로컬에서 비교하세요.',
                  ),
                ),
              );
              return;
            }
            setState(() => _tileId = id);
          },
        ),
        if (!_tile.canRender)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '선택 타일을 불러올 수 없어요. ${_tile.keyHint}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'C.S1 비교 · ${_tile.code} ${_tile.label} · ${_tile.rankNote}',
              style: const TextStyle(
                fontSize: 11,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
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
                      _selectedPin = null;
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
                    widget.onRadiusChanged?.call(km);
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
        else if (_error != null && _viewCenter == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _openAddressSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                  ),
                  child: const Text(
                    '주소 입력',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
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
              '상권 ${_filtered.length}곳 · 글/세미나 ${_contentPins.length}'
              '${_insight == null ? '' : ' (상권 전체 ${_insight!.totalInRadius})'}',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_selectedPin != null)
          _ContentPinCard(
            pin: _selectedPin!,
            bookmarked: RegionContentBookmarkStore.instance.isBookmarked(
              _selectedPin!.kind == RegionMapPinKind.post
                  ? RegionContentKind.post
                  : RegionContentKind.seminar,
              _selectedPin!.id,
            ),
            onToggleSave: () async {
              final kind = _selectedPin!.kind == RegionMapPinKind.post
                  ? RegionContentKind.post
                  : RegionContentKind.seminar;
              await RegionContentBookmarkStore.instance
                  .toggle(kind, _selectedPin!.id);
              if (mounted) setState(() {});
            },
          )
        else if (_selected != null)
          _SelectedCard(item: _selected!),
        const SizedBox(height: 4),
        const Text(
          '출처: 소상공인시장진흥공단 상가(상권)정보 · 추정·참고용',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final center = _viewCenter;
    if (_loading && center == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(
            color: Color(0xFFF3F4F6),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          _MapControlColumn(
            gpsBusy: _gpsBusy,
            onGps: _onGpsTap,
            onSaved: _openSavedSheet,
          ),
        ],
      );
    }
    if (center == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFF3F4F6),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '지도 중심을 아직 잡을 수 없어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _openAddressSettings,
                      child: const Text('주소 입력'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _MapControlColumn(
            gpsBusy: _gpsBusy,
            onGps: _onGpsTap,
            onSaved: _openSavedSheet,
          ),
        ],
      );
    }

    final markers = <Marker>[
      Marker(
        point: center,
        width: 36,
        height: 36,
        child: Icon(
          _gpsBanner == _GpsBanner.active
              ? Icons.near_me_rounded
              : Icons.my_location,
          color: SoriTokens.primary,
          size: 28,
        ),
      ),
      for (final s in _filtered)
        Marker(
          point: LatLng(s.latitude, s.longitude),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => setState(() {
              _selected = s;
              _selectedPin = null;
            }),
            child: Icon(
              Icons.storefront_outlined,
              color: _selected?.name == s.name &&
                      _selected?.distanceM == s.distanceM
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF94A3B8),
              size: 26,
            ),
          ),
        ),
      for (final pin in _contentPins)
        Marker(
          point: LatLng(pin.latitude, pin.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedPin = pin;
              _selected = null;
            }),
            child: Icon(
              pin.kind == RegionMapPinKind.post
                  ? Icons.chat_bubble_rounded
                  : Icons.event_rounded,
              color: _selectedPin?.id == pin.id
                  ? SoriTokens.primary
                  : (pin.kind == RegionMapPinKind.post
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF0F766E)),
              size: 32,
            ),
          ),
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom:
                _radiusKm <= 0.5 ? 15.2 : (_radiusKm <= 1 ? 14.2 : 13.2),
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              key: ValueKey('tiles-${_tile.code}'),
              urlTemplate: _tile.canRender
                  ? _tile.urlTemplate
                  : RegionMapTileCatalog.spec(
                      RegionMapTileId.osmBaseline,
                    ).urlTemplate,
              subdomains: _tile.canRender
                  ? _tile.subdomains
                  : const <String>[],
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
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _tile.attribution,
                  prependCopyright: false,
                ),
              ],
            ),
          ],
        ),
        _MapControlColumn(
          gpsBusy: _gpsBusy,
          onGps: _onGpsTap,
          onSaved: _openSavedSheet,
        ),
      ],
    );
  }
}

class _Cs1TileCompareBar extends StatelessWidget {
  const _Cs1TileCompareBar({
    required this.selected,
    required this.onSelected,
  });

  final RegionMapTileId selected;
  final ValueChanged<RegionMapTileId> onSelected;

  @override
  Widget build(BuildContext context) {
    final specs = RegionMapTileCatalog.compareSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '베이스맵 비교 (C.S1 · 운영=A Alidade · 0=롤백)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in specs) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${s.code} ${s.label}'),
                    selected: selected == s.id,
                    onSelected: (_) => onSelected(s.id),
                    selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: selected == s.id
                          ? SoriTokens.primary
                          : (s.canRender
                              ? SoriTokens.textSecondary
                              : const Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControlColumn extends StatelessWidget {
  const _MapControlColumn({
    required this.gpsBusy,
    required this.onGps,
    required this.onSaved,
  });

  final bool gpsBusy;
  final VoidCallback onGps;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapRoundButton(
            label: '현재 위치로 보기',
            busy: gpsBusy,
            icon: Icons.my_location_rounded,
            onPressed: onGps,
          ),
          const SizedBox(height: 8),
          _MapRoundButton(
            label: '저장한 지역 콘텐츠 보기',
            busy: false,
            icon: Icons.bookmark_rounded,
            onPressed: onSaved,
          ),
        ],
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.label,
    required this.busy,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, size: 22, color: SoriTokens.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentPinCard extends StatelessWidget {
  const _ContentPinCard({
    required this.pin,
    required this.bookmarked,
    required this.onToggleSave,
  });

  final RegionMapPin pin;
  final bool bookmarked;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final kindLabel =
        pin.kind == RegionMapPinKind.post ? '커뮤니티 글' : '세미나';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kindLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pin.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: bookmarked ? '저장 해제' : '저장',
            onPressed: onToggleSave,
            icon: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: SoriTokens.primary,
            ),
          ),
        ],
      ),
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
