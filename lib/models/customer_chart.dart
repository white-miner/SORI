class CustomerChart {
  const CustomerChart({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.visitNumber,
    this.visitChecked = false,
    this.visitCheckedAt,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.treatmentSummary = '',
    this.directorInsight = '',
    this.feedbackToken,
    this.feedbackLineOpenedAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final int visitNumber;
  final bool visitChecked;
  final DateTime? visitCheckedAt;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String treatmentSummary;
  final String directorInsight;
  final String? feedbackToken;
  final DateTime? feedbackLineOpenedAt;

  bool get hasFeedbackLine =>
      feedbackToken != null && feedbackLineOpenedAt != null;

  /// 첫 방문이면 네이버 등록 CTA, 회원권 N회차는 복사/공유 CTA.
  bool get isFirstVisit => visitNumber <= 1;

  CustomerChart copyWith({
    String? id,
    String? shopId,
    String? customerId,
    int? visitNumber,
    bool? visitChecked,
    DateTime? visitCheckedAt,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? treatmentSummary,
    String? directorInsight,
    String? feedbackToken,
    DateTime? feedbackLineOpenedAt,
  }) {
    return CustomerChart(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      customerId: customerId ?? this.customerId,
      visitNumber: visitNumber ?? this.visitNumber,
      visitChecked: visitChecked ?? this.visitChecked,
      visitCheckedAt: visitCheckedAt ?? this.visitCheckedAt,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      treatmentSummary: treatmentSummary ?? this.treatmentSummary,
      directorInsight: directorInsight ?? this.directorInsight,
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
        'visit_checked': visitChecked,
        'visit_checked_at': visitCheckedAt?.toIso8601String(),
        'before_image_url': beforeImageUrl,
        'after_image_url': afterImageUrl,
        'treatment_summary': treatmentSummary,
        'director_insight': directorInsight,
        'feedback_token': feedbackToken,
        'feedback_line_opened_at':
            feedbackLineOpenedAt?.toIso8601String(),
      };

  factory CustomerChart.fromMap(Map<String, dynamic> map) {
    return CustomerChart(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String,
      visitNumber: map['visit_number'] as int,
      visitChecked: map['visit_checked'] as bool? ?? false,
      visitCheckedAt: map['visit_checked_at'] != null
          ? DateTime.parse(map['visit_checked_at'] as String)
          : null,
      beforeImageUrl: map['before_image_url'] as String?,
      afterImageUrl: map['after_image_url'] as String?,
      treatmentSummary: map['treatment_summary'] as String? ?? '',
      directorInsight: map['director_insight'] as String? ?? '',
      feedbackToken: map['feedback_token'] as String?,
      feedbackLineOpenedAt: map['feedback_line_opened_at'] != null
          ? DateTime.parse(map['feedback_line_opened_at'] as String)
          : null,
    );
  }
}
