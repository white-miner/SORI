import '../utils/db_map.dart';

/// 원장 마이페이지 — AI 세미나 피드백 보관함 리포트.
class SeminarFeedbackReport {
  const SeminarFeedbackReport({
    required this.id,
    required this.classId,
    required this.shopId,
    required this.classTitle,
    this.eventDate,
    this.completedEnrollmentCount = 0,
    this.topInsightTags = const [],
    this.aiSummaryStrength = '',
    this.aiSummaryImprovement = '',
    this.rawFeedbackCount = 0,
    this.createdAt,
    this.updatedAt,
    this.positiveComments = const [],
  });

  final String id;
  final String classId;
  final String shopId;
  final String classTitle;
  final DateTime? eventDate;

  /// 수강 완료(정산) 인원 — UI 표시용.
  final int completedEnrollmentCount;
  final List<String> topInsightTags;
  final String aiSummaryStrength;
  final String aiSummaryImprovement;
  final int rawFeedbackCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 상세 — 수강생 긍정 코멘트 모음.
  final List<String> positiveComments;

  factory SeminarFeedbackReport.fromMap(Map<String, dynamic> map) {
    final cls = map['seminar_classes'];
    final classMap = cls is Map ? Map<String, dynamic>.from(cls) : map;

    List<String> tags = [];
    final rawTags = map['top_insight_tags'];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList(growable: false);
    }

    List<String> comments = [];
    final rawComments = map['positive_comments'];
    if (rawComments is List) {
      comments = rawComments
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    return SeminarFeedbackReport(
      id: DbMap.asText(map['id']),
      classId: DbMap.asText(map['class_id'] ?? classMap['id']),
      shopId: DbMap.asText(map['shop_id']),
      classTitle: DbMap.asText(classMap['title'] ?? map['class_title'], '세미나'),
      eventDate: DbMap.asDateTime(classMap['event_date'] ?? map['event_date']),
      completedEnrollmentCount: DbMap.asInt(
        classMap['completed_enrollment_count'] ??
            map['completed_enrollment_count'] ??
            map['raw_feedback_count'],
      ),
      topInsightTags: tags,
      aiSummaryStrength: DbMap.asText(map['ai_summary_strength']),
      aiSummaryImprovement: DbMap.asText(map['ai_summary_improvement']),
      rawFeedbackCount: DbMap.asInt(map['raw_feedback_count']),
      createdAt: DbMap.asDateTime(map['created_at']),
      updatedAt: DbMap.asDateTime(map['updated_at']),
      positiveComments: comments,
    );
  }
}
