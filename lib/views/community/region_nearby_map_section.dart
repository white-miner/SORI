import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/biz_profile_store.dart';
import '../../services/region_content_bookmark_store.dart';
import '../../services/region_map_gps.dart';
import '../../services/shop_market_service.dart';
import '../../services/our_area_shop_snapshot.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/naver_map_links.dart';
import '../../utils/area_search_center.dart';
import '../../utils/our_area_category.dart';
import '../../utils/our_area_radius_insight.dart';
import '../../utils/region_shop_list_copy.dart';
import '../../utils/sori_bottom_sheet.dart';
import '../explore_community_post_page.dart';
import '../seminar_class_detail_page.dart';
import '../shop_settings_page.dart';
import 'region_map_bloom.dart';
import 'region_map_clusters.dart';
import 'region_map_content_pins.dart';
import 'region_map_explore_sheet.dart';
import 'region_map_tile_candidates.dart';

/// 우리지역 커뮤니티 탐색 지도 — Local Bloom · glass controls · Peek/Half sheet.
/// Timer / Payment / Visit / 고객 좌표 비노출.
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
  final void Function(double? lat, double? lng)? onCenterChanged;

  @override
  State<RegionNearbyMapSection> createState() => _RegionNearbyMapSectionState();
}

enum _GpsBanner { none, active, denied, failed }

class _RegionNearbyMapSectionState extends State<RegionNearbyMapSection> {
  // The deployed upstream radius contract supports at most 2 km.
  static const _radiiKm = <double>[0.5, 1.0, 2.0];

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _loading = true;
  int _requestEpoch = 0;
  AreaSearchCenter? _activeSearch;
  bool _mapMoved = false;
  String _shopQuery = '';
  int _visibleLimit = 20;
  bool _gpsBusy = false;
  String? _error;
  String? _marketSoftError;
  ShopMarketInsight? _insight;
  ShopMarketStoreItem? _selectedMarket;
  List<RegionMapPin> _contentPins = const [];
  LatLng? _baseCenter;
  LatLng? _gpsCenter;
  LatLng? _mapCamera;
  _GpsBanner _gpsBanner = _GpsBanner.none;
  String _categoryKey = OurAreaCategory.all;
  RegionMapTileId _tileId = RegionMapTileCatalog.productionDefault;
  RegionMapContentFilter _filter = RegionMapContentFilter.all;
  RegionMapSheetMode _sheetMode = RegionMapSheetMode.hidden;
  RegionMapPin? _peekPin;
  List<RegionMapPin> _sheetPins = const [];
  String? _sheetTitle;
  double _zoom = 14.2;
  List<RegionContentBookmark> _savedPreview = const [];

  double get _radiusKm => widget.radiusKm;
  double? get _nextRadiusKm =>
      RegionShopListCopy.nextRadiusKm(_radiusKm, steps: _radiiKm);

  void _widenRadius() {
    final next = _nextRadiusKm;
    if (next == null) return;
    widget.onRadiusChanged?.call(next);
  }

  AreaSearchCenter get _searchCenter => _activeSearch ?? AreaSearchCenter.resolve(
    shopLat: widget.store.shop.latitude,
    shopLng: widget.store.shop.longitude,
  );

  AreaSearchFilterResult<ShopMarketStoreItem> get _storeFilter {
    return AreaSearchCenter.filter<ShopMarketStoreItem>(
      _insight?.storeItems ?? const <ShopMarketStoreItem>[],
      center: _searchCenter,
      radiusKm: _radiusKm,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
      withDistance: (s, m) => s.copyWith(distanceM: m),
    );
  }

