import 'customer_chart.dart';
import 'seminar_class.dart';
import 'shop.dart';

/// 세미나 클래스 랜딩 페이지용 — 클래스 + 강사 샵 + 근원 B/A 차트.
class SeminarClassDetail {
  const SeminarClassDetail({
    required this.seminarClass,
    required this.directorShop,
    this.targetChart,
  });

  final SeminarClass seminarClass;
  final Shop directorShop;
  final CustomerChart? targetChart;

  int get remainingSeats =>
      (seminarClass.maxCapacity - seminarClass.currentEnrollment).clamp(0, 9999);

  double get enrollmentRatio => seminarClass.maxCapacity <= 0
      ? 0
      : (seminarClass.currentEnrollment / seminarClass.maxCapacity).clamp(0.0, 1.0);

  bool get isAlmostFull =>
      remainingSeats <= 3 || enrollmentRatio >= 0.75;

  /// B/A 헤더 슬라이더용 이미지 URL (Before → After 순).
  List<String> get heroImageUrls {
    final chart = targetChart;
    if (chart == null) return const [];
    final urls = <String>[];
    final before = chart.beforeImageUrl?.trim() ?? '';
    final after = chart.afterImageUrl?.trim() ?? '';
    if (before.startsWith('http')) urls.add(before);
    if (after.startsWith('http')) urls.add(after);
    return urls;
  }

  /// Extra promo images for seminar landing hero/gallery.
  List<String> get promoImageUrls {
    final extra = <String>[
      for (final raw in seminarClass.additionalImages)
        if (raw.trim().startsWith('http')) raw.trim(),
    ];
    if (extra.isNotEmpty) return extra;
    return heroImageUrls;
  }

  /// Auto-Syllabus — care_tags + care_name.
  List<String> get syllabusTags {
    final tags = <String>[];
    final careName = targetChart?.careName.trim() ?? '';
    if (careName.isNotEmpty) tags.add(careName);
    for (final raw in targetChart?.careTags ?? const <String>[]) {
      final t = raw.trim().replaceAll('#', '');
      if (t.isEmpty) continue;
      if (tags.any((e) => e.toLowerCase() == t.toLowerCase())) continue;
      tags.add(t);
    }
    return tags;
  }

  /// 강사 작성 설명 → 차트 인사이트 → 샵 bio 순 fallback.
  String get displayDescription {
    final direct = seminarClass.description.trim();
    if (direct.isNotEmpty) return direct;
    final insight = targetChart?.directorInsight.trim() ?? '';
    if (insight.isNotEmpty) return insight;
    final summary = targetChart?.treatmentSummary.trim() ?? '';
    if (summary.isNotEmpty) return summary;
    final bio = directorShop.bio.trim();
    if (bio.isNotEmpty) return bio;
    return '이번 세미나에서는 실제 관리 케이스 B/A를 바탕으로 핵심 테크닉과 시술 포인트를 라이브로 공유합니다.';
  }
}
