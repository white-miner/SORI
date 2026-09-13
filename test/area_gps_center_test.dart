import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/our_area_shop_snapshot.dart';
import 'package:sori/utils/area_search_center.dart';
import 'package:sori/utils/our_area_category.dart';
import 'package:sori/utils/our_area_radius_insight.dart';
import 'package:sori/utils/region_shop_list_copy.dart';

void main() {
  Map<String, dynamic> snapshotJson() {
    return jsonDecode(
      File(OurAreaShopSnapshot.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
  }

  test('GPS success uses one coordinate for filter, count, and insight', () {
    final items = OurAreaShopSnapshot.parse(
      snapshotJson(),
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
    );
    final here = AreaSearchCenter.currentLocation(
      lat: AreaSearchCenter.defaultLat,
      lng: AreaSearchCenter.defaultLng,
    );
    expect(here.source, AreaSearchSource.gps);

    final filtered = AreaSearchCenter.filter(
      items,
      center: here,
      radiusKm: 1,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
      withDistance: (s, m) => s.copyWith(distanceM: m),
    );
    final insight = OurAreaRadiusInsight.fromMappedKeys(
      filtered.items.map((s) => s.chipKey),
    );
    expect(filtered.inRadiusCount, insight.total);
    expect(
      RegionShopListCopy.searchBasis(here.source),
      '현재 위치 기준',
    );
    expect(
      RegionShopListCopy.countLine(filtered.inRadiusCount),
      '${insight.total}곳 발견',
    );
  });

  test('permission denied keeps fallback center and retry CTA', () {
    final fallback = AreaSearchCenter.resolve(
      gpsLat: null,
      gpsLng: null,
      mapLat: AreaSearchCenter.defaultLat,
      mapLng: AreaSearchCenter.defaultLng,
    );
    expect(fallback.source, isNot(AreaSearchSource.gps));
    expect(fallback.lat, AreaSearchCenter.defaultLat);
    expect(fallback.lng, AreaSearchCenter.defaultLng);
    expect(
      RegionShopListCopy.emptyKind(
        permissionDeniedOrFailed: true,
        usingCurrentLocation: false,
        snapshotCoversCenter: OurAreaShopSnapshot.covers(
          fallback.lat,
          fallback.lng,
        ),
      ),
      AreaShopEmptyKind.locationFailed,
    );
    expect(RegionShopListCopy.retryGpsLabel, '내 위치로 찾기');
    expect(
      RegionShopListCopy.locationUnavailableBanner(fallback.source),
      contains(RegionShopListCopy.searchBasis(fallback.source)),
    );
  });

  test('GPS success with zero snapshot is not a location failure', () {
    final items = OurAreaShopSnapshot.parse(
      snapshotJson(),
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
    );
    const seoulLat = 37.5665;
    const seoulLng = 126.9780;
    final here = AreaSearchCenter.currentLocation(
      lat: seoulLat,
      lng: seoulLng,
    );
    expect(OurAreaShopSnapshot.covers(here.lat, here.lng), isFalse);
    expect(
      OurAreaShopSnapshot.covers(
        OurAreaShopSnapshot.seonggeon.lat,
        OurAreaShopSnapshot.seonggeon.lng,
      ),
      isTrue,
    );

    final filtered = AreaSearchCenter.filter(
      items,
      center: here,
      radiusKm: 1,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    );
    expect(filtered.inRadiusCount, 0);
    expect(
      RegionShopListCopy.emptyKind(
        permissionDeniedOrFailed: false,
        usingCurrentLocation: true,
        snapshotCoversCenter: false,
      ),
      AreaShopEmptyKind.snapshotUnready,
    );
    expect(
      RegionShopListCopy.emptySnapshotUnreadyTitle,
      '현재 위치 주변 데이터 준비 중',
    );
    expect(
      RegionShopListCopy.showGyeongjuExampleLabel,
      '경주 예시 지역 보기',
    );
    expect(
      RegionShopListCopy.emptyKind(
        permissionDeniedOrFailed: false,
        usingCurrentLocation: true,
        snapshotCoversCenter: true,
      ),
      AreaShopEmptyKind.trueZero,
    );
    expect(
      RegionShopListCopy.emptyTrueZeroTitle,
      '이 반경에 등록된 업소가 없어요',
    );
  });

  test('1/3/5/10km and hair/nail filters still follow the GPS center', () {
    final items = OurAreaShopSnapshot.parse(
      snapshotJson(),
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
    );
    final here = AreaSearchCenter.currentLocation(
      lat: AreaSearchCenter.defaultLat,
      lng: AreaSearchCenter.defaultLng,
    );
    int countAt(double km, {String selected = OurAreaCategory.all}) {
      final kept = AreaSearchCenter.filter(
        items,
        center: here,
        radiusKm: km,
        latOf: (s) => s.latitude,
        lngOf: (s) => s.longitude,
      ).items.where(
            (s) => OurAreaCategory.matches(
              selected: selected,
              chipKey: s.chipKey,
              categoryLabel: s.categoryLabel,
            ),
          );
      return kept.length;
    }

    expect(countAt(1), greaterThanOrEqualTo(1));
    expect(countAt(3), greaterThanOrEqualTo(countAt(1)));
    expect(countAt(5), greaterThanOrEqualTo(countAt(3)));
    expect(countAt(10), greaterThanOrEqualTo(countAt(5)));
    expect(countAt(3, selected: 'hair'), greaterThanOrEqualTo(1));
    expect(countAt(3, selected: 'nail'), greaterThanOrEqualTo(1));
    expect(
      countAt(3, selected: 'hair') + countAt(3, selected: 'nail'),
      lessThanOrEqualTo(countAt(3)),
    );
  });
}
