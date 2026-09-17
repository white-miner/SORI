/// 전자 동의서 법적 고지 텍스트 (의료용어 배제 · 케어/관리 용어 통일).
class ChartConsentTexts {
  ChartConsentTexts._();

  static const String intro =
      '케어 전 고객 확인용 전자 동의서입니다. 작성하지 않아도 차트만 저장할 수 있어요.';

  // —— A. 관리 중 주의사항 및 호전 반응 ——
  static const String mandatoryCareTitle =
      '관리 중 주의사항 및 호전 반응 안내 동의';

  static const List<String> mandatoryCareBody = [
    '고객의 피부 상태 및 체질에 따라 붉어짐, 붓기, 가려움, 각질 부각 등의 일시적인 호전 반응이 나타날 수 있음을 인지합니다.',
    '과거 피부 질환 이력, 특정 화장품 알레르기 등을 사전에 고지할 의무가 있으며, 미고지로 인한 트러블은 샵에 책임을 물을 수 없습니다.',
    '안내받은 홈케어 처방(자외선 차단, 무마찰 세안 등)을 성실히 이행할 것을 약속합니다.',
  ];

  /// 3초 핵심 요약 (주의사항).
  static const String mandatoryCareSummary =
      '관리 후 열감/붉은기는 정상 반응이며 24시간 내 사우나 금지';

  // —— B. 이상 반응 · 의료적 진단 · 보상 ——
  static const String mandatoryReactionTitle =
      '이상 반응에 대한 의료적 진단 및 보상 규정';

  static const List<String> mandatoryReactionBody = [
    "이상 반응으로 인한 피해 보상 청구 시, 반드시 피부과 전문의가 발급한 '본 샵의 관리 부주의가 명백한 원인'임이 명시된 진단서/소견서를 제출해야 보험 보상 절차가 진행됨을 확인합니다.",
    '의학적 인과관계가 증명되지 않은 주관적 심증만으로 과도한 합의금을 요구하거나, 허위 사실로 영업을 방해할 경우 강력한 법적 조치가 취해질 수 있음을 인지합니다.',
  ];

  /// 3초 핵심 요약 (보상/진단).
  static const String mandatoryReactionSummary =
      '의료 행위가 아닌 피부 관리이며 이상 반응 시 샵 안내 수칙 준수';

  // —— C. 회원권 · 다회권 환불 ——
  static const String mandatoryRefundTitle = '회원권 및 다회권 환불 규정 안내';

  static const List<String> mandatoryRefundBody = [
    "중도 해지 시, 이미 제공받은 관리는 '할인가'가 아닌 1회당 '정상가(단과가)' 기준으로 차감되며, 총 결제 금액의 10%가 위약금으로 추가 공제됩니다.",
    '기본 제공/증정받은 화장품을 개봉 및 사용한 경우, 해당 제품의 소비자가격 전액이 환불금에서 공제됩니다.',
    '회원권의 유효기간은 1년(또는 샵 지정일)이며, 기한 경과 시 미사용 잔여 횟수는 소멸되고 양도 및 환불이 불가합니다.',
  ];

  /// 3초 핵심 요약 (환불 규정).
  static const String mandatoryRefundSummary =
      '중도 해지 시 단가(정가) 차감 후 잔여금 환불 규정 적용';

  // —— 선택: 사진 ——
  static const String documentTitle = '고객 정보 및 관리 동의서';

  static const String optionalPhotoTitle =
      '관리 전/중/후 사진 및 영상 촬영 동의';

  /// UI용 짧은 활용 옵션 라벨.
  static const String photoUseMarketing =
      '마케팅 및 사례 공유 (SNS, 블로그 / 눈 가림)';

  static const String photoUseOffline =
      '원내 상담 및 차트 기록용 (외부 유출 불가)';

  /// PDF 인쇄용 단일 활용 범위 문구.
  static const String photoScopeMarketing =
      '활용 범위: 마케팅 및 사례 공유 (SNS, 블로그 / 눈 가림 비식별 처리)';

  static const String photoScopeOffline =
      '활용 범위: 원내 상담 및 차트 기록용 (외부 유출 불가)';
}
