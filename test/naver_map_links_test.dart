import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/utils/naver_map_links.dart';

void main() {
  test('existing map URL wins over coords and search', () {
    final uri = NaverMapLinks.uri(
      name: '숨은샵',
      address: '서울 강남구',
      latitude: 37.5,
      longitude: 127.0,
      existingMapUrl: 'https://m.place.naver.com/place/demo',
      region: '경주',
    );
    expect(uri?.toString(), 'https://m.place.naver.com/place/demo');
  });

  test('coords build a Naver Map pin when no place URL', () {
    final uri = NaverMapLinks.uri(
      name: '바디잉크',
      address: '서울 강남구 역삼동',
      latitude: 37.501,
      longitude: 127.039,
    );
    expect(uri, isNotNull);
    expect(uri!.host, 'map.naver.com');
    expect(uri.path, '/index.nhn');
    expect(uri.queryParameters['lat'], '37.501');
    expect(uri.queryParameters['lng'], '127.039');
    expect(uri.queryParameters['query'], '바디잉크');
  });

  test('zero coords fall back to address then name+region', () {
    final byAddress = NaverMapLinks.uri(
      name: '헤어샵',
      address: '서울 마포구 연남동 1',
      latitude: 0,
      longitude: 0,
    );
    expect(byAddress.toString(), contains(Uri.encodeComponent('헤어샵 서울 마포구 연남동 1')));

    final byRegion = NaverMapLinks.uri(
      name: '헤어샵',
      latitude: 0,
      longitude: 0,
      region: '경주시',
    );
    expect(byRegion.toString(), contains(Uri.encodeComponent('헤어샵 경주시')));
  });

  test('hides when no name, address, region, url, or coords', () {
    expect(NaverMapLinks.uri(), isNull);
    expect(
      NaverMapLinks.uri(name: '  ', address: '', region: '', existingMapUrl: ''),
      isNull,
    );
    expect(NaverMapLinks.hasValidCoords(0, 0), isFalse);
    expect(NaverMapLinks.hasValidCoords(null, 127), isFalse);
  });

  test('region map canvas gestures stay untouched; CTA is list/card only', () {
    final map = File(
      'lib/views/community/region_nearby_map_section.dart',
    ).readAsStringSync();
    expect(map.contains('interactionOptions: const InteractionOptions('), isTrue);
    expect(map.contains("child: const Text('지도에서 보기')"), isTrue);
    expect(map.contains('NaverMapLinks.uri'), isTrue);
    expect(map.contains('RegionMapExploreSheet('), isTrue);

    final sheet = File(
      'lib/views/community/region_map_explore_sheet.dart',
    ).readAsStringSync();
    expect(sheet.contains('지도에서 보기'), isFalse);
    expect(sheet.contains('NaverMapLinks'), isFalse);
  });
}
