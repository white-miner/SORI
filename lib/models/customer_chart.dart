import '../utils/db_map.dart';

class CustomerChart {
  const CustomerChart({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.visitNumber,
    this.customChartNo,
    this.visitChecked = false,
    this.visitCheckedAt,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.careName = '',
    this.treatmentSummary = '',
    this.directorInsight = '',
    this.allergyNotes = '',
    this.skinSensitivity = '',
    this.sideEffectHistory = '',
    this.customerRequests = '',
    this.concernChips = const [],
    this.firstVisitFearChips = const [],
    this.revisitFeedbackChips = const [],
    this.feedbackToken,
    this.feedbackLineOpenedAt,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final int visitNumber;

  /// 원장이 수동 지정하는 외부 차트 번호 (없으면 visitNumber 표시).
  final String? customChartNo;
  final bool visitChecked;
  final DateTime? visitCheckedAt;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String careName;
  final String treatmentSummary;
  final String directorInsight;

  /// 방문 차트에 기록하는 메디컬 정보 (고객 등록 폼과 분리).
  final String allergyNotes;
  final String skinSensitivity;
  final String sideEffectHistory;
  final String customerRequests;

  final List<String> concernChips;
  final List<String> firstVisitFearChips;
  final List<String> revisitFeedbackChips;
  final String? feedbackToken;
  final DateTime? feedbackLineOpenedAt;

  /// DB created_at (타임라인 날짜 표시용, 쓰기 시 서버 기본값 사용).
  final DateTime? createdAt;

  bool get hasFeedbackLine =>
      feedbackToken != null && feedbackLineOpenedAt != null;

  bool get isFirstVisit => visitNumber <= 1;

  String get displayChartNo =>
      (customChartNo != null && customChartNo!.trim().isNotEmpty)
          ? customChartNo!.trim()
          : '$visitNumber';

  CustomerChart copyWith({
    String? id,
    String? shopId,
    String? customerId,
    int? visitNumber,
    String? customChartNo,
    bool? visitChecked,
    DateTime? visitCheckedAt,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? careName,
    String? treatmentSummary,
    String? directorInsight,
    String? allergyNotes,
    String? skinSensitivity,
    String? sideEffectHistory,
    String? customerRequests,
    List<String>? concernChips,
    List<String>? firstVisitFearChips,
    List<String>? revisitFeedbackChips,
    String? feedbackToken,
    DateTime? feedbackLineOpenedAt,
    DateTime? createdAt,
    bool clearCustomChartNo = false,
    bool clearBeforeImageUrl = false,
    bool clearAfterImageUrl = false,
  }) {
    return CustomerChart(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      customerId: customerId ?? this.customerId,
      visitNumber: visitNumber ?? this.visitNumber,
      customChartNo:
          clearCustomChartNo ? null : (customChartNo ?? this.customChartNo),
      visitChecked: visitChecked ?? this.visitChecked,
      visitCheckedAt: visitCheckedAt ?? this.visitCheckedAt,
      beforeImageUrl: clearBeforeImageUrl
          ? null
          : (beforeImageUrl ?? this.beforeImageUrl),
      afterImageUrl: clearAfterImageUrl
          ? null
          : (afterImageUrl ?? this.afterImageUrl),
      careName: careName ?? this.careName,
      treatmentSummary: treatmentSummary ?? this.treatmentSummary,
      directorInsight: directorInsight ?? this.directorInsight,
      allergyNotes: allergyNotes ?? this.allergyNotes,
      skinSensitivity: skinSensitivity ?? this.skinSensitivity,
      sideEffectHistory: sideEffectHistory ?? this.sideEffectHistory,
      customerRequests: customerRequests ?? this.customerRequests,
      concernChips: concernChips ?? this.concernChips,
      firstVisitFearChips: firstVisitFearChips ?? this.firstVisitFearChips,
      revisitFeedbackChips:
          revisitFeedbackChips ?? this.revisitFeedbackChips,
      feedbackToken: feedbackToken ?? this.feedbackToken,
      feedbackLineOpenedAt:
          feedbackLineOpenedAt ?? this.feedbackLineOpenedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'customer_id': customerId,
        'visit_number': visitNumber,
        'custom_chart_no': customChartNo,
        'visit_checked': visitChecked,
        'visit_checked_at': visitCheckedAt?.toIso8601String(),
        // 미첨부는 빈 문자열이 아니라 명시적 null로 저장한다.
        'before_image_url': DbMap.nullIfBlank(beforeImageUrl),
        'after_image_url': DbMap.nullIfBlank(afterImageUrl),
        'care_name': careName,
        'treatment_summary': treatmentSummary,
        'director_insight': directorInsight,
        // 메디컬/요약 미입력도 null이 아닌 '' 로 안전하게 기록.
        'allergy_notes': allergyNotes,
        'skin_sensitivity': skinSensitivity,
        'side_effect_history': sideEffectHistory,
        'customer_requests': customerRequests,
        'concern_chips': concernChips,
        'first_visit_fear_chips': firstVisitFearChips,
        'revisit_feedback_chips': revisitFeedbackChips,
        'feedback_token': feedbackToken,
        'feedback_line_opened_at':
            feedbackLineOpenedAt?.toIso8601String(),
      };

  factory CustomerChart.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(map['id']);
    final shopId = DbMap.asText(map['shop_id']);
    final customerId = DbMap.asText(map['customer_id']);
    if (id.isEmpty || shopId.isEmpty || customerId.isEmpty) {
      throw FormatException('customer_chart row missing required fields: $map');
    }

    return CustomerChart(
      id: id,
      shopId: shopId,
      customerId: customerId,
      visitNumber: DbMap.asInt(map['visit_number'], 1),
      customChartNo: DbMap.asTextOrNull(map['custom_chart_no']),
      visitChecked: DbMap.asBool(map['visit_checked']),
      visitCheckedAt: DbMap.asDateTime(map['visit_checked_at']),
      beforeImageUrl: DbMap.asTextOrNull(map['before_image_url']),
      afterImageUrl: DbMap.asTextOrNull(map['after_image_url']),
      careName: DbMap.asText(map['care_name']),
      treatmentSummary: DbMap.asText(map['treatment_summary']),
      directorInsight: DbMap.asText(map['director_insight']),
      allergyNotes: DbMap.asText(map['allergy_notes']),
      skinSensitivity: DbMap.asText(map['skin_sensitivity']),
      sideEffectHistory: DbMap.asText(map['side_effect_history']),
      customerRequests: DbMap.asText(map['customer_requests']),
      concernChips: DbMap.asStringList(map['concern_chips']),
      firstVisitFearChips: DbMap.asStringList(map['first_visit_fear_chips']),
      revisitFeedbackChips: DbMap.asStringList(map['revisit_feedback_chips']),
      feedbackToken: DbMap.asTextOrNull(map['feedback_token']),
      feedbackLineOpenedAt: DbMap.asDateTime(map['feedback_line_opened_at']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
