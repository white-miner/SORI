import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/community_post.dart';
import '../../services/sori_store.dart';
import '../../utils/geo_distance.dart';

/// Phase C.3 — 글/세미나 맵 핀. 좌표는 shop_id / director_shop_id 프록시(Expand, 무파괴).
enum RegionMapPinKind { post, seminar }

class RegionMapPin {
  const RegionMapPin({
    required this.kind,
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.shopId,
  });

  final RegionMapPinKind kind;
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String? shopId;
}

abstract final class RegionMapContentPins {
  RegionMapContentPins._();

  static Future<List<RegionMapPin>> loadNear({
    required SoriStore store,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) async {
    final shopIds = <String>{};
    for (final p in store.communityPosts) {
      final sid = p.shopId.trim();
      if (sid.isNotEmpty) shopIds.add(sid);
    }
    for (final s in store.openSeminarClassesForFeed) {
      final sid = s.directorShopId.trim();
      if (sid.isNotEmpty) shopIds.add(sid);
    }
    if (shopIds.isEmpty) return const [];

    final coords = await _shopCoords(shopIds.toList());
    if (coords.isEmpty) return const [];

    final out = <RegionMapPin>[];
    for (final p in store.communityPosts) {
      final c = coords[p.shopId.trim()];
      if (c == null) continue;
      if (!isWithinRadiusKm(
        centerLat: centerLat,
        centerLng: centerLng,
        pointLat: c.$1,
        pointLng: c.$2,
        radiusKm: radiusKm,
      )) {
        continue;
      }
      out.add(
        RegionMapPin(
          kind: RegionMapPinKind.post,
          id: p.id,
          title: _postTitle(p),
          latitude: c.$1,
          longitude: c.$2,
          shopId: p.shopId,
        ),
      );
    }
    for (final s in store.openSeminarClassesForFeed) {
      final c = coords[s.directorShopId.trim()];
      if (c == null) continue;
      if (!isWithinRadiusKm(
        centerLat: centerLat,
        centerLng: centerLng,
        pointLat: c.$1,
        pointLng: c.$2,
        radiusKm: radiusKm,
      )) {
        continue;
      }
      out.add(
        RegionMapPin(
          kind: RegionMapPinKind.seminar,
          id: s.id,
          title: s.title.trim().isEmpty ? '세미나' : s.title.trim(),
          latitude: c.$1,
          longitude: c.$2,
          shopId: s.directorShopId,
        ),
      );
    }
    return out;
  }

  static String _postTitle(CommunityPost p) {
    final t = p.title.trim();
    if (t.isNotEmpty) return t;
    final body = p.body.trim();
    if (body.isEmpty) return '커뮤니티 글';
    return body.length > 36 ? '${body.substring(0, 36)}…' : body;
  }

  static Future<Map<String, (double, double)>> _shopCoords(
    List<String> shopIds,
  ) async {
    final out = <String, (double, double)>{};
    try {
      final client = Supabase.instance.client;
      // Batch in chunks of 80.
      for (var i = 0; i < shopIds.length; i += 80) {
        final chunk = shopIds.sublist(
          i,
          i + 80 > shopIds.length ? shopIds.length : i + 80,
        );
        final rows = await client
            .from('shops')
            .select('id,latitude,longitude')
            .inFilter('id', chunk);
        for (final raw in rows) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = map['id']?.toString().trim() ?? '';
          final lat = (map['latitude'] as num?)?.toDouble();
          final lng = (map['longitude'] as num?)?.toDouble();
          if (id.isEmpty || lat == null || lng == null) continue;
          if (lat.abs() < 0.01 && lng.abs() < 0.01) continue;
          out[id] = (lat, lng);
        }
      }
    } catch (e) {
      debugPrint('RegionMapContentPins._shopCoords: $e');
    }
    return out;
  }
}
