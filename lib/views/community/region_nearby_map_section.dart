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
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/naver_map_links.dart';
import '../../utils/area_search_center.dart';
import '../../utils/our_area_category.dart';
import '../../utils/region_shop_list_copy.dart';
import '../../utils/sori_bottom_sheet.dart';
import '../explore_community_post_page.dart';
import '../seminar_class_detail_page.dart';
import 'region_map_bloom.dart';
import 'region_map_clusters.dart';
import 'region_map_content_pins.dart';
import 'region_map_explore_sheet.dart';
import 'region_map_tile_candidates.dart';

typedef RegionNearbyLoader = Future<ShopMarketInsight> Function({
  required double latitude,
  required double longitude,
  required int radiusM,
  bool force,
});

/// 우리지역 커뮤니티 탐색 지도 — Local Bloom · glass controls · Peek/Half sheet.
/// Timer / Payment / Visit / 고객 좌표 비노출.
class RegionNearbyMapSection extends StatefulWidget {
  const RegionNearbyMapSection({
    super.key,
    required this.store,
    this.radiusKm = 1.0,
    this.onRadiusChanged,
    this.onCenterChanged,
    this.sheetFooter,
    this.nearbyLoader,
  });

  final SoriStore store;
  final double radiusKm;
  final ValueChanged<double>? onRadiusChanged;
  final void Function(double? lat, double? lng)? onCenterChanged;
  /// 시트 맨 아래. 우리 동네 게시물처럼 지도 밖 목록을 시트 스크롤에 붙인다.
  final Widget? sheetFooter;
  /// 테스트가 공공 API 없이 같은 목록 경로를 열 때 쓴다. 없으면 Edge 조회.
  final RegionNearbyLoader? nearbyLoader;

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
  LatLng? _mapCamera;
  _GpsBanner _gpsBanner = _GpsBanner.none;
  String _categoryKey = OurAreaCategory.all;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<String> _recentSearches = <String>[];
  static const _popularSearches = <String>[
    '피부관리',
    '네일',
    '헤어',
    '바버',
    '타투',
    '반영구',
    '두피관리',
  ];
  final RegionMapTileId _tileId = RegionMapTileCatalog.productionDefault;
  RegionMapContentFilter _filter = RegionMapContentFilter.all;
  RegionMapSheetMode _sheetMode = RegionMapSheetMode.hidden;
  RegionMapPin? _peekPin;
  List<RegionMapPin> _sheetPins = const [];
  String? _sheetTitle;
  double _zoom = 14.2;
  List<RegionContentBookmark> _savedPreview = const [];

  double get _radiusKm => widget.radiusKm;
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

  List<ShopMarketStoreItem> get _radiusShops => _storeFilter.items;

