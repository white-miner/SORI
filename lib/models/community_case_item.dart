import 'customer_chart.dart';
import 'customer_review.dart';
import 'shop.dart';
import '../utils/case_persona.dart';

/// 전국/단골 B/A 커뮤니티 피드 항목.
class CommunityCaseItem {
  const CommunityCaseItem({
    required this.chart,
    required this.shop,
    this.review,
    this.careTags = const [],
    this.customerAge,
    this.customerGenderLabel,
  });

  final CustomerChart chart;
  final Shop shop;
  final CustomerReview? review;

  /// 피드 해시태그 (care_tags / concern_chips).
  final List<String> careTags;

  /// 공개 피드용 익명 나이 (생년월일 미노출).
  final int? customerAge;

  /// 공개 피드용 성별 라벨 (`여성` / `남성`).
  final String? customerGenderLabel;

  bool get hasVerifiedReview =>
      review != null && review!.displayText.trim().isNotEmpty;

  List<String> get displayCareTags {
    if (careTags.isNotEmpty) return careTags;
    return chart.careTags;
  }

  /// 본문 요약 — 차트 join 필드 기준.
  String get personaLine => chart.metadataSummaryLine.isNotEmpty
      ? chart.metadataSummaryLine
      : CasePersona.line(
          chart: chart,
          age: customerAge ?? chart.age,
          genderLabel: customerGenderLabel ?? chart.gender,
        );
}