  List<ShopMarketStoreItem> get _visibleStores {
    return _storeFilter.items
        .where((s) => s.chipKey != 'other' &&
            ('${s.name} ${s.address}').toLowerCase().contains(_shopQuery.toLowerCase()))
        .where(
          (s) => OurAreaCategory.matches(
            selected: _categoryKey,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .toList();
  }

  LatLng get _viewCenter {
    final c = _searchCenter;
    return LatLng(c.lat, c.lng);
  }
  RegionMapTileSpec get _tile => RegionMapTileCatalog.spec(_tileId);

  List<RegionMapPin> get _filteredPins {
    switch (_filter) {
      case RegionMapContentFilter.all:
        return _contentPins;
      case RegionMapContentFilter.post:
        return _contentPins
            .where((p) => p.kind == RegionMapPinKind.post)
            .toList();
      case RegionMapContentFilter.seminar:
        return _contentPins
            .where((p) => p.kind == RegionMapPinKind.seminar)
            .toList();
    }
  }

  @override
  void initState() {
    super.initState();
    RegionMapTileCatalog.debugLogKeyPresence();
    _reload();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RegionNearbyMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm) {
      _reload(keepGps: true);
    }
  }

  Future<void> _reload({bool keepGps = true, AreaSearchCenter? target, bool force = false}) async {
    final epoch = ++_requestEpoch;
    final radiusM = (_radiusKm * 1000).round();
    setState(() {
      _loading = true;
      _error = null;
      _marketSoftError = null;
      _selectedMarket = null;
      _peekPin = null;
      _sheetMode = RegionMapSheetMode.hidden;
    });
    try {
      var search = target ?? _activeSearch ?? AreaSearchCenter.resolve(
        shopLat: widget.store.shop.latitude,
        shopLng: widget.store.shop.longitude,
      );
      if (search.source == AreaSearchSource.defaultRegion && target == null) {
        var address = widget.store.shop.address?.trim() ?? '';
        if (address.isEmpty && widget.store.shop.id.trim().isNotEmpty) {
          try {
            final biz = await BizProfileStore.load(widget.store.shop.id)
                .timeout(const Duration(seconds: 3));
            address = biz.address.trim();
          } catch (_) { /* Location remains an explicit user choice. */ }
        }
        if (address.isNotEmpty) {
          final resolved = await ShopMarketService.instance
              .resolveNeighborhoodFromAddress(address)
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
          if (resolved != null) search = AreaSearchCenter.resolve(
            insightLat: resolved.latitude, insightLng: resolved.longitude,
          );
        }
        if (search.source == AreaSearchSource.defaultRegion) {
          if (!mounted || epoch != _requestEpoch) return;
          setState(() { _loading = false; _error = 'location_required'; });
          return;
        }
      }
      if (!mounted || epoch != _requestEpoch) return;
      final point = LatLng(search.lat, search.lng);
      setState(() {
        _activeSearch = search;
        _baseCenter = point;
        _insight = null;
        _contentPins = const [];
        _mapMoved = false;
        _visibleLimit = 20;
        _zoom = RegionShopListCopy.mapZoom(_radiusKm);
      });
      try { _mapController.move(point, _zoom); } catch (_) {}
      widget.onCenterChanged?.call(search.lat, search.lng);
      // Community content must never block public shop discovery.
      unawaited(_loadContentPins(search, epoch));
      final insight = await ShopMarketService.instance.fetchNearby(
        latitude: search.lat, longitude: search.lng, radiusM: radiusM, force: force,
      );
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _insight = insight;
        _loading = false;
        if (!insight.storesOk) {
          _error = insight.storesError ?? 'nearby_unavailable';
          _marketSoftError = '주변 샵을 불러오지 못했어요. 다시 시도해 주세요.';
        } else if (!insight.storesComplete) {
          _marketSoftError = '일부 결과만 도착했어요. 표시된 개수는 전체 업소 수가 아닙니다.';
        }
      });
      _debugSearchLog(search);
    } catch (_) {
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _loading = false;
        _error = 'nearby_unavailable';
        _marketSoftError = '주변 샵을 불러오지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _loadContentPins(AreaSearchCenter search, int epoch) async {
    try {
      final pins = await RegionMapContentPins.loadNear(
        store: widget.store, centerLat: search.lat, centerLng: search.lng,
        radiusKm: _radiusKm,
      ).timeout(const Duration(seconds: 5));
      if (mounted && epoch == _requestEpoch) setState(() => _contentPins = pins);
    } catch (_) { /* Public shop results remain usable. */ }
  }