  int _countFor(String key) {
    return _radiusShops
        .where(
          (s) => OurAreaCategory.matches(
            selected: key,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .length;
  }

  List<ShopMarketStoreItem> get _visibleStores {
    final query = _shopQuery.trim().toLowerCase();
    return _radiusShops
        .where(
          (s) => OurAreaCategory.matches(
            selected: _categoryKey,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .where((s) => query.isEmpty || _shopHaystack(s).contains(query))
        .toList();
  }

  List<ShopMarketStoreItem> _searchHits(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _radiusShops
        .where((s) => _shopHaystack(s).contains(query))
        .toList();
  }

  String _shopHaystack(ShopMarketStoreItem item) {
    return '${item.name} ${item.searchPlace} ${item.adongNm} ${item.industryDisplay} ${item.categoryLabel} ${OurAreaCategory.chipLabel(item.chipKey)}'
        .toLowerCase();
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
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RegionNearbyMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm) {
      _reload();
    }
  }

  Future<void> _reload({AreaSearchCenter? target, bool force = false}) async {
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
      final loader = widget.nearbyLoader ?? ShopMarketService.instance.fetchNearby;
      final insight = await loader(
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
    _gpsBanner = _GpsBanner.none;
    await _reload(target: AreaSearchCenter(
      lat: point.latitude, lng: point.longitude, source: AreaSearchSource.mapCamera,
    ), force: true);
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
      _gpsBanner = _GpsBanner.active;
    });
    await _reload(target: search, force: true);
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

  bool _sameShop(ShopMarketStoreItem? a, ShopMarketStoreItem b) {
    if (a == null) return false;
    return identical(a, b) ||
        (a.name == b.name && a.address == b.address && a.lotAddress == b.lotAddress);
  }

  void _selectShop(ShopMarketStoreItem item, {bool fromSearch = false}) {
    final chip = OurAreaCategory.selectableKeys.contains(item.chipKey)
        ? item.chipKey
        : OurAreaCategory.all;
    setState(() {
      if (fromSearch) {
        _searchOpen = false;
        _shopQuery = '';
        _categoryKey = chip;
      }
      _selectedMarket = item;
      _sheetMode = RegionMapSheetMode.hidden;
      _peekPin = null;
    });
    final nextZoom = _zoom < 15.2 ? 15.2 : _zoom;
    try {
      _mapController.move(LatLng(item.latitude, item.longitude), nextZoom);
      _zoom = nextZoom;
    } catch (_) {}
    _snapSheet(0.52);
  }

  void _snapSheet(double size) {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      size,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() => _searchOpen = false);
  }

  void _onSearchDismiss() {
    if (_searchController.text.trim().isNotEmpty) {
      _searchController.clear();
      setState(() {});
      return;
    }
    _closeSearch();
  }

  void _runSearch(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _recentSearches.remove(text);
      _recentSearches.insert(0, text);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    });
  }

  String get _basisLine {
    final address = widget.store.shop.address?.trim() ?? '';
    switch (_searchCenter.source) {
      case AreaSearchSource.gps:
        return '현재 위치';
      case AreaSearchSource.mapCamera:
        return '지도에서 고른 위치';
      case AreaSearchSource.shopOrInsight:
        return address.isEmpty ? '내 샵' : '내 샵 · $address';
      case AreaSearchSource.defaultRegion:
        return address.isEmpty ? '검색 기준 위치가 필요합니다' : address;
    }
  }

  double? get _widerRadius {
    final index = _radiiKm.indexWhere((km) => (km - _radiusKm).abs() < 0.01);
    if (index < 0 || index >= _radiiKm.length - 1) return null;
    return _radiiKm[index + 1];
  }

  List<_ShopBunch> _bunchShops(List<ShopMarketStoreItem> stores) {
    final selected = <ShopMarketStoreItem>[];
    final pool = <ShopMarketStoreItem>[];
    for (final shop in stores) {
      if (_sameShop(_selectedMarket, shop)) {
        selected.add(shop);
      } else {
        pool.add(shop);
      }
    }
    final showEach = _zoom >= 15.2 || pool.length <= 8;
    final bunches = <_ShopBunch>[];
    if (showEach) {
      for (final shop in pool) {
        bunches.add(_ShopBunch(point: LatLng(shop.latitude, shop.longitude), items: [shop]));
      }
    } else {
      final cell = _zoom >= 13.4 ? 0.0045 : 0.012;
      final buckets = <String, List<ShopMarketStoreItem>>{};
      for (final shop in pool) {
        final key = '${(shop.latitude / cell).floor()}|${(shop.longitude / cell).floor()}';
        (buckets[key] ??= []).add(shop);
      }
      for (final group in buckets.values) {
        var lat = 0.0;
        var lng = 0.0;
        for (final shop in group) {
          lat += shop.latitude;
          lng += shop.longitude;
        }
        bunches.add(_ShopBunch(
          point: LatLng(lat / group.length, lng / group.length),
          items: group,
        ));
      }
    }
    for (final shop in selected) {
      bunches.add(_ShopBunch(point: LatLng(shop.latitude, shop.longitude), items: [shop]));
    }
    return bunches;
  }

