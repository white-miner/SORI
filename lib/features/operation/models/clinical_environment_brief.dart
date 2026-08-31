/// PRD v4.2 — 오늘의 임상 디테일 (서술형 개조식).
class ClinicalEnvironmentBrief {
  const ClinicalEnvironmentBrief({
    required this.headline,
    required this.narrative,
    required this.calmTargetC,
    this.deviceIntensityCap = 4,
    this.alerts = const [],
  });

  final String headline;
  final String narrative;
  final double calmTargetC;

  /// Plan Phase 타격 심도 상한 (silent bind).
  final int deviceIntensityCap;
  final List<ClinicalAlert> alerts;

  static const standard = ClinicalEnvironmentBrief(
    headline: '표준 프로토콜',
    narrative: '오늘 환경은 표준 프로토콜에 적합합니다. 상담 전 고객 체감 온도만 확인하세요.',
    calmTargetC: 22.0,
  );

  bool get shouldSurface => alerts.isNotEmpty;
}

class ClinicalAlert {
  const ClinicalAlert({
    required this.key,
    required this.headline,
    required this.narrative,
    required this.priority,
  });

  final String key;
  final String headline;
  final String narrative;
  final int priority;
}