  void _debugSearchLog(AreaSearchCenter search) {
    if (!kDebugMode) return;
    debugPrint(_diagnosticsFor(search).report);
  }

  AreaSearchDiagnostics _diagnosticsFor(AreaSearchCenter search) {
    LatLng? cam = _mapCamera ?? _baseCenter;
    try {
      cam = _mapController.camera.center;
    } catch (_) {}
    return AreaSearchCenter.diagnose<ShopMarketStoreItem>(
      _insight?.storeItems ?? const <ShopMarketStoreItem>[],
      search: search,
      mapLat: cam?.latitude,
      mapLng: cam?.longitude,
      radiusKm: _radiusKm,
      geoStatus: '${_gpsBanner.name}${_error == null ? '' : ' err=$_error'}',
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    );
  }

  Future<void> _searchFromMapCenter() async {
    try { _mapCamera = _mapController.camera.center; } catch (_) {}
    final point = _mapCamera;
    if (point == null) return;
    _gpsCenter = null;
    _gpsBanner = _GpsBanner.none;
    await _reload(target: AreaSearchCenter(
      lat: point.latitude, lng: point.longitude, source: AreaSearchSource.mapCamera,
    ), force: true);
  }

  Future<void> _openAddressSettings() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ShopSettingsPage()),
    );
    if (mounted) { _activeSearch = null; await _reload(); }
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
        return;
      case RegionMapGpsOutcome.failed:
        setState(() => _gpsBanner = _GpsBanner.failed);
        return;
      case RegionMapGpsOutcome.ok:
        await _applyCurrentLocation(result.lat!, result.lng!);
    }
  }

  /// GPS 한 점을 AreaSearchCenter.currentLocation으로 넣고 맵·원·목록을 같이 옮긴다.
  Future<void> _applyCurrentLocation(double lat, double lng) async {
    final search = AreaSearchCenter.currentLocation(lat: lat, lng: lng);
    if (search.source != AreaSearchSource.gps) return;
    setState(() {
      _gpsCenter = LatLng(lat, lng);
      _gpsBanner = _GpsBanner.active;
    });
    await _reload(target: search, force: true);
  }

  Future<void> _showGyeongjuExample() async {
    final point = const LatLng(
      AreaSearchCenter.defaultLat,
      AreaSearchCenter.defaultLng,
    );
    final zoom = RegionShopListCopy.mapZoom(_radiusKm);
    setState(() {
      _gpsCenter = null;
      _gpsBanner = _GpsBanner.none;
      _mapCamera = point;
      _zoom = zoom;
    });
    try {
      _mapController.move(point, zoom);
    } catch (_) {}
    await _reload(keepGps: false);
  }

  Future<void> _openSavedSheet({bool fullList = false}) async {
    await RegionContentBookmarkStore.instance.refresh();
    if (!mounted) return;
    if (!fullList) {
      setState(() {
        _savedPreview = RegionContentBookmarkStore.instance.recent(limit: 3);
        _sheetMode = RegionMapSheetMode.savedHalf;
        _peekPin = null;
        _selectedMarket = null;
      });
      return;
    }
    final items = RegionContentBookmarkStore.instance.items;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RegionMapBloom.sheetCream,
      builder: (ctx) {
        final bottom = soriSheetBottomPadding(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '저장한 지역 콘텐츠',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      '저장한 글과 세미나가 여기에 모여요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final b = items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            b.kind == RegionContentKind.post
                                ? Icons.article_outlined
                                : Icons.event_outlined,
                            color: SoriTokens.primary,
                          ),
                          title: Text(
                            _bookmarkTitle(b),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openBookmark(b);
                          },
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

  Future<void> _openBookmark(RegionContentBookmark b) async {
    if (b.kind == RegionContentKind.seminar) {
      await SeminarClassDetailPage.open(
        context,
        store: widget.store,
        classId: b.targetId,
      );
      return;
    }
    for (final p in widget.store.communityPosts) {
      if (p.id == b.targetId) {
        await ExploreCommunityPostPage.open(
          context,
          store: widget.store,
          post: p,
        );
        return;
      }
    }
  }

  Future<void> _openPin(RegionMapPin pin) async {
    if (pin.kind == RegionMapPinKind.seminar) {
      await SeminarClassDetailPage.open(
        context,
        store: widget.store,
        classId: pin.id,
      );
      return;
    }
    for (final p in widget.store.communityPosts) {
      if (p.id == pin.id) {
        await ExploreCommunityPostPage.open(
          context,
          store: widget.store,
          post: p,
        );
        return;
      }
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd) return;
    try {
      final camera = _mapController.camera;
      final distance = AreaSearchCenter.distanceMeters(
        centerLat: _searchCenter.lat, centerLng: _searchCenter.lng,
        pointLat: camera.center.latitude, pointLng: camera.center.longitude,
      ) ?? 0;
      setState(() {
        _zoom = camera.zoom;
        _mapCamera = camera.center;
        _mapMoved = distance > 30;
      });
    } catch (_) {}
  }

  void _closeSheet() {
    setState(() {
      _sheetMode = RegionMapSheetMode.hidden;
      _peekPin = null;
      _sheetPins = const [];
      _selectedMarket = null;
    });
  }

  void _selectOverlay(RegionMapOverlay overlay) {
    if (overlay.kind == RegionMapOverlayKind.cluster) {
      final b = RegionMapClusters.boundsOf(overlay.pins);
      if (b != null) {
        try {
          _mapController.move(b.center, (_zoom + 1.4).clamp(12.0, 17.0));
        } catch (_) {}
      }
      setState(() {
        _sheetMode = RegionMapSheetMode.clusterHalf;
        _sheetPins = overlay.pins;
        _sheetTitle = '이 지역의 이야기 ${overlay.pins.length}개';
        _peekPin = null;
        _selectedMarket = null;
      });
      return;
    }
    if (overlay.pins.length > 1) {
      setState(() {
        _sheetMode = RegionMapSheetMode.clusterHalf;
        _sheetPins = overlay.pins;
        _sheetTitle = '이 위치의 이야기 ${overlay.pins.length}개';
        _peekPin = null;
        _selectedMarket = null;
      });
      return;
    }
    final pin = overlay.sole;
    setState(() {
      _sheetMode = RegionMapSheetMode.markerPeek;
      _peekPin = pin;
      _sheetPins = const [];
      _selectedMarket = null;
    });
  }

  String? get _gpsStatusText {
    switch (_gpsBanner) {
      case _GpsBanner.active:
        return '현재 위치 주변을 보고 있어요.';
      case _GpsBanner.denied:
      case _GpsBanner.failed:
        return RegionShopListCopy.locationUnavailableBanner(_searchCenter.source);
      case _GpsBanner.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stores = _visibleStores;
    final allStores = _storeFilter.items.where((s) => s.chipKey != 'other').toList();
    final mapH = (MediaQuery.sizeOf(context).height * 0.53).clamp(320.0, 540.0);
    final hasLocation = _activeSearch != null;
    final partial = _insight?.storesOk == true && !_insight!.storesComplete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('region-shop-search'),
          decoration: InputDecoration(
            hintText: '이 반경에서 샵 이름·주소 찾기',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
          onChanged: (value) => setState(() { _shopQuery = value.trim(); _visibleLimit = 20; }),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final key in OurAreaCategory.selectableKeys)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('region-shop-category-$key'),
                  label: Text(_insight?.storesOk == true ? '${OurAreaCategory.labelOf(key)} ${allStores.where((s) => OurAreaCategory.matches(selected: key, chipKey: s.chipKey, categoryLabel: s.categoryLabel)).length}${partial ? '+' : ''}' : OurAreaCategory.labelOf(key)),
                  selected: _categoryKey == key,
                  onSelected: (_) => setState(() { _categoryKey = key; _selectedMarket = null; _visibleLimit = 20; }),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.radar_rounded, size: 18, color: SoriTokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(hasLocation ? RegionShopListCopy.searchBasis(_searchCenter.source) : '탐색할 위치를 선택하세요', style: const TextStyle(fontSize: 13))),
          DropdownButton<double>(
            key: const Key('region-radius'),
            value: _radiiKm.contains(_radiusKm) ? _radiusKm : 1.0,
            underline: const SizedBox.shrink(),
            items: [for (final km in _radiiKm) DropdownMenuItem(value: km, child: Text(RegionShopListCopy.radiusLabel(km)))],
            onChanged: (km) { if (km != null) widget.onRadiusChanged?.call(km); },
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: mapH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(fit: StackFit.expand, children: [
              _buildMapCanvas(stores),
              _MapGlassControls(
                gpsBusy: _gpsBusy, gpsActive: _gpsBanner == _GpsBanner.active,
                onGps: _onGpsTap, onSaved: () => _openSavedSheet(),
              ),
              if (_loading) const Positioned(top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(minHeight: 3)),
              if (_mapMoved || !hasLocation)
                Positioned(top: 12, left: 12, right: 76,
                  child: Align(alignment: Alignment.topCenter,
                    child: FilledButton.icon(
                      key: const Key('region-search-this-area'),
                      onPressed: _loading ? null : _searchFromMapCenter,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('이 위치에서 검색'),
                    ),
                  ),
                ),
              RegionMapExploreSheet(
                sheetController: _sheetController, mode: _sheetMode, filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                onClose: _closeSheet, selectedPin: _peekPin, clusterPins: _sheetPins,
                clusterTitle: _sheetTitle, savedPreview: _savedPreview,
                titleForBookmark: _bookmarkTitle, onOpenPin: _openPin,
                onOpenSavedAll: () => _openSavedSheet(fullList: true),
                onOpenBookmark: _openBookmark,
              ),
              if (_selectedMarket != null)
                Positioned(left: 12, right: 12, bottom: 30,
                  child: Material(elevation: 6, borderRadius: BorderRadius.circular(20),
                    child: Padding(padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_selectedMarket!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                          IconButton(tooltip: '선택 닫기', onPressed: _closeSheet, icon: const Icon(Icons.close_rounded)),
                        ]),
                        Text('${_selectedMarket!.categoryLabel} · ${RegionShopListCopy.distanceLabel(_selectedMarket!.distanceM) ?? '가까운 위치'}'),
                        Text(_selectedMarket!.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                        _NaverMapCta(buttonKey: const Key('region-selected-map-cta'), item: _selectedMarket!, region: ''),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (_gpsStatusText != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_gpsStatusText!)),
        if (!hasLocation && !_loading) ...[
          const Text('내 위치를 사용하거나 지도를 움직여 탐색할 지역을 선택해 주세요.'),
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _onGpsTap, icon: const Icon(Icons.my_location_rounded), label: const Text('내 위치로 찾기'))),
        ] else if (_loading)
          Semantics(liveRegion: true, child: const Text('이 반경의 뷰티샵을 찾고 있어요…'))
        else ...[
          if (_marketSoftError != null) Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 20), const SizedBox(width: 8),
              Expanded(child: Text(_marketSoftError!, style: const TextStyle(fontSize: 13))),
              TextButton(onPressed: () => _reload(force: true), child: const Text('다시 시도')),
            ]),
          ),
          if (_insight?.storesOk == true) ...[
            Semantics(liveRegion: true, child: Text(
              '${RegionShopListCopy.radiusLabel(_radiusKm)} · ${OurAreaCategory.labelOf(_categoryKey)} ${stores.length}곳${partial ? ' · 일부 결과' : ''}',
              key: const Key('region-shop-list-count'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            )),
            const SizedBox(height: 4),
            const Text('공공데이터 등록 업소 · 거리순', style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary)),
            const SizedBox(height: 12),
            if (stores.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(partial ? '아직 이 조건의 샵을 찾지 못했어요. 다시 조회해 주세요.' : '이 조건으로 조회된 샵이 없어요. 업종·검색어·반경을 바꿔보세요.')),
            for (var i = 0; i < stores.length && i < _visibleLimit; i++)
              _MarketStoreRow(item: stores[i], index: i, region: '',
                selected: identical(_selectedMarket, stores[i]) || (_selectedMarket?.name == stores[i].name && _selectedMarket?.address == stores[i].address),
                onSelect: () {
                  setState(() { _selectedMarket = stores[i]; _sheetMode = RegionMapSheetMode.hidden; });
                  try { _mapController.move(LatLng(stores[i].latitude, stores[i].longitude), _zoom); } catch (_) {}
                },
              ),
            if (stores.length > _visibleLimit)
              TextButton(onPressed: () => setState(() => _visibleLimit += 20), child: const Text('샵 더 보기')),
            const SizedBox(height: 8),
            const Text('출처: 소상공인시장진흥공단 상가(상권)정보
등록·갱신 시차로 실제 영업 현황과 다를 수 있어요.',
              style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary, height: 1.5)),
          ],
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMapCanvas(List<ShopMarketStoreItem> stores) {
    final center = _viewCenter;

    final overlays = RegionMapClusters.build(
      pins: _filteredPins,
      zoom: _zoom,
    );

    final markers = <Marker>[
      if (_activeSearch != null) Marker(
        point: center,
        width: 36,
        height: 36,
        child: Icon(
          _gpsBanner == _GpsBanner.active
              ? Icons.near_me_rounded
              : Icons.my_location,
          color: _gpsBanner == _GpsBanner.active
              ? RegionMapBloom.gpsActive
              : SoriTokens.primary,
          size: 28,
        ),
      ),
      for (final s in stores)
        Marker(
          point: LatLng(s.latitude, s.longitude),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedMarket = s;
              _sheetMode = RegionMapSheetMode.hidden;
              _peekPin = null;
            }),
            child: Tooltip(message: '${s.name} · ${s.categoryLabel}', child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Icon(
              Icons.storefront_outlined,
              color: _selectedMarket?.name == s.name &&
                      _selectedMarket?.distanceM == s.distanceM
                  ? SoriTokens.primary
                  : RegionMapBloom.market,
              size: 22,
            ))),
          ),
        ),
      for (final o in overlays)
        Marker(
          point: o.point,
          width: o.isSingle ? 44 : 48,
          height: o.isSingle ? 44 : 48,
          child: GestureDetector(
            onTap: () => _selectOverlay(o),
            child: _OverlayMarker(
              overlay: o,
              selected: _peekPin != null &&
                  o.isSingle &&
                  _peekPin!.id == o.sole.id,
            ),
          ),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: RegionShopListCopy.mapZoom(_radiusKm),
        onMapEvent: _onMapEvent,
        onTap: (_, _) => _closeSheet(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.pinchMove |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        TileLayer(
          key: ValueKey('tiles-${_tile.code}'),
          urlTemplate: _tile.canRender
              ? _tile.urlTemplate
              : RegionMapTileCatalog.spec(RegionMapTileId.osmBaseline)
                  .urlTemplate,
          subdomains: _tile.canRender ? _tile.subdomains : const <String>[],
          userAgentPackageName: 'com.sori.app',
        ),
        CircleLayer(
          circles: [
            if (_activeSearch != null) CircleMarker(
              point: center,
              radius: _radiusKm * 1000,
              useRadiusInMeter: true,
              color: SoriTokens.primary.withValues(alpha: 0.08),
              borderColor: SoriTokens.primary.withValues(alpha: 0.35),
              borderStrokeWidth: 1,
            ),
          ],
        ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(_tile.attribution),
          ],
        ),
      ],
    );
  }
}