  @override
  Widget build(BuildContext context) {
    final stores = _visibleStores;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.78;
        return Material(
          color: SoriTokens.background,
          child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBrowseHeader(),
              Expanded(
                child: _searchOpen
                    ? _buildSearchMode()
                    : _buildMapStage(stores),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildBrowseHeader() {
    if (_searchOpen) {
      final hasText = _searchController.text.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('region-search-back'),
              tooltip: '검색 닫기',
              onPressed: _closeSearch,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: TextField(
                key: const Key('region-shop-search'),
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: '업소, 주소, 업종 검색',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    key: const Key('region-search-submit'),
                    tooltip: '검색',
                    onPressed: () => _runSearch(_searchController.text),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('region-search-close'),
              tooltip: hasText ? '검색어 지우기' : '검색 닫기',
              onPressed: _onSearchDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '우리지역',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SoriTokens.textPrimary),
            ),
          ),
          IconButton(
            key: const Key('region-search-open'),
            tooltip: '업소 검색',
            onPressed: _openSearch,
            iconSize: 26,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchMode() {
    final query = _searchController.text.trim();
    final hits = _searchHits(query);
    return ListView(
      key: const Key('region-search-body'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (query.isEmpty) ...[
          const Text('인기 검색어', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in _popularSearches)
                ActionChip(
                  key: Key('region-popular-$word'),
                  label: Text(word),
                  onPressed: () => _runSearch(word),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text('최근 검색어', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (_recentSearches.isNotEmpty)
                TextButton(
                  key: const Key('region-recent-clear-all'),
                  onPressed: () => setState(_recentSearches.clear),
                  child: const Text('전체삭제'),
                ),
            ],
          ),
          if (_recentSearches.isEmpty)
            const Text('최근 검색어가 없어요.', style: TextStyle(color: SoriTokens.textSecondary))
          else
            for (final word in _recentSearches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(word),
                onTap: () => _runSearch(word),
                trailing: IconButton(
                  key: Key('region-recent-clear-$word'),
                  tooltip: '최근 검색어 삭제',
                  onPressed: () => setState(() => _recentSearches.remove(word)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
        ] else ...[
          Text('검색 결과 ${hits.length}곳', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (hits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('이 반경에서 맞는 업소를 찾지 못했어요.'),
            )
          else
            for (final item in hits.take(30))
              ListTile(
                key: Key('region-search-hit-${item.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${OurAreaCategory.chipLabel(item.chipKey)} · ${_regionShown(item.adongNm)} · ${_regionShown(item.address)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectShop(item, fromSearch: true),
              ),
        ],
      ],
    );
  }

  Widget _buildMapStage(List<ShopMarketStoreItem> stores) {
    final hasLocation = _activeSearch != null;
    final partial = _insight?.storesOk == true && !_insight!.storesComplete;
    final sourceText = _insight?.sourceText ?? ShopMarketInsight.fieldUnavailable;
    final queryTimeText = _insight?.queryTimeText ?? ShopMarketInsight.fieldUnavailable;
    final countLabel =
        '${RegionShopListCopy.radiusLabel(_radiusKm)} · ${OurAreaCategory.chipLabel(_categoryKey)} ${stores.length}곳${partial ? ' · 일부 결과' : ''}';
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RegionMapBloom.mapClipRadius),
          child: _buildMapCanvas(stores),
        ),
        if (_mapMoved || !hasLocation)
          Positioned(
            top: 64,
            left: 12,
            child: FilledButton.icon(
              key: const Key('region-search-this-area'),
              onPressed: _loading ? null : _searchFromMapCenter,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('이 위치에서 검색'),
            ),
          ),
        _MapGlassControls(
          gpsBusy: _gpsBusy,
          gpsActive: _gpsBanner == _GpsBanner.active,
          onGps: _onGpsTap,
          onSaved: () => _openSavedSheet(),
        ),
        if (_loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
        if (_sheetMode == RegionMapSheetMode.hidden)
        DraggableScrollableSheet(
          key: const Key('region-result-sheet'),
          controller: _sheetController,
          initialChildSize: 0.22,
          minChildSize: 0.16,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.22, 0.52],
          builder: (context, scrollController) {
            return _ShopResultSheet(
              scrollController: scrollController,
              stores: stores,
              countLabel: countLabel,
              basis: Row(
                children: [
                  Expanded(
                    child: Text(
                      _basisLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3C), fontWeight: FontWeight.w600),
                    ),
                  ),
                  DropdownButton<double>(
                    key: const Key('region-radius'),
                    value: _radiiKm.contains(_radiusKm) ? _radiusKm : 1.0,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final km in _radiiKm)
                        DropdownMenuItem(value: km, child: Text(RegionShopListCopy.radiusLabel(km))),
                    ],
                    onChanged: (km) {
                      if (km != null) widget.onRadiusChanged?.call(km);
                    },
                  ),
                ],
              ),
              partial: partial,
              loading: _loading,
              error: _error,
              softError: _marketSoftError,
              gpsStatus: _gpsStatusText,
              hasLocation: hasLocation,
              sourceText: sourceText,
              queryTimeText: queryTimeText,
              selected: _selectedMarket,
              sameShop: _sameShop,
              visibleLimit: _visibleLimit,
              widerRadius: _widerRadius,
              onSelect: _selectShop,
              onClearSelection: () => setState(() => _selectedMarket = null),
              onRetry: () => _reload(force: true),
              onGps: _onGpsTap,
              onWiden: _widerRadius == null
                  ? null
                  : () => widget.onRadiusChanged?.call(_widerRadius!),
              onMore: () => setState(() => _visibleLimit += 20),
              footer: widget.sheetFooter,
            );
          },
        )
        else
          RegionMapExploreSheet(
            sheetController: _sheetController,
            mode: _sheetMode,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
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
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 48,
            child: ListView(
              key: const Key('region-category-chips'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final key in OurAreaCategory.selectableKeys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MapCategoryChip(
                      chipKey: key,
                      label: _insight?.storesOk == true
                          ? '${OurAreaCategory.chipLabel(key)} ${_countFor(key)}${partial ? '+' : ''}'
                          : OurAreaCategory.chipLabel(key),
                      selected: _categoryKey == key,
                      onTap: () => setState(() {
                        _categoryKey = key;
                        _selectedMarket = null;
                        _visibleLimit = 20;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
      for (final bunch in _bunchShops(stores))
        if (bunch.items.length == 1)
          Marker(
            point: bunch.point,
            width: _sameShop(_selectedMarket, bunch.items.first) ? 56 : 40,
            height: _sameShop(_selectedMarket, bunch.items.first) ? 56 : 40,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _selectShop(bunch.items.first),
              child: Tooltip(
                message: '${bunch.items.first.name} · ${bunch.items.first.categoryLabel}',
                child: _ShopMarkerFace(
                  selected: _sameShop(_selectedMarket, bunch.items.first),
                  label: _zoom >= 15.2 ? bunch.items.first.name : null,
                ),
              ),
            ),
          )
        else
          Marker(
            point: bunch.point,
            width: 46,
            height: 46,
            child: GestureDetector(
              onTap: () {
                try {
                  _mapController.move(bunch.point, (_zoom + 1.6).clamp(12.0, 17.0));
                } catch (_) {}
              },
              child: Tooltip(
                message: '이 구역 ${bunch.items.length}곳',
                child: _ShopClusterFace(count: bunch.items.length),
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

// 예전 검색 패널. 지도 위 칩과 헤더 검색으로 갈라진 뒤에도 호출 경로는 남긴다.
// ignore: unused_element
class _MapFilterPanel extends StatelessWidget {
  const _MapFilterPanel({required this.search, required this.chips});

  final Widget search;
  final Widget chips;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RegionMapBloom.panelFill,
        borderRadius: BorderRadius.circular(RegionMapBloom.shopCardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: const [RegionMapBloom.panelShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 8),
            chips,
          ],
        ),
      ),
    );
  }
}

class _ShopMarkerFace extends StatelessWidget {
  const _ShopMarkerFace({required this.selected, this.label});

  final bool selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: RegionMapBloom.shopSelectRing, width: 2.5)
            : null,
        boxShadow: [
          if (selected)
            const BoxShadow(
              color: RegionMapBloom.shopSelectGlow,
              blurRadius: 12,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.storefront_outlined,
        color: selected ? RegionMapBloom.shopSelectRing : RegionMapBloom.market,
        size: 22,
      ),
    ),
    );
  }
}

class _ShopClusterFace extends StatelessWidget {
  const _ShopClusterFace({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3C),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _ShopBunch {
  const _ShopBunch({required this.point, required this.items});

  final LatLng point;
  final List<ShopMarketStoreItem> items;
}

class _MapCategoryChip extends StatelessWidget {
  const _MapCategoryChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SoriTokens.brand : Colors.white,
      elevation: selected ? 0 : 1,
      shadowColor: const Color(0x14000000),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: Key('region-shop-category-$chipKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF3A3A3C),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedShopGlass extends StatelessWidget {
  const _SelectedShopGlass({
    required this.item,
    required this.sourceText,
    required this.queryTimeText,
    required this.onClose,
  });

  final ShopMarketStoreItem item;
  final String sourceText;
  final String queryTimeText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RegionMapBloom.panelFill,
        borderRadius: BorderRadius.circular(RegionMapBloom.shopCardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: const [RegionMapBloom.panelShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: RegionMapBloom.shopTitleSize,
                      fontWeight: FontWeight.w800,
                      color: RegionMapBloom.shopTitleColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '선택 닫기',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '${_regionShown(item.industryDisplay)} · ${_regionDistance(item)} · ${_regionShown(item.adongNm)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: RegionMapBloom.shopMetaSize,
                color: RegionMapBloom.shopMetaColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _regionShown(item.address),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: RegionMapBloom.shopMetaSize,
                color: RegionMapBloom.shopTitleColor,
              ),
            ),
            _NaverMapCta(
              buttonKey: const Key('region-selected-map-cta'),
              item: item,
              region: '',
            ),
            _PublicShopFacts(
              item: item,
              sourceText: sourceText,
              queryTimeText: queryTimeText,
            ),
          ],
        ),
      ),
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

class _PublicShopFacts extends StatelessWidget {
  const _PublicShopFacts({
    required this.item,
    required this.sourceText,
    required this.queryTimeText,
  });

  final ShopMarketStoreItem item;
  final String sourceText;
  final String queryTimeText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fact('지번', item.lotAddress),
        _fact('출처', sourceText),
        _fact('조회 시점', queryTimeText),
      ],
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label ${_regionShown(value)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: RegionMapBloom.shopAuxSize,
          color: RegionMapBloom.shopMetaColor,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ShopDetailFacts extends StatelessWidget {
  const _ShopDetailFacts({required this.item});

  final ShopMarketStoreItem item;

  @override
  Widget build(BuildContext context) {
    final name = RegionShopListCopy.visibleText(item.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: RegionMapBloom.shopTitleSize,
              color: RegionMapBloom.shopTitleColor,
            ),
          ),
        Text(
          '${_regionShown(item.industryDisplay)} · ${_regionShown(item.adongNm)} · ${_regionDistance(item)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: RegionMapBloom.shopMetaSize,
            color: RegionMapBloom.shopMetaColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _regionShown(item.address),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: RegionMapBloom.shopMetaSize,
            color: RegionMapBloom.shopTitleColor,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(RegionMapBloom.shopCardRadius),
        child: InkWell(
          key: Key('region-market-store-$index'),
          onTap: onSelect,
          borderRadius: BorderRadius.circular(RegionMapBloom.shopCardRadius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RegionMapBloom.shopCardRadius),
              border: Border.all(
                color: selected
                    ? RegionMapBloom.shopSelectRing
                    : const Color(0xFFE5E7EB),
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

String _regionShown(String raw) {
  final text = raw.trim();
  return text.isEmpty ? ShopMarketInsight.fieldUnavailable : text;
}

String _regionDistance(ShopMarketStoreItem item) {
  if (!AreaSearchCenter.hasValidPoint(item.latitude, item.longitude)) {
    return ShopMarketInsight.fieldUnavailable;
  }
  return _regionShown(RegionShopListCopy.distanceLabel(item.distanceM) ?? '');
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
    final place = item.searchPlace;
    final uri = NaverMapLinks.uri(
      name: item.name,
      address: place.isEmpty ? null : place,
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

class _ShopResultSheet extends StatelessWidget {
  const _ShopResultSheet({
    required this.scrollController,
    required this.stores,
    required this.countLabel,
    required this.basis,
    required this.partial,
    required this.loading,
    required this.error,
    required this.softError,
    required this.gpsStatus,
    required this.hasLocation,
    required this.sourceText,
    required this.queryTimeText,
    required this.selected,
    required this.sameShop,
    required this.visibleLimit,
    required this.widerRadius,
    required this.onSelect,
    required this.onClearSelection,
    required this.onRetry,
    required this.onGps,
    required this.onWiden,
    required this.onMore,
    required this.footer,
  });

  final ScrollController scrollController;
  final List<ShopMarketStoreItem> stores;
  final String countLabel;
  final Widget basis;
  final bool partial;
  final bool loading;
  final String? error;
  final String? softError;
  final String? gpsStatus;
  final bool hasLocation;
  final String sourceText;
  final String queryTimeText;
  final ShopMarketStoreItem? selected;
  final bool Function(ShopMarketStoreItem?, ShopMarketStoreItem) sameShop;
  final int visibleLimit;
  final double? widerRadius;
  final ValueChanged<ShopMarketStoreItem> onSelect;
  final VoidCallback onClearSelection;
  final VoidCallback onRetry;
  final VoidCallback onGps;
  final VoidCallback? onWiden;
  final VoidCallback onMore;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final shown = stores.take(visibleLimit).toList();
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x14000000),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          basis,
          const SizedBox(height: 4),
          Text(
            countLabel,
            key: const Key('region-shop-list-count'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            '공공데이터 등록 업소 · 거리순',
            style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          if (gpsStatus != null) ...[
            const SizedBox(height: 8),
            Text(gpsStatus!, style: const TextStyle(fontSize: 13)),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('이 반경의 뷰티샵을 찾고 있어요…'),
            )
          else if (!hasLocation || error == 'location_required') ...[
            const SizedBox(height: 12),
            const Text('검색 기준 위치가 필요합니다.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onGps,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('현재 위치 사용'),
              ),
            ),
          ] else if (error != null) ...[
            const SizedBox(height: 12),
            Text(softError ?? '주변 샵을 불러오지 못했어요. 다시 시도해 주세요.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ),
          ] else ...[
            if (softError != null) ...[
              const SizedBox(height: 8),
              Text(softError!, style: const TextStyle(fontSize: 13)),
            ],
            if (selected != null) ...[
              const SizedBox(height: 8),
              _SelectedShopGlass(
                item: selected!,
                sourceText: sourceText,
                queryTimeText: queryTimeText,
                onClose: onClearSelection,
              ),
            ],
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length.clamp(0, 8),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = shown[index];
                    return SizedBox(
                      width: 148,
                      child: Material(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => onSelect(item),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.storefront_outlined, color: RegionMapBloom.market),
                                const Spacer(),
                                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  '${OurAreaCategory.chipLabel(item.chipKey)} · ${_regionDistance(item)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partial
                          ? '아직 이 조건의 샵을 찾지 못했어요. 다시 조회해 주세요.'
                          : '이 반경 안에 이 업종으로 등록된 업소가 없습니다.',
                    ),
                    if (onWiden != null)
                      TextButton(
                        onPressed: onWiden,
                        child: Text('${RegionShopListCopy.radiusLabel(widerRadius!)}로 넓혀보기'),
                      )
                    else
                      TextButton(onPressed: onRetry, child: const Text('다시 시도')),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    _MarketStoreRow(
                      item: shown[i],
                      index: i,
                      region: '',
                      selected: sameShop(selected, shown[i]),
                      onSelect: () => onSelect(shown[i]),
                    ),
                  if (stores.length > visibleLimit)
                    TextButton(onPressed: onMore, child: const Text('샵 더 보기')),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              '출처\n$sourceText\n조회 시점\n$queryTimeText\n등록·갱신 시차로 실제 영업 현황과 다를 수 있어요.',
              style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary, height: 1.5),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
          ],
        ),
        ],
      ),
    );
  }
}
