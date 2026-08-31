import '../../visit/consultation_track.dart';
import 'sos_signal.dart';
import 'skin_stress_index.dart';
import 'visit_biometrics.dart';

/// PRD v4.0 — 퀵 체크 후 딥 차트 진입 깊이 (IA 뎁스 분리).
enum ConsultationDeepMode {
  /// 신규 + SOS 낮음 — 전체 딥 차트 (4.0-C 이후).
  fullDesign,

  /// 신규 + SOS 높음 — Face Map 생략, Barrier 우선.
  shortenedSafety,

  /// 기존 — 유지 보수 트래킹.
  maintenance,

  /// 간편 기록 — 세션 우회.
  quickChartOnly;

  String get label => switch (this) {
        ConsultationDeepMode.fullDesign => '기초 공사 설계',
        ConsultationDeepMode.shortenedSafety => '안전 우선 상담',
        ConsultationDeepMode.maintenance => '유지 보수 트래킹',
        ConsultationDeepMode.quickChartOnly => '간편 기록',
      };
}

ConsultationDeepMode resolveDeepMode({
  required ConsultationTrack track,
  required SosSignal sos,
  VisitBiometrics? biometrics,
  SsiBand? ssiBand,
}) {
  if (track == ConsultationTrack.returning) {
    return ConsultationDeepMode.maintenance;
  }
  if (sos.grade.index >= SosGrade.s2.index) {
    return ConsultationDeepMode.shortenedSafety;
  }
  if (ssiBand != null && ssiBand.isElevated) {
    return ConsultationDeepMode.shortenedSafety;
  }
  if (biometrics != null &&
      biometrics.cycle == BiometricTouchState.active &&
      biometrics.alcohol == BiometricTouchState.active) {
    return ConsultationDeepMode.shortenedSafety;
  }
  return ConsultationDeepMode.fullDesign;
}
