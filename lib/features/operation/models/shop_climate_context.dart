import '../clinical_brief_engine.dart';
import 'clinical_environment_brief.dart';
import 'skin_stress_index.dart';
/// PRD v4.2 — 매장 미세 기후 + SSI + 임상 브리핑 SSOT.
class ShopClimateContext {
  const ShopClimateContext({
    required this.tempC,
    required this.humidityPct,
    required this.uvIndex,
    required this.pm25UgM3,
    required this.ssi,
    required this.brief,
    this.fetchedAt,
    this.source = 'kma',
    this.locationLabel = '매장',
  });

  final double tempC;
  final int humidityPct;
  final int uvIndex;
  final int pm25UgM3;
  final SkinStressIndex ssi;
  final ClinicalEnvironmentBrief brief;
  final DateTime? fetchedAt;
  final String source;
  final String locationLabel;

  factory ShopClimateContext.fromMap(Map<String, dynamic> map) {
    final tempC = (map['temp_c'] as num?)?.toDouble() ?? 22;
    final humidity = (map['humidity_pct'] as num?)?.toInt() ?? 55;
    final uv = (map['uv_index'] as num?)?.toInt() ?? 3;
    final pm25 = (map['pm25_ug_m3'] as num?)?.toInt() ?? 20;
    final hotDays = (map['hot_days_last_7'] as num?)?.toInt() ?? 0;

    final ssi = SkinStressIndex.compute(
      tempC: tempC,
      humidityPct: humidity,
      uvIndex: uv,
      pm25UgM3: pm25,
    );
    final brief = ClinicalBriefEngine.build(
      tempC: tempC,
      humidityPct: humidity,
      uvIndex: uv,
      pm25UgM3: pm25,
      ssi: ssi,
      hotDaysLast7: hotDays,
    );

    final fetchedRaw = map['fetched_at']?.toString() ?? '';
    return ShopClimateContext(
      tempC: tempC,
      humidityPct: humidity,
      uvIndex: uv,
      pm25UgM3: pm25,
      ssi: ssi,
      brief: brief,
      fetchedAt: DateTime.tryParse(fetchedRaw)?.toLocal(),
      source: map['source']?.toString() ?? 'kma',
      locationLabel: map['location_label']?.toString() ?? '매장',
    );
  }

  Map<String, dynamic> toMap() => {
        'temp_c': tempC,
        'humidity_pct': humidityPct,
        'uv_index': uvIndex,
        'pm25_ug_m3': pm25UgM3,
        'ssi': ssi.score,
        'ssi_band': ssi.band.name,
        'calm_target_c': brief.calmTargetC,
        'headline': brief.headline,
        'narrative': brief.narrative,
        'fetched_at': fetchedAt?.toUtc().toIso8601String(),
        'source': source,
        'location_label': locationLabel,
      };

  static ShopClimateContext fallback({String locationLabel = '경주'}) {
    return ShopClimateContext.fromMap({
      'temp_c': 28,
      'humidity_pct': 42,
      'uv_index': 7,
      'pm25_ug_m3': 38,
      'hot_days_last_7': 2,
      'location_label': locationLabel,
      'source': 'fallback',
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// PRD v5.4 — toolbox weather label (Korean, no truncated headline).
  String get weatherLabelKo {
    final h = brief.headline.trim();
    if (h.isEmpty ||
        h == '표준 프로토콜' ||
        h == '피부 스트레스 양호') {
      return '조금 흐림';
    }
    return h;
  }
}
