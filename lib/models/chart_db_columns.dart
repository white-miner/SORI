/// 차트 DB 쓰기 SSOT — `CustomerChart.toDbWriteMap` 키와 1:1.
/// 마이그레이션 `023_chart_records_ssot_full_sync.sql` 과 항상 동기화할 것.
abstract final class ChartDbColumns {
  /// 앱이 Supabase `chart_records`(→ customer_charts) 로 전송하는 컬럼명.
  static const List<String> writeKeys = [
    'id',
    'shop_id',
    'customer_id',
    'visit_number',
    'custom_chart_no',
    'visit_checked',
    'visit_checked_at',
    'before_image_url',
    'after_image_url',
    'photo_meta',
    'care_name',
    'device_info',
    'treatment_summary',
    'director_insight',
    'allergy_notes',
    'skin_sensitivity',
    'side_effect_history',
    'customer_requests',
    'concern_chips',
    'care_tags',
    'first_visit_fear_chips',
    'revisit_feedback_chips',
    'feedback_token',
    'feedback_line_opened_at',
    'consent_mandatory',
    'consent_photo',
    'consent_marketing',
    'consent_offline_only',
    'signature_url',
    'consent_pdf_url',
    'is_case_shared',
    'prescription_tags',
    'home_care_prescriptions',
    'guardian_phone',
    'info_view_consent',
    'home_care_mission_checks',
    'updated_at',
  ];

  /// PGRST204 strip 재시도에서도 절대 제거하면 안 되는 NOT NULL FK.
  /// (제거 시 insert 후 `customer_id: null` FormatException / NOT NULL 위반)
  static const Set<String> protectedWriteKeys = {
    'shop_id',
    'customer_id',
  };

  /// 앱 대면 관계명 (뷰 또는 테이블). 물리 저장은 customer_charts.
  static const String relation = 'chart_records';

  /// 물리 테이블 / 폴백.
  static const String physicalTable = 'customer_charts';
}
