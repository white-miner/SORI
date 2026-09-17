import 'dart:math' as math;

/// 하버사인 거리 (미터).
double haversineMeters({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const r = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

bool isWithinRadiusKm({
  required double centerLat,
  required double centerLng,
  required double pointLat,
  required double pointLng,
  required double radiusKm,
}) {
  if (radiusKm <= 0) return false;
  final m = haversineMeters(
    lat1: centerLat,
    lng1: centerLng,
    lat2: pointLat,
    lng2: pointLng,
  );
  return m <= radiusKm * 1000;
}