class _OverlayMarker extends StatelessWidget {
  const _OverlayMarker({required this.overlay, required this.selected});
  final RegionMapOverlay overlay;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!overlay.isSingle || overlay.kind == RegionMapOverlayKind.cluster) {
      final fill = overlay.allSeminar
          ? RegionMapBloom.seminar
          : RegionMapBloom.post;
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          overlay.countLabel,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
    }
    final pin = overlay.sole;
    final isPost = pin.kind == RegionMapPinKind.post;
    final color = isPost ? RegionMapBloom.post : RegionMapBloom.seminar;
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: RegionMapBloom.selectRing, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              )
            : null,
        child: Icon(
          isPost ? Icons.chat_bubble_rounded : Icons.event_rounded,
          color: color,
          size: 32,
        ),
      ),
    );
  }
}

/// 지도 위 floating control — ClipRRect + BackdropFilter(σ8) · 화면당 소수.
class _MapGlassControls extends StatelessWidget {
  const _MapGlassControls({
    required this.gpsBusy,
    required this.gpsActive,
    required this.onGps,
    required this.onSaved,
  });

  final bool gpsBusy;
  final bool gpsActive;
  final VoidCallback onGps;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassRoundButton(
            label: RegionShopListCopy.findMyLocationLabel,
            busy: gpsBusy,
            active: gpsActive,
            activeColor: RegionMapBloom.gpsActive,
            icon: Icons.my_location_rounded,
            onPressed: onGps,
          ),
          const SizedBox(height: 8),
          _GlassRoundButton(
            label: '저장한 지역 콘텐츠 보기',
            busy: false,
            active: false,
            activeColor: SoriTokens.primary,
            icon: Icons.bookmark_rounded,
            onPressed: onSaved,
          ),
        ],
      ),
    );
  }
}

