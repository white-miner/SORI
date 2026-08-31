import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/shop.dart';
import 'clinical_assistant_store.dart';
import 'models/shop_climate_context.dart';
import 'shop_geocoding_service.dart';

/// PRD v4.2 — KMA + PM2.5, 1시간 클라이언트 캐시.
class ShopClimateService {
  ShopClimateService._();
  static final ShopClimateService instance = ShopClimateService._();

  ShopClimateContext? _cache;
  DateTime? _cacheAt;
  String? _cacheShopId;

  static const _cacheTtl = Duration(hours: 1);

  /// 경주 기본 좌표 (PO v4.2 로컬 SSOT 폴백).
  static const gyeongjuLat = 35.8562;
  static const gyeongjuLng = 129.2247;

  Future<ShopClimateContext> fetchForShop(Shop shop) async {
    final sid = shop.id.trim();
    if (_cache != null &&
        _cacheShopId == sid &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      ClinicalAssistantStore.instance.setCurrent(_cache!);
      return _cache!;
    }

    var resolved = shop;
    if (shop.latitude == null || shop.longitude == null) {
      resolved = await ShopGeocodingService.instance.ensureShopCoordinates(shop);
    }

    final lat = resolved.latitude ?? gyeongjuLat;
    final lng = resolved.longitude ?? gyeongjuLng;
    final locationLabel = _locationLabel(resolved);

    ShopClimateContext? ctx;

    try {
      final client = Supabase.instance.client;
      final res = await client.functions
          .invoke(
            'get-shop-climate',
            body: {
              'shop_id': sid,
              'latitude': lat,
              'longitude': lng,
              'location_label': locationLabel,
            },
          )
          .timeout(const Duration(seconds: 6));
      ctx = _parseResponse(res.data, locationLabel);
    } catch (e) {
      debugPrint('get-shop-climate edge failed: $e');
    }

    ctx ??= await _fetchDirect(lat, lng, locationLabel);

    _cache = ctx;
    _cacheAt = DateTime.now();
    _cacheShopId = sid;
    ClinicalAssistantStore.instance.setCurrent(ctx);
    return ctx;
  }

  ShopClimateContext? _parseResponse(dynamic data, String locationLabel) {
    try {
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is String) {
        map = jsonDecode(data) as Map<String, dynamic>?;
      }
      if (map == null) return null;
      map['location_label'] ??= locationLabel;
      return ShopClimateContext.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  String _locationLabel(Shop shop) {
    final addr = shop.address?.trim() ?? '';
    if (addr.contains('경주')) return '경주';
    if (addr.isNotEmpty) {
      final parts = addr.split(' ');
      if (parts.length >= 2) return parts[1];
    }
    return shop.name.trim().isEmpty ? '매장' : shop.name.trim();
  }

  Future<ShopClimateContext> _fetchDirect(
    double lat,
    double lng,
    String locationLabel,
  ) async {
    final key = dotenv.env['KMA_SERVICE_KEY']?.trim() ??
        dotenv.env['DATA_GO_KR_SERVICE_KEY']?.trim() ??
        '';
    if (key.isEmpty) {
      return ShopClimateContext.fallback(locationLabel: locationLabel);
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

      final weatherUri = Uri.parse(
        'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst'
        '?serviceKey=${Uri.encodeComponent(key)}'
        '&pageNo=1&numOfRows=200&dataType=JSON'
        '&base_date=$dateStr&base_time=$baseTime'
        '&nx=${grid.nx}&ny=${grid.ny}',
      );

      final weatherRes = await http.get(weatherUri).timeout(const Duration(seconds: 5));
      if (weatherRes.statusCode != 200) {
        return ShopClimateContext.fallback(locationLabel: locationLabel);
      }

      final body = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final items = _extractKmaItems(body);

      double? tmp;
      int? reh;
      for (final item in items) {
        final cat = item['category']?.toString();
        final val = item['fcstValue']?.toString();
        if (cat == 'TMP' && tmp == null) tmp = double.tryParse(val ?? '');
        if (cat == 'REH' && reh == null) reh = int.tryParse(val ?? '');
      }

      final tempC = tmp ?? 22.0;
      final humidity = reh ?? 55;
      final uv = _estimateUv(tempC, humidity, hour);
      final pm25 = await _fetchPm25Direct(key, locationLabel);

      return ShopClimateContext.fromMap({
        'temp_c': tempC,
        'humidity_pct': humidity,
        'uv_index': uv,
        'pm25_ug_m3': pm25,
        'hot_days_last_7': tempC >= 30 ? 2 : 0,
        'location_label': locationLabel,
        'source': 'kma_direct',
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('climate direct fetch failed: $e');
      return ShopClimateContext.fallback(locationLabel: locationLabel);
    }
  }

  Future<int> _fetchPm25Direct(String key, String locationLabel) async {
    final station = locationLabel.contains('경주') ? '경주' : '경주';
    try {
      final uri = Uri.parse(
        'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRdmtrcMesureDnsty'
        '?serviceKey=${Uri.encodeComponent(key)}'
        '&returnType=json&numOfRows=1&pageNo=1'
        '&stationName=${Uri.encodeComponent(station)}'
        '&dataTerm=DAILY&ver=1.0',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return 25;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = body['response']?['body']?['items'];
      if (items is List && items.isNotEmpty) {
        final pm = items.first['pm25Value']?.toString() ?? '';
        final v = int.tryParse(pm.replaceAll(RegExp(r'[^0-9]'), ''));
        if (v != null && v >= 0) return v;
      }
    } catch (e) {
      debugPrint('PM2.5 fetch failed: $e');
    }
    return 25;
  }

  List<Map<String, dynamic>> _extractKmaItems(Map<String, dynamic> body) {
    try {
      final items = body['response']?['body']?['items']?['item'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
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
