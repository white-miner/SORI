/// PRD v4.2 — Skin Stress Index (SSI) band + score.
enum SsiBand {
  low,
  moderate,
  high,
  critical;

  String get label => switch (this) {
        SsiBand.low => '양호',
        SsiBand.moderate => '보통',
        SsiBand.high => '주의',
        SsiBand.critical => '위험',
      };

  bool get isElevated => index >= SsiBand.high.index;
}

class SkinStressIndex {
  const SkinStressIndex({
    required this.score,
    required this.band,
    required this.tempStress,
    required this.humidStress,
    required this.uvStress,
    required this.pm25Stress,
  });

  final int score;
  final SsiBand band;
  final double tempStress;
  final double humidStress;
  final double uvStress;
  final double pm25Stress;

  /// PO v4.2 — 4지표 가중 SSI (0–100).
  static SkinStressIndex compute({
    required double tempC,
    required int humidityPct,
    required int uvIndex,
    required int pm25UgM3,
  }) {
    final tempStress = _clamp((tempC - 26) * 8, 0, 100);
    final humidStress = humidityPct < 45
        ? _clamp((45 - humidityPct) * 2.0, 0, 100)
        : _clamp((humidityPct - 75) * 2.0, 0, 40);
    final uvStress = _clamp((uvIndex - 3) * 12.0, 0, 100);
    final pm25Stress = _clamp((pm25UgM3 - 15) * 3.0, 0, 100);

    final raw = 0.30 * tempStress +
        0.15 * humidStress +
        0.30 * uvStress +
        0.25 * pm25Stress;
    final score = raw.round().clamp(0, 100);
    final band = _bandForScore(score);

    return SkinStressIndex(
      score: score,
      band: band,
      tempStress: tempStress,
      humidStress: humidStress,
      uvStress: uvStress,
      pm25Stress: pm25Stress,
    );
  }

  static SsiBand _bandForScore(int score) {
    if (score >= 80) return SsiBand.critical;
    if (score >= 60) return SsiBand.high;
    if (score >= 30) return SsiBand.moderate;
    return SsiBand.low;
  }

  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