class _GlassRoundButton extends StatefulWidget {
  const _GlassRoundButton({
    required this.label,
    required this.busy,
    required this.active,
    required this.activeColor,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final bool active;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_GlassRoundButton> createState() => _GlassRoundButtonState();
}

class _GlassRoundButtonState extends State<_GlassRoundButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.active
        ? widget.activeColor.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.86);
    final iconColor =
        widget.active ? widget.activeColor : const Color(0xFF5E5862);

    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            if (!widget.busy) widget.onPressed();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: Duration(milliseconds: _pressed ? 90 : 180),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF211928).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: widget.busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        )
                      : Icon(widget.icon, size: 22, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
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
          '베이스맵 비교 (debug)',
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
                          : SoriTokens.textSecondary,
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

class _ShopListSummary extends StatelessWidget {
  const _ShopListSummary({
    required this.radiusKm,
    required this.category,
    required this.count,
    required this.searchBasis,
    required this.insight,
    this.sources = const [],
  });

  final double radiusKm;
  final String? category;
  final int count;
  final String searchBasis;
  final OurAreaRadiusInsight insight;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final mix = RegionShopListCopy.compositionLine(
      insight.mix.map((row) => (label: row.label, count: row.count)),
    );
    final top = RegionShopListCopy.topCategoryLine(insight.top?.label);
    return Column(
      key: const Key('region-shop-insight'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RegionShopListCopy.headline(
            radiusKm: radiusKm,
            category: category,
          ),
          key: const Key('region-shop-list-summary'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          RegionShopListCopy.conditionLine(
            searchBasis: searchBasis,
            radiusKm: radiusKm,
            category: category,
          ),
          key: const Key('region-shop-insight-condition'),
          style: const TextStyle(
            fontSize: 12,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          RegionShopListCopy.countLine(count),
          key: const Key('region-shop-list-count'),
          style: const TextStyle(
            fontSize: 12,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (mix != null) ...[
          const SizedBox(height: 4),
          Text(
            mix,
            key: const Key('region-shop-insight-mix'),
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (top != null) ...[
          const SizedBox(height: 4),
          Text(
            top,
            key: const Key('region-shop-insight-top'),
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          RegionShopListCopy.provenanceLine(
            sources: sources,
            snapshotDate: OurAreaShopSnapshot.sourceDate,
          ),
          key: const Key('region-shop-provenance'),
          style: const TextStyle(
            fontSize: 11,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ShopListEmpty extends StatelessWidget {
  const _ShopListEmpty({
    required this.kind,
    this.onWiden,
    this.onRetryGps,
    this.onSearchMap,
    this.onShowGyeongjuExample,
  });

  final AreaShopEmptyKind kind;
  final VoidCallback? onWiden;
  final VoidCallback? onRetryGps;
  final VoidCallback? onSearchMap;
  final VoidCallback? onShowGyeongjuExample;

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      AreaShopEmptyKind.locationFailed =>
        RegionShopListCopy.emptyLocationTitle,
      AreaShopEmptyKind.snapshotUnready =>
        RegionShopListCopy.emptySnapshotUnreadyTitle,
      AreaShopEmptyKind.trueZero => RegionShopListCopy.emptyTrueZeroTitle,
    };
    final hint = switch (kind) {
      AreaShopEmptyKind.locationFailed =>
        RegionShopListCopy.emptyLocationHint,
      AreaShopEmptyKind.snapshotUnready =>
        RegionShopListCopy.emptySnapshotUnreadyHint,
      AreaShopEmptyKind.trueZero => RegionShopListCopy.emptyTrueZeroHint,
    };
    final keyName = switch (kind) {
      AreaShopEmptyKind.locationFailed => 'region-shop-list-empty-location',
      AreaShopEmptyKind.snapshotUnready => 'region-shop-list-empty-unready',
      AreaShopEmptyKind.trueZero => 'region-shop-list-empty',
    };

    return Padding(
      key: Key(keyName),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (kind == AreaShopEmptyKind.locationFailed) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onRetryGps != null)
                  OutlinedButton(
                    key: const Key('region-shop-retry-gps'),
                    onPressed: onRetryGps,
                    child: const Text(RegionShopListCopy.retryGpsLabel),
                  ),
                if (onSearchMap != null)
                  FilledButton(
                    key: const Key('region-shop-search-map-center'),
                    onPressed: onSearchMap,
                    child: const Text(RegionShopListCopy.searchFromMapLabel),
                  ),
              ],
            ),
          ] else if (kind == AreaShopEmptyKind.snapshotUnready) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('region-shop-show-gyeongju-example'),
              onPressed: onShowGyeongjuExample,
              child: const Text(RegionShopListCopy.showGyeongjuExampleLabel),
            ),
          ] else if (onWiden != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('region-shop-widen-radius'),
              onPressed: onWiden,
              child: const Text('반경 넓히기'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopDetailFacts extends StatelessWidget {
  const _ShopDetailFacts({
    required this.item,
    this.titleSize = 14,
  });

  final ShopMarketStoreItem item;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final name = RegionShopListCopy.visibleText(item.name);
    final category = RegionShopListCopy.visibleText(item.categoryLabel);
    final distance = AreaSearchCenter.hasValidPoint(
          item.latitude,
          item.longitude,
        )
        ? RegionShopListCopy.distanceLabel(item.distanceM)
        : null;
    final address = RegionShopListCopy.visibleText(item.address);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: titleSize,
            ),
          ),
        if (category != null) ...[
          const SizedBox(height: 4),
          Text(
            category,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
        if (distance != null) ...[
          const SizedBox(height: 4),
          Text(
            distance,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (address != null) ...[
          const SizedBox(height: 4),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.item, required this.region});

  final ShopMarketStoreItem item;
  final String region;

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
          _ShopDetailFacts(item: item, titleSize: 15),
          _NaverMapCta(
            buttonKey: const Key('region-selected-map-cta'),
            item: item,
            region: region,
          ),
        ],
      ),
    );
  }
}

class _MarketStoreRow extends StatelessWidget {
  const _MarketStoreRow({
    required this.item,
    required this.index,
    required this.region,
    required this.selected,
    required this.onSelect,
  });

  final ShopMarketStoreItem item;
  final int index;
  final String region;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('region-market-store-$index'),
          onTap: onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? SoriTokens.primary : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShopDetailFacts(item: item),
                _NaverMapCta(
                  buttonKey: Key('region-market-map-cta-$index'),
                  item: item,
                  region: region,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NaverMapCta extends StatelessWidget {
  const _NaverMapCta({
    required this.buttonKey,
    required this.item,
    required this.region,
  });

  final Key buttonKey;
  final ShopMarketStoreItem item;
  final String region;

  @override
  Widget build(BuildContext context) {
    final uri = NaverMapLinks.uri(
      name: item.name,
      address: item.address,
      region: region,
    );
    if (uri == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          key: buttonKey,
          onPressed: () async {
            var ok = false;
            try { ok = await NaverMapLinks.open(uri); } catch (_) {}
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('지도를 열 수 없어요.')),
              );
            }
          },
          child: const Text('네이버에서 샵 찾기'),
        ),
      ),
    );
  }
}

