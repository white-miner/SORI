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
    this.consentMandatory = false,
    this.consentPhoto = false,
    this.consentMarketing = false,
    this.consentOfflineOnly = false,
    this.signatureUrl,
    this.caseShared = false,
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

  /// 전자 동의서.
  final bool consentMandatory;
  final bool consentPhoto;
  final bool consentMarketing;
  final bool consentOfflineOnly;
  final String? signatureUrl;

  /// 관리 케이스 공개 공유 여부 (동의 서명 완료 차트만 true 가능).
  final bool caseShared;

  bool get hasFeedbackLine =>
      feedbackToken != null && feedbackLineOpenedAt != null;

  bool get isFirstVisit => visitNumber <= 1;

  /// 정보 활용 동의서 서명 완료 여부.
  bool get isConsentSigned {
    final sig = signatureUrl?.trim() ?? '';
    return sig.isNotEmpty;
  }

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
    bool? consentMandatory,
    bool? consentPhoto,
    bool? consentMarketing,
    bool? consentOfflineOnly,
    String? signatureUrl,
    bool? caseShared,
    bool clearCustomChartNo = false,
    bool clearBeforeImageUrl = false,
    bool clearAfterImageUrl = false,
    bool clearSignatureUrl = false,
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
      consentMandatory: consentMandatory ?? this.consentMandatory,
      consentPhoto: consentPhoto ?? this.consentPhoto,
      consentMarketing: consentMarketing ?? this.consentMarketing,
      consentOfflineOnly: consentOfflineOnly ?? this.consentOfflineOnly,
      signatureUrl:
          clearSignatureUrl ? null : (signatureUrl ?? this.signatureUrl),
      caseShared: caseShared ?? this.caseShared,
    );
  }

  Map<String, dynamic> toMap() => toDbWriteMap(includeId: true);

  /// Supabase customer_charts insert/update 전용 안전 페이로드.
  Map<String, dynamic> toDbWriteMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'shop_id': shopId,
      'customer_id': customerId,
      'visit_number': visitNumber < 1 ? 1 : visitNumber,
      'custom_chart_no': DbMap.asTextOrNull(customChartNo),
      'visit_checked': visitChecked,
      'visit_checked_at': visitCheckedAt?.toUtc().toIso8601String(),
      'before_image_url': DbMap.asTextOrNull(beforeImageUrl),
      'after_image_url': DbMap.asTextOrNull(afterImageUrl),
      'care_name': careName.trim(),
      'treatment_summary': treatmentSummary.trim(),
      'director_insight': directorInsight.trim(),
      'allergy_notes': allergyNotes.trim(),
      'skin_sensitivity': skinSensitivity.trim(),
      'side_effect_history': sideEffectHistory.trim(),
      'customer_requests': customerRequests.trim(),
      'concern_chips': DbMap.sanitizeStringList(concernChips),
      'first_visit_fear_chips': DbMap.sanitizeStringList(firstVisitFearChips),
      'revisit_feedback_chips':
          DbMap.sanitizeStringList(revisitFeedbackChips),
      'feedback_token': DbMap.asTextOrNull(feedbackToken),
      'feedback_line_opened_at':
          feedbackLineOpenedAt?.toUtc().toIso8601String(),
      // 동의서: 미작성 시 false / signature null
      'consent_mandatory': consentMandatory,
      'consent_photo': consentPhoto,
      'consent_marketing': consentMarketing,
      'consent_offline_only': consentOfflineOnly,
      'signature_url': DbMap.asTextOrNull(signatureUrl),
      'case_shared': caseShared,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

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
      consentMandatory: DbMap.asBool(map['consent_mandatory']),
      consentPhoto: DbMap.asBool(map['consent_photo']),
      consentMarketing: DbMap.asBool(map['consent_marketing']),
      consentOfflineOnly: DbMap.asBool(map['consent_offline_only']),
      signatureUrl: DbMap.asTextOrNull(map['signature_url']),
      caseShared: DbMap.asBool(map['case_shared'] ?? map['is_public']),
    );
  }
}
