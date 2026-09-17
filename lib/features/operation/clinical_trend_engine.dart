import 'models/clinical_trend_snapshot.dart';

/// PRD v4.3 — Naver-only CTI (Google slot reserved for module plug-in).
class ClinicalTrendEngine {
  ClinicalTrendEngine._();

  static bool qualifiesForTop({required int cti, required int surgePct}) =>
      surgePct >= 5 || cti >= 40;

  static ClinicalTrendSnapshot buildFallbackSnapshot() =>
      ClinicalTrendSnapshot.fallback();

  static List<ClinicalTrendItem> rankTop3(List<ClinicalTrendItem> items) {
    final sorted = [...items]..sort((a, b) {
        if (b.cti != a.cti) return b.cti.compareTo(a.cti);
        if (b.surgePct != a.surgePct) return b.surgePct.compareTo(a.surgePct);
        return b.poPriority.compareTo(a.poPriority);
      });
    return sorted
        .where(
          (i) => qualifiesForTop(cti: i.cti, surgePct: i.surgePct),
        )
        .take(3)
        .toList();
  }
}
