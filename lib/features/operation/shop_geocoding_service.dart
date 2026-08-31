import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../models/shop.dart';

/// 매장 주소 → 좌표 (카카오 REST 우선, 실패 시 서울 시청 폴백).
class ShopGeocodingService {
  ShopGeocodingService._();
  static final ShopGeocodingService instance = ShopGeocodingService._();

  static const _seoulLat = 37.5665;
  static const _seoulLng = 126.9780;

  Future<({double lat, double lng})> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return (lat: _seoulLat, lng: _seoulLng);
    }

    final kakaoKey = dotenv.env['KAKAO_REST_API_KEY']?.trim() ?? '';
    if (kakaoKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://dapi.kakao.com/v2/local/search/address.json'
          '?query=${Uri.encodeComponent(trimmed)}',
        );
        final res = await http
            .get(uri, headers: {'Authorization': 'KakaoAK $kakaoKey'})
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final docs = body['documents'] as List<dynamic>? ?? [];
          if (docs.isNotEmpty) {
            final first = docs.first as Map<String, dynamic>;
            final lat = double.tryParse(first['y']?.toString() ?? '');
            final lng = double.tryParse(first['x']?.toString() ?? '');
            if (lat != null && lng != null) {
              return (lat: lat, lng: lng);
            }
          }
        }
      } catch (e) {
        debugPrint('Kakao geocode failed: $e');
      }
    }

    return (lat: _seoulLat, lng: _seoulLng);
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
