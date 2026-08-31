import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/shop.dart';
import 'models/shop_weather_context.dart';
import 'shop_geocoding_service.dart';

/// PRD v4.0 — 기상청 단기예보 우선, 30분 클라이언트 캐시.
class ShopWeatherService {
  ShopWeatherService._();
  static final ShopWeatherService instance = ShopWeatherService._();

  ShopWeatherContext? _cache;
  DateTime? _cacheAt;
  String? _cacheShopId;

  static const _cacheTtl = Duration(minutes: 30);

  Future<ShopWeatherContext> fetchForShop(Shop shop) async {
    final sid = shop.id.trim();
    if (_cache != null &&
        _cacheShopId == sid &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }

    var resolved = shop;
    if (shop.latitude == null || shop.longitude == null) {
      resolved = await ShopGeocodingService.instance.ensureShopCoordinates(shop);
    }

    ShopWeatherContext? ctx;

    try {
      final client = Supabase.instance.client;
      final res = await client.functions
          .invoke(
            'get-shop-weather',
            body: {
              'shop_id': sid,
              'latitude': resolved.latitude,
              'longitude': resolved.longitude,
            },
          )
          .timeout(const Duration(seconds: 5));
      final data = res.data;
      if (data is Map<String, dynamic>) {
        ctx = ShopWeatherContext.fromMap(data);
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          ctx = ShopWeatherContext.fromMap(decoded);
        }
      }
    } catch (e) {
      debugPrint('get-shop-weather edge failed, trying direct KMA: $e');
    }

    ctx ??= await _fetchKmaDirect(
      resolved.latitude ?? 37.5665,
      resolved.longitude ?? 126.9780,
    );

    _cache = ctx;
    _cacheAt = DateTime.now();
    _cacheShopId = sid;
    return ctx;
  }

  Future<ShopWeatherContext> _fetchKmaDirect(double lat, double lng) async {
    final key = dotenv.env['KMA_SERVICE_KEY']?.trim() ??
        dotenv.env['DATA_GO_KR_SERVICE_KEY']?.trim() ??
        '';
    if (key.isEmpty) {
      return ShopWeatherContext.fallback();
    }

    try {
      final grid = _latLngToGrid(lat, lng);
      final now = DateTime.now();
      var baseDate = DateTime(now.year, now.month, now.day);
      var baseTime = '0500';
      final hour = now.hour;
      if (hour < 2) {
        baseDate = baseDate.subtract(const Duration(days: 1));
        baseTime = '2300';
      } else if (hour < 5) {
        baseTime = '0200';
      } else if (hour < 8) {
        baseTime = '0500';
      } else if (hour < 11) {
        baseTime = '0800';
      } else if (hour < 14) {
        baseTime = '1100';
      } else if (hour < 17) {
        baseTime = '1400';
      } else if (hour < 20) {
        baseTime = '1700';
      } else if (hour < 23) {
        baseTime = '2000';
      } else {
        baseTime = '2300';
      }

      final dateStr =
          '${baseDate.year}${baseDate.month.toString().padLeft(2, '0')}${baseDate.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse(
        'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst'
        '?serviceKey=${Uri.encodeComponent(key)}'
        '&pageNo=1&numOfRows=200&dataType=JSON'
        '&base_date=$dateStr&base_time=$baseTime'
        '&nx=${grid.nx}&ny=${grid.ny}',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return ShopWeatherContext.fallback();

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = _extractKmaItems(body);
      if (items.isEmpty) return ShopWeatherContext.fallback();

      double? tmp;
      int? reh;
      for (final item in items) {
        final cat = item['category']?.toString();
        final val = item['fcstValue']?.toString();
        if (cat == 'TMP' && tmp == null) {
          tmp = double.tryParse(val ?? '');
        }
        if (cat == 'REH' && reh == null) {
          reh = int.tryParse(val ?? '');
        }
      }

      final tempC = tmp ?? 22.0;
      final humidity = reh ?? 55;
      final uv = _estimateUv(tempC, humidity, hour);

      return ShopWeatherContext.compute(
        tempC: tempC,
        humidityPct: humidity,
        uvIndex: uv,
        fetchedAt: DateTime.now(),
        source: 'kma_direct',
      );
    } catch (e) {
      debugPrint('KMA direct fetch failed: $e');
      return ShopWeatherContext.fallback();
    }
  }

  List<Map<String, dynamic>> _extractKmaItems(Map<String, dynamic> body) {
    try {
      final response = body['response'] as Map<String, dynamic>?;
      final bodyMap = response?['body'] as Map<String, dynamic>?;
      final items = bodyMap?['items'];
      if (items is Map<String, dynamic>) {
        final list = items['item'];
        if (list is List) {
          return list.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    return [];
  }

  int _estimateUv(double tempC, int humidity, int hour) {
    if (hour < 7 || hour > 18) return 1;
    var uv = ((tempC - 10) / 3).round().clamp(1, 10);
    if (humidity > 80) uv = math.max(1, uv - 1);
    return uv;
  }

  ({int nx, int ny}) _latLngToGrid(double lat, double lng) {
    const re = 6371.00877;
    const grid = 5.0;
    const slat1 = 30.0;
    const slat2 = 60.0;
    const olon = 126.0;
    const olat = 38.0;
    const xo = 43.0;
    const yo = 136.0;

    final dLat = _degToRad(slat2 - slat1);
    final ra = math.tan(math.pi * 0.25 + _degToRad(slat1) * 0.5);
    final rb = math.tan(math.pi * 0.25 + _degToRad(slat2) * 0.5);
    final sn = math.log(ra / rb) / math.log(dLat);
    final sf = math.pow(ra, sn) * math.cos(_degToRad(slat1)) / sn;
    final ro = re * sf / math.pow(math.tan(math.pi * 0.25 + _degToRad(olat) * 0.5), sn);

    var ra2 = re * sf / math.pow(math.tan(math.pi * 0.25 + _degToRad(lat) * 0.5), sn);
    var theta = lng * math.pi / 180 - olon * math.pi / 180;
    if (theta > math.pi) theta -= 2 * math.pi;
    if (theta < -math.pi) theta += 2 * math.pi;
    theta *= sn;

    final x = (ra2 * math.sin(theta) + xo).round();
    final y = (ro - ra2 * math.cos(theta) + yo).round();
    return (nx: x, ny: y);
  }

  double _degToRad(double deg) => deg * math.pi / 180;
}
