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
  static const _radiiKm = RegionShopListCopy.radiusStepsKm;

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _loading = true;
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

  AreaSearchCenter get _searchCenter {
    LatLng? cam = _mapCamera;
    try {
      cam = _mapController.camera.center;
    } catch (_) {}
    return AreaSearchCenter.resolve(
      gpsLat: _gpsCenter?.latitude,
      gpsLng: _gpsCenter?.longitude,
      mapLat: cam?.latitude ?? _baseCenter?.latitude,
      mapLng: cam?.longitude ?? _baseCenter?.longitude,
      insightLat: _insight?.centerLatitude,
      insightLng: _insight?.centerLongitude,
      shopLat: widget.store.shop.latitude,
      shopLng: widget.store.shop.longitude,
    );
  }

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

  Future<void> _reload({bool keepGps = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _marketSoftError = null;
      _selectedMarket = null;
      _peekPin = null;
      _sheetMode = RegionMapSheetMode.hidden;
      if (!keepGps) {
        _gpsCenter = null;
        _gpsBanner = _GpsBanner.none;
      }
    });
    final shop = widget.store.shop;
    final biz = await BizProfileStore.load(shop.id);
    final bizAddr = biz.address.trim();
    await Future.wait([
      widget.store.refreshCommunityPosts(force: true),
      widget.store.refreshCommunityHotCases(),
    ]);
    final search = AreaSearchCenter.resolve(
      gpsLat: keepGps ? _gpsCenter?.latitude : null,
      gpsLng: keepGps ? _gpsCenter?.longitude : null,
      mapLat: _mapCamera?.latitude,
      mapLng: _mapCamera?.longitude,
      shopLat: shop.latitude,
      shopLng: shop.longitude,
    );
    final insight = await ShopMarketService.instance.fetch(
      shop: shop,
      category: '전체',
      fallbackAddress: bizAddr.isEmpty ? null : bizAddr,
      radiusM: (_radiusKm * 1000).round(),
      overrideLat: search.lat,
      overrideLng: search.lng,
    );
    if (!mounted) return;
    final center = LatLng(search.lat, search.lng);
    final pins = await RegionMapContentPins.loadNear(
      store: widget.store,
      centerLat: search.lat,
      centerLng: search.lng,
      radiusKm: _radiusKm,
    );

    setState(() {
      _insight = insight;
      _baseCenter = center;
      _contentPins = pins;
      _loading = false;
      if (!insight.storesOk) {
        _error = insight.storesError;
        _marketSoftError = ShopMarketService.friendlyReason(insight.storesError);
      } else {
        _error = null;
      }
    });
    widget.onCenterChanged?.call(search.lat, search.lng);
    _debugSearchLog(search);
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
    try {
      _mapCamera = _mapController.camera.center;
    } catch (_) {}
    await _reload(keepGps: false);
  }

  Future<void> _openAddressSettings() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ShopSettingsPage()),
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
        await _reload(keepGps: false);
        if (mounted) setState(() => _gpsBanner = _GpsBanner.denied);
        return;
      case RegionMapGpsOutcome.failed:
        await _reload(keepGps: false);
        if (mounted) setState(() => _gpsBanner = _GpsBanner.failed);
        return;
      case RegionMapGpsOutcome.ok:
        await _applyCurrentLocation(result.lat!, result.lng!);
    }
  }

  /// GPS 한 점을 AreaSearchCenter.currentLocation으로 넣고 맵·원·목록을 같이 옮긴다.
  Future<void> _applyCurrentLocation(double lat, double lng) async {
    final search = AreaSearchCenter.currentLocation(lat: lat, lng: lng);
    if (search.source != AreaSearchSource.gps) return;
    final point = LatLng(search.lat, search.lng);
    final zoom = RegionShopListCopy.mapZoom(_radiusKm);
    setState(() {
      _gpsCenter = point;
      _mapCamera = point;
      _gpsBanner = _GpsBanner.active;
      _error = null;
      _zoom = zoom;
    });
    try {
      _mapController.move(point, zoom);
    } catch (_) {}
    widget.onCenterChanged?.call(search.lat, search.lng);

    final biz = await BizProfileStore.load(widget.store.shop.id);
    final pinsFuture = RegionMapContentPins.loadNear(
      store: widget.store,
      centerLat: search.lat,
      centerLng: search.lng,
      radiusKm: _radiusKm,
    );
    final insight = await ShopMarketService.instance.fetch(
      shop: widget.store.shop,
      category: '전체',
      fallbackAddress: biz.address.trim().isEmpty ? null : biz.address.trim(),
      radiusM: (_radiusKm * 1000).round(),
      overrideLat: search.lat,
      overrideLng: search.lng,
    );
    final pins = await pinsFuture;
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _contentPins = pins;
      _peekPin = null;
      _sheetMode = RegionMapSheetMode.hidden;
      _baseCenter = point;
      _marketSoftError = insight.storesOk
          ? null
          : ShopMarketService.friendlyReason(insight.storesError);
    });
    _debugSearchLog(search);
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
    if (event is MapEventMoveEnd) {
      try {
        _zoom = _mapController.camera.zoom;
        _mapCamera = _mapController.camera.center;
      } catch (_) {}
      if (_gpsBanner == _GpsBanner.active &&
          event.source != MapEventSource.mapController) {
        setState(() => _gpsBanner = _GpsBanner.none);
      } else {
        setState(() {});
      }
    }
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
    final screenH = MediaQuery.sizeOf(context).height;
    final mapH = (screenH * 0.52).clamp(280.0, 520.0);
    final gpsText = _gpsStatusText;
    final stores = _visibleStores;
    final search = _searchCenter;
    final emptyKind = RegionShopListCopy.emptyKind(
      permissionDeniedOrFailed: _gpsBanner == _GpsBanner.denied ||
          _gpsBanner == _GpsBanner.failed,
      usingCurrentLocation: search.source == AreaSearchSource.gps,
      snapshotCoversCenter: OurAreaShopSnapshot.covers(search.lat, search.lng),
    );
    final locationFailed = emptyKind == AreaShopEmptyKind.locationFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: mapH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMapCanvas(stores),
                _MapGlassControls(
                  gpsBusy: _gpsBusy,
                  gpsActive: _gpsBanner == _GpsBanner.active,
                  onGps: _onGpsTap,
                  onSaved: () => _openSavedSheet(),
                ),
                RegionMapExploreSheet(
                  sheetController: _sheetController,
                  mode: _sheetMode,
                  filter: _filter,
                  onFilterChanged: (f) {
                    setState(() {
                      _filter = f;
                      // 필터는 중심 유지 · marker만 갱신 (시트 detent 유지)
                    });
                  },
                  onClose: _closeSheet,
                  selectedPin: _peekPin,
                  clusterPins: _sheetPins,
                  clusterTitle: _sheetTitle,
                  savedPreview: _savedPreview,
                  titleForBookmark: _bookmarkTitle,
                  onOpenPin: _openPin,
                  onOpenSavedAll: () => _openSavedSheet(fullList: true),
                  onOpenBookmark: _openBookmark,
                ),
              ],
            ),
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
          if (locationFailed) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('region-shop-retry-gps'),
              onPressed: _onGpsTap,
              child: const Text(RegionShopListCopy.retryGpsLabel),
            ),
          ],
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          Text(
            key: const Key('area-search-diagnostics'),
            _diagnosticsFor(_searchCenter).report,
            style: const TextStyle(
              fontSize: 10,
              height: 1.35,
              color: SoriTokens.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openAddressSettings,
              child: const Text('주소로 중심 잡기'),
            ),
          ),
          _Cs1TileCompareBar(
            selected: _tileId,
            onSelected: (id) {
              final next = RegionMapTileCatalog.spec(id);
              if (!next.canRender) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${next.label} 키가 없어요. .env에 ${next.keyHint}를 넣으세요.',
                    ),
                  ),
                );
                return;
              }
              setState(() => _tileId = id);
            },
          ),
        ],
        const SizedBox(height: 10),
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
                  label: Text(
                    km < 1
                        ? '${(km * 1000).round()}m'
                        : '${km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1)}km',
                  ),
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
              onPressed: _loading ? null : () => _reload(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final key in OurAreaCategory.selectableKeys)
              ChoiceChip(
                key: Key('region-shop-category-$key'),
                label: Text(OurAreaCategory.labelOf(key)),
                selected: _categoryKey == key,
                onSelected: (_) {
                  if (_categoryKey == key) return;
                  setState(() {
                    _categoryKey = key;
                    _selectedMarket = null;
                  });
                },
                selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          if (_marketSoftError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _marketSoftError!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _reload(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '반경 ${_radiusKm < 1 ? '${(_radiusKm * 1000).round()}m' : '${_radiusKm}km'} · '
              '상권 ${stores.length}곳 · 글/세미나 ${_filteredPins.length}',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectedMarket != null)
            _SelectedCard(
              item: _selectedMarket!,
              region: (widget.store.shop.address ?? '').trim(),
            ),
          const SizedBox(height: 8),
          _ShopListSummary(
            radiusKm: _radiusKm,
            category: OurAreaCategory.labelOf(_categoryKey),
            count: stores.length,
            searchBasis: RegionShopListCopy.searchBasis(_searchCenter.source),
            insight: OurAreaRadiusInsight.fromMappedKeys(
              stores.map((s) => s.chipKey),
            ),
            sources: _insight?.sources ?? const <String>[],
          ),
          if (stores.isEmpty)
            _ShopListEmpty(
              kind: emptyKind,
              onWiden: _nextRadiusKm == null || widget.onRadiusChanged == null
                  ? null
                  : _widenRadius,
              onRetryGps: locationFailed ? null : _onGpsTap,
              onSearchMap: _searchFromMapCenter,
              onShowGyeongjuExample: _showGyeongjuExample,
            )
          else ...[
            const SizedBox(height: 6),
            for (var i = 0; i < stores.length; i++)
              _MarketStoreRow(
                item: stores[i],
                index: i,
                region: (widget.store.shop.address ?? '').trim(),
                selected: _selectedMarket?.name == stores[i].name &&
                    _selectedMarket?.distanceM == stores[i].distanceM,
                onSelect: () => setState(() => _selectedMarket = stores[i]),
              ),
          ],
        ],
        const SizedBox(height: 4),
        const Text(
          '출처: 소상공인시장진흥공단 상가(상권)정보 · 추정·참고용',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildMapCanvas(List<ShopMarketStoreItem> stores) {
    final center = _viewCenter;
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final overlays = RegionMapClusters.build(
      pins: _filteredPins,
      zoom: _zoom,
    );

    final markers = <Marker>[
      Marker(
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
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedMarket = s;
              _sheetMode = RegionMapSheetMode.hidden;
              _peekPin = null;
            }),
            child: Icon(
              Icons.storefront_outlined,
              color: _selectedMarket?.name == s.name &&
                      _selectedMarket?.distanceM == s.distanceM
                  ? SoriTokens.primary
                  : RegionMapBloom.market,
              size: 22,
            ),
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
            CircleMarker(
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
      latitude: item.latitude,
      longitude: item.longitude,
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
            final ok = await NaverMapLinks.open(uri);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('지도를 열 수 없어요.')),
              );
            }
          },
          child: const Text('지도에서 보기'),
        ),
      ),
    );
  }
}
