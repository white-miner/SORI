import 'package:url_launcher/url_launcher.dart';

/// 네이버 지도 웹 URL. 새 SDK 없이 기존 식별값만 조합한다.
abstract final class NaverMapLinks {
  static bool hasValidCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.abs() < 0.01 && lng.abs() < 0.01) return false;
    return lat.abs() <= 90 && lng.abs() <= 180;
  }

  /// 우선순위: 기존 지도/플레이스 URL → 좌표 → 주소 → 업체명+지역 검색.
  static Uri? uri({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? existingMapUrl,
    String? region,
  }) {
    final existing = existingMapUrl?.trim() ?? '';
    if (existing.isNotEmpty) {
      final parsed = Uri.tryParse(existing);
      if (parsed != null &&
          (parsed.isScheme('http') || parsed.isScheme('https'))) {
        return parsed;
      }
    }

    final label = (name ?? '').trim();
    if (hasValidCoords(latitude, longitude)) {
      return Uri.https('map.naver.com', '/index.nhn', {
        'lat': '$latitude',
        'lng': '$longitude',
        'dlevel': '16',
        if (label.isNotEmpty) 'query': label,
      });
    }

    final addr = (address ?? '').trim();
    if (addr.isNotEmpty) {
      final query = label.isEmpty ? addr : '$label $addr';
      return Uri.parse(
        'https://map.naver.com/p/search/${Uri.encodeComponent(query)}',
      );
    }

    final area = (region ?? '').trim();
    if (label.isEmpty && area.isEmpty) return null;
    final query = [label, area].where((e) => e.isNotEmpty).join(' ');
    return Uri.parse(
      'https://map.naver.com/p/search/${Uri.encodeComponent(query)}',
    );
  }

  static Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
