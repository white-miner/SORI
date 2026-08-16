import '../utils/db_map.dart';
import 'chart_db_columns.dart';
import 'home_care_prescriptions.dart';

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
    this.homeCarePrescriptions = const [],
    this.guardianPhone,
    this.infoViewConsent = false,
    this.homeCareMissionChecks = const [false, false, false],
    this.consentPdfUrl,
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

  /// 전자 동의서 PDF public URL.
  final String? consentPdfUrl;

  /// 관리 케이스 공개 공유 여부 (동의 서명 완료 차트만 true 가능).
  final bool caseShared;

  /// 홈케어 처방 태그 ID 목록.
  final List<String> homeCarePrescriptions;

  /// 보호자 연락처 (가족 스위처 매칭).
  final String? guardianPhone;

  /// 보호자 정보 열람 동의.
  final bool infoViewConsent;

  /// 시술 후 3일 미션 체크 상태.
  final List<bool> homeCareMissionChecks;

  bool get hasBeforeImage =>
      beforeImageUrl != null && beforeImageUrl!.trim().isNotEmpty;

  bool get hasAfterImage =>
      afterImageUrl != null && afterImageUrl!.trim().isNotEmpty;

  /// Before만 있고 After 미등록 — 단계별 업로드 Finalize 대상.
  bool get needsAfterPhoto => hasBeforeImage && !hasAfterImage;

  /// 피드 해시태그 — care_tags 우선, 없으면 concern_chips.
  List<String> get careTags =>
      concernChips.where((e) => e.trim().isNotEmpty).toList(growable: false);

  bool get hasFeedbackLine =>
      feedbackToken != null && feedbackLineOpenedAt != null;

  bool get isFirstVisit => visitNumber <= 1;

  /// 정보 활용 동의서 서명/PDF 완료 여부.
  bool get isConsentSigned {
    final sig = signatureUrl?.trim() ?? '';
    final pdf = consentPdfUrl?.trim() ?? '';
    return sig.isNotEmpty || pdf.isNotEmpty;
  }

  /// 동의 체결 기준일 (표시용).
  DateTime? get consentSignedAt =>
      createdAt ?? visitCheckedAt ?? feedbackLineOpenedAt;

  String get displayChartNo =>
      (customChartNo != null && customChartNo!.trim().isNotEmpty)
          ? customChartNo!.trim()
          : '$visitNumber';

  /// 오픈 피드용 — PII/토큰/메디컬 메모를 제거한 투영.
  CustomerChart asPublicFeedProjection() {
    return CustomerChart(
      id: id,
      shopId: shopId,
      customerId: '',
      visitNumber: visitNumber,
      visitChecked: visitChecked,
      visitCheckedAt: visitCheckedAt,
      beforeImageUrl: beforeImageUrl,
      afterImageUrl: afterImageUrl,
      careName: careName,
      treatmentSummary: '',
      directorInsight: '',
      allergyNotes: '',
      skinSensitivity: '',
      sideEffectHistory: '',
      customerRequests: '',
      concernChips: concernChips,
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
      feedbackToken: null,
      feedbackLineOpenedAt: null,
      createdAt: createdAt,
      consentMandatory: false,
      consentPhoto: false,
      consentMarketing: false,
      consentOfflineOnly: false,
      signatureUrl: null,
      consentPdfUrl: null,
      caseShared: true,
      homeCarePrescriptions: const [],
      guardianPhone: null,
      infoViewConsent: false,
      homeCareMissionChecks: const [false, false, false],
    );
  }

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
    String? consentPdfUrl,
    bool? caseShared,
    List<String>? homeCarePrescriptions,
    String? guardianPhone,
    bool? infoViewConsent,
    List<bool>? homeCareMissionChecks,
    bool clearCustomChartNo = false,
    bool clearBeforeImageUrl = false,
    bool clearAfterImageUrl = false,
    bool clearSignatureUrl = false,
    bool clearConsentPdfUrl = false,
    bool clearGuardianPhone = false,
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
      consentPdfUrl:
          clearConsentPdfUrl ? null : (consentPdfUrl ?? this.consentPdfUrl),
      caseShared: caseShared ?? this.caseShared,
      homeCarePrescriptions:
          homeCarePrescriptions ?? this.homeCarePrescriptions,
      guardianPhone: clearGuardianPhone
          ? null
          : (guardianPhone ?? this.guardianPhone),
      infoViewConsent: infoViewConsent ?? this.infoViewConsent,
      homeCareMissionChecks:
          homeCareMissionChecks ?? this.homeCareMissionChecks,
    );
  }

  static List<bool> normalizeMissionChecks(List<bool>? raw) {
    final base = List<bool>.filled(3, false);
    if (raw == null) return base;
    for (var i = 0; i < 3 && i < raw.length; i++) {
      base[i] = raw[i];
    }
    return base;
  }

  static List<bool> missionChecksFromDynamic(dynamic raw) {
    if (raw is! List) return const [false, false, false];
    final out = <bool>[];
    for (final e in raw) {
      if (e is bool) {
        out.add(e);
      } else if (e is num) {
        out.add(e != 0);
      } else if (e is String) {
        out.add(e.toLowerCase() == 'true' || e == '1');
      } else {
        out.add(false);
      }
    }
    return normalizeMissionChecks(out);
  }

  Map<String, dynamic> toMap() => toDbWriteMap(includeId: true);

  /// Supabase `chart_records`(= customer_charts) insert/update 전용 안전 페이로드.
  /// 키 목록은 [ChartDbColumns.writeKeys] / migration 023 과 SSOT.
  Map<String, dynamic> toDbWriteMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'shop_id': shopId,
      // NOT NULL FK — 빈 문자열/null 전송 금지 (PGRST strip 후에도 재주입됨)
      'customer_id': customerId.trim(),
      'visit_number': visitNumber < 1 ? 1 : visitNumber,
      'custom_chart_no': DbMap.asTextOrNull(customChartNo),
      'visit_checked': visitChecked,
      'visit_checked_at': visitCheckedAt?.toUtc().toIso8601String(),
      'before_image_url': DbMap.asTextOrNull(beforeImageUrl),
      'after_image_url': DbMap.asTextOrNull(afterImageUrl),
      'photo_meta': {
        if (beforeImageUrl != null && beforeImageUrl!.trim().isNotEmpty)
          'before': {
            'visit_number': visitNumber < 1 ? 1 : visitNumber,
            'chart_id': id,
            'kind': 'before',
          },
        if (afterImageUrl != null && afterImageUrl!.trim().isNotEmpty)
          'after': {
            'visit_number': visitNumber < 1 ? 1 : visitNumber,
            'chart_id': id,
            'kind': 'after',
          },
      },
      'care_name': careName.trim(),
      'treatment_summary': treatmentSummary.trim(),
      'director_insight': directorInsight.trim(),
      'allergy_notes': allergyNotes.trim(),
      'skin_sensitivity': skinSensitivity.trim(),
      'side_effect_history': sideEffectHistory.trim(),
      'customer_requests': customerRequests.trim(),
      'concern_chips': DbMap.sanitizeStringList(concernChips),
      'care_tags': DbMap.sanitizeStringList(concernChips),
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
      'consent_pdf_url': DbMap.asTextOrNull(consentPdfUrl),
      // DB 컬럼명: is_case_shared (legacy case_shared 미전송 → PGRST204 방지)
      'is_case_shared': caseShared,
      'prescription_tags': HomecareDictionary.sanitizeTagIds(
        homeCarePrescriptions,
      ),
      'home_care_prescriptions': HomecareDictionary.sanitizeTagIds(
        homeCarePrescriptions,
      ),
      'guardian_phone': () {
        final digits = (guardianPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        return digits.isEmpty ? null : digits;
      }(),
      'info_view_consent': infoViewConsent,
      'home_care_mission_checks':
          normalizeMissionChecks(homeCareMissionChecks),
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
    if (id.isEmpty || shopId.isEmpty) {
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
      concernChips: () {
        final tags = DbMap.asStringList(map['care_tags']);
        if (tags.isNotEmpty) return tags;
        return DbMap.asStringList(map['concern_chips']);
      }(),
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
      consentPdfUrl: DbMap.asTextOrNull(map['consent_pdf_url']),
      caseShared: DbMap.asBool(
        map['is_case_shared'] ?? map['case_shared'] ?? map['is_public'],
      ),
      homeCarePrescriptions: HomecareDictionary.sanitizeTagIds(
        DbMap.asStringList(
          map['prescription_tags'] ?? map['home_care_prescriptions'],
        ),
      ),
      guardianPhone: () {
        final raw = DbMap.asTextOrNull(map['guardian_phone']);
        if (raw == null) return null;
        final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.isEmpty ? null : digits;
      }(),
      infoViewConsent: DbMap.asBool(map['info_view_consent']),
      homeCareMissionChecks:
          missionChecksFromDynamic(map['home_care_mission_checks']),
    );
  }
}
