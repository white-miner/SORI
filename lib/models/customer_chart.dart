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
    this.concernChips = const [],
    this.firstVisitFearChips = const [],
    this.revisitFeedbackChips = const [],
    this.feedbackToken,
    this.feedbackLineOpenedAt,
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
  final List<String> concernChips;
  final List<String> firstVisitFearChips;
  final List<String> revisitFeedbackChips;
  final String? feedbackToken;
  final DateTime? feedbackLineOpenedAt;

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
    List<String>? concernChips,
    List<String>? firstVisitFearChips,
    List<String>? revisitFeedbackChips,
    String? feedbackToken,
    DateTime? feedbackLineOpenedAt,
    bool clearCustomChartNo = false,
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
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      careName: careName ?? this.careName,
      treatmentSummary: treatmentSummary ?? this.treatmentSummary,
      directorInsight: directorInsight ?? this.directorInsight,
      concernChips: concernChips ?? this.concernChips,
      firstVisitFearChips: firstVisitFearChips ?? this.firstVisitFearChips,
      revisitFeedbackChips:
          revisitFeedbackChips ?? this.revisitFeedbackChips,
      feedbackToken: feedbackToken ?? this.feedbackToken,
      feedbackLineOpenedAt:
          feedbackLineOpenedAt ?? this.feedbackLineOpenedAt,
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
        'before_image_url': beforeImageUrl,
        'after_image_url': afterImageUrl,
        'care_name': careName,
        'treatment_summary': treatmentSummary,
        'director_insight': directorInsight,
        'concern_chips': concernChips,
        'first_visit_fear_chips': firstVisitFearChips,
        'revisit_feedback_chips': revisitFeedbackChips,
        'feedback_token': feedbackToken,
        'feedback_line_opened_at':
            feedbackLineOpenedAt?.toIso8601String(),
      };

  factory CustomerChart.fromMap(Map<String, dynamic> map) {
    List<String> listOf(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      return const [];
    }

    return CustomerChart(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String,
      visitNumber: map['visit_number'] as int,
      customChartNo: map['custom_chart_no'] as String?,
      visitChecked: map['visit_checked'] as bool? ?? false,
      visitCheckedAt: map['visit_checked_at'] != null
          ? DateTime.parse(map['visit_checked_at'] as String)
          : null,
      beforeImageUrl: map['before_image_url'] as String?,
      afterImageUrl: map['after_image_url'] as String?,
      careName: map['care_name'] as String? ?? '',
      treatmentSummary: map['treatment_summary'] as String? ?? '',
      directorInsight: map['director_insight'] as String? ?? '',
      concernChips: listOf(map['concern_chips']),
      firstVisitFearChips: listOf(map['first_visit_fear_chips']),
      revisitFeedbackChips: listOf(map['revisit_feedback_chips']),
      feedbackToken: map['feedback_token'] as String?,
      feedbackLineOpenedAt: map['feedback_line_opened_at'] != null
          ? DateTime.parse(map['feedback_line_opened_at'] as String)
          : null,
    );
  }
}
