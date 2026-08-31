/// PRD v4.0 — 매장 환경 역학 (기상청 단기예보 기반).
class ShopWeatherContext {
  const ShopWeatherContext({
    required this.tempC,
    required this.humidityPct,
    required this.uvIndex,
    required this.calmTargetC,
    required this.headline,
    required this.narrative,
    this.fetchedAt,
    this.source = 'kma',
  });

  final double tempC;
  final int humidityPct;
  final int uvIndex;
  final double calmTargetC;
  final String headline;
  final String narrative;
  final DateTime? fetchedAt;
  final String source;

  factory ShopWeatherContext.fromMap(Map<String, dynamic> map) {
    final fetchedRaw = map['fetched_at']?.toString() ?? '';
    return ShopWeatherContext(
      tempC: (map['temp_c'] as num?)?.toDouble() ??
          (map['tempC'] as num?)?.toDouble() ??
          22,
      humidityPct: (map['humidity_pct'] as num?)?.toInt() ??
          (map['humidityPct'] as num?)?.toInt() ??
          55,
      uvIndex: (map['uv_index'] as num?)?.toInt() ??
          (map['uvIndex'] as num?)?.toInt() ??
          3,
      calmTargetC: (map['calm_target_c'] as num?)?.toDouble() ??
          (map['calmTargetC'] as num?)?.toDouble() ??
          22,
      headline: map['headline']?.toString() ?? '',
      narrative: map['narrative']?.toString() ?? '',
      fetchedAt: DateTime.tryParse(fetchedRaw)?.toLocal(),
      source: map['source']?.toString() ?? 'kma',
    );
  }

  Map<String, dynamic> toMap() => {
        'temp_c': tempC,
        'humidity_pct': humidityPct,
        'uv_index': uvIndex,
        'calm_target_c': calmTargetC,
        'headline': headline,
        'narrative': narrative,
        'fetched_at': fetchedAt?.toUtc().toIso8601String(),
        'source': source,
      };

  /// PO 확정 초기 진정 온도 공식 + 서술형 개조식 변환.
  static ShopWeatherContext compute({
    required double tempC,
    required int humidityPct,
    required int uvIndex,
    DateTime? fetchedAt,
    String source = 'kma',
  }) {
    var calm = 22.0;
    if (humidityPct < 45) calm += 0.5;
    if (uvIndex >= 6) calm += 0.3;
    if (tempC > 28) calm -= (tempC - 28) * 0.1;
    calm = calm.clamp(20.0, 24.0);

    final calmStr = calm.toStringAsFixed(1);
    String headline = '초기 진정 온도 ${calmStr}°C';
    String narrative;

    if (humidityPct < 45 && uvIndex >= 6) {
      narrative =
          '외기가 건조하고 자외선이 강합니다. 시술 전 냉각 패드 3분으로 표피 열감을 먼저 낮추세요.';
    } else if (humidityPct < 45) {
      narrative =
          '습도 ${humidityPct}%로 피부 수분 증발이 빠릅니다. 시술 전 냉각 패드 3분을 권장합니다.';
    } else if (uvIndex >= 6) {
      narrative =
          '자외선 지수 $uvIndex로 혈관 확장 리스크가 있습니다. SPF 재도포 후 상담을 시작하세요.';
    } else if (tempC > 28) {
      narrative =
          '외기 ${tempC.toStringAsFixed(0)}°C로 열감이 빨리 올라갑니다. 냉각·보습으로 장벽을 먼저 안정시키세요.';
    } else {
      narrative =
          '오늘 환경은 표준 프로토콜에 적합합니다. 상담 전 고객 체감 온도만 확인하세요.';
    }

    return ShopWeatherContext(
      tempC: tempC,
      humidityPct: humidityPct,
      uvIndex: uvIndex,
      calmTargetC: calm,
      headline: headline,
      narrative: narrative,
      fetchedAt: fetchedAt ?? DateTime.now(),
      source: source,
    );
  }

  static ShopWeatherContext fallback() => compute(
        tempC: 24,
        humidityPct: 55,
        uvIndex: 4,
        source: 'fallback',
      );
}
