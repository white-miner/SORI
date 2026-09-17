import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../models/shop.dart';

/// 주소 → 좌표 + 행정동(동네 이름·코드).
class ShopNeighborhood {
  const ShopNeighborhood({
    required this.latitude,
    required this.longitude,
    required this.dongName,
    required this.admCd,
    this.displayLabel = '',
  });

  final double latitude;
  final double longitude;
  /// 예: 성건동
  final String dongName;
  /// 행정동 코드 (보통 10자리)
  final String admCd;
  final String displayLabel;

  bool get isLinked => admCd.trim().isNotEmpty;
}

/// 매장 주소 → 좌표 (카카오 REST 우선, 실패 시 서울 시청 폴백).
class ShopGeocodingService {
  ShopGeocodingService._();
  static final ShopGeocodingService instance = ShopGeocodingService._();

  static const _seoulLat = 37.5665;
  static const _seoulLng = 126.9780;

  Future<({double lat, double lng})> geocodeAddress(String address) async {
    final n = await resolveNeighborhood(address);
    if (n != null) return (lat: n.latitude, lng: n.longitude);
    return (lat: _seoulLat, lng: _seoulLng);
  }

  /// 주소만으로 행정동 코드·동 이름을 찾는다. 키 없거나 실패 시 null.
  Future<ShopNeighborhood?> resolveNeighborhood(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final kakaoKey = dotenv.env['KAKAO_REST_API_KEY']?.trim() ?? '';
    if (kakaoKey.isEmpty) return null;

    try {
      final searchUri = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/address.json'
        '?query=${Uri.encodeComponent(trimmed)}',
      );
      final searchRes = await http
          .get(searchUri, headers: {'Authorization': 'KakaoAK $kakaoKey'})
          .timeout(const Duration(seconds: 5));
      if (searchRes.statusCode != 200) return null;

      final body = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final docs = body['documents'] as List<dynamic>? ?? [];
      if (docs.isEmpty) return null;

      final first = docs.first as Map<String, dynamic>;
      final lat = double.tryParse(first['y']?.toString() ?? '');
      final lng = double.tryParse(first['x']?.toString() ?? '');
      if (lat == null || lng == null) return null;

      // address.h_code 가 있으면 우선 사용
      final addr = first['address'];
      if (addr is Map) {
        final hCode = '${addr['h_code'] ?? ''}'.trim();
        final region3 = '${addr['region_3depth_name'] ?? ''}'.trim();
        if (hCode.isNotEmpty) {
          return ShopNeighborhood(
            latitude: lat,
            longitude: lng,
            dongName: region3,
            admCd: hCode,
            displayLabel: region3.isEmpty ? hCode : region3,
          );
        }
      }

      final region = await _coordToAdminDong(
        kakaoKey: kakaoKey,
        lat: lat,
        lng: lng,
      );
      if (region == null) {
        return ShopNeighborhood(
          latitude: lat,
          longitude: lng,
          dongName: '',
          admCd: '',
          displayLabel: '',
        );
      }
      return ShopNeighborhood(
        latitude: lat,
        longitude: lng,
        dongName: region.dongName,
        admCd: region.admCd,
        displayLabel: region.dongName,
      );
    } catch (e) {
      debugPrint('Kakao neighborhood resolve failed: $e');
      return null;
    }
  }

  Future<({String dongName, String admCd})?> _coordToAdminDong({
    required String kakaoKey,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json'
      '?x=$lng&y=$lat',
    );
    final res = await http
        .get(uri, headers: {'Authorization': 'KakaoAK $kakaoKey'})
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = body['documents'] as List<dynamic>? ?? [];
    Map<String, dynamic>? hDoc;
    for (final d in docs) {
      if (d is! Map) continue;
      final map = Map<String, dynamic>.from(d);
      if ('${map['region_type']}' == 'H') {
        hDoc = map;
        break;
      }
    }
    hDoc ??= docs.isNotEmpty && docs.first is Map
        ? Map<String, dynamic>.from(docs.first as Map)
        : null;
    if (hDoc == null) return null;
    final code = '${hDoc['code'] ?? ''}'.trim();
    final dong = '${hDoc['region_3depth_name'] ?? ''}'.trim();
    if (code.isEmpty) return null;
    return (dongName: dong, admCd: code);
  }

  Future<Shop> ensureShopCoordinates(Shop shop) async {
    if (shop.latitude != null &&
        shop.longitude != null &&
        shop.latitude!.abs() > 0.01) {
      return shop;
    }
    final addr = shop.address?.trim() ?? '';
    if (addr.isEmpty) return shop;
    final coords = await geocodeAddress(addr);
    return shop.copyWith(
      latitude: coords.lat,
      longitude: coords.lng,
    );
  }
}
