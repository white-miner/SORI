import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import 'package:flutter/material.dart';

/// PO PRD v4.0 — SOS 운영 위험 등급 (CRM 링과 별도 SSOT).
enum SosGrade {
  clear,
  s1,
  s2,
  s3;

  String get dbValue => switch (this) {
        SosGrade.clear => 'clear',
        SosGrade.s1 => 's1',
        SosGrade.s2 => 's2',
        SosGrade.s3 => 's3',
      };

  static SosGrade fromDb(String? raw) {
    return SosGrade.values.firstWhere(
      (e) => e.dbValue == raw?.trim().toLowerCase(),
      orElse: () => SosGrade.clear,
    );
  }

  static SosGrade max(SosGrade a, SosGrade b) {
    return a.index >= b.index ? a : b;
  }

  /// CDG — 좌측 3px 바 색상. S3만 시스템 레드.
  Color? get barColor => switch (this) {
        SosGrade.clear => null,
        SosGrade.s1 => const Color(0xFFE5E5EA),
        SosGrade.s2 => const Color(0xFF3A3A3C),
        SosGrade.s3 => VisitGlassTokens.alert,
      };

  bool get showIcon => index >= SosGrade.s2.index;
}

class SosSignal {
  const SosSignal({
    this.grade = SosGrade.clear,
    this.headline = '',
    this.narrative = '',
    this.sources = const [],
    this.matchedKeywords = const [],
  });

  final SosGrade grade;
  final String headline;
  final String narrative;
  final List<String> sources;
  final List<String> matchedKeywords;

  bool get isElevated => grade.index >= SosGrade.s2.index;

  static const none = SosSignal();
}

class SosKeywordRule {
  const SosKeywordRule({
    required this.keyword,
    required this.grade,
    required this.headline,
    required this.narrative,
    this.shopId,
    this.id,
  });

  final String? id;
  final String? shopId;
  final String keyword;
  final SosGrade grade;
  final String headline;
  final String narrative;

  factory SosKeywordRule.fromMap(Map<String, dynamic> map) {
    return SosKeywordRule(
      id: map['id']?.toString(),
      shopId: map['shop_id']?.toString(),
      keyword: map['keyword']?.toString() ?? '',
      grade: SosGrade.fromDb(map['grade']?.toString()),
      headline: map['headline']?.toString() ?? '',
      narrative: map['narrative']?.toString() ?? '',
    );
  }
}

/// PO 확정 기본 키워드 사전.
const defaultSosKeywordRules = <SosKeywordRule>[
  // S1
  SosKeywordRule(
    keyword: '임신',
    grade: SosGrade.s1,
    headline: '임신 중',
    narrative:
        '호르몬 변화로 피부 반응이 예측하기 어렵습니다. 강한 타격 전 의료 상담을 권장합니다.',
  ),
  SosKeywordRule(
    keyword: '수유',
    grade: SosGrade.s1,
    headline: '수유 중',
    narrative:
        '성분 흡수 경로를 고려해 자극적 시술과 특정 앰플은 보류하세요.',
  ),
  SosKeywordRule(
    keyword: '알레르기',
    grade: SosGrade.s1,
    headline: '알레르기 이력',
    narrative:
        '패치 테스트 없이 새 성분을 도입하지 마세요. 이전 반응 성분을 먼저 확인하세요.',
  ),
  // S2
  SosKeywordRule(
    keyword: '부작용',
    grade: SosGrade.s2,
    headline: '부작용 이력',
    narrative:
        '과거 반응 패턴이 반복될 수 있습니다. 타격 심도를 1단계 낮추고 관찰 간격을 늘리세요.',
  ),
  SosKeywordRule(
    keyword: '스테로이드',
    grade: SosGrade.s2,
    headline: '스테로이드 복용',
    narrative:
        '장벽 얇아짐과 멍·붉은기 위험이 높아집니다. 마찰과 열감 자극을 최소화하세요.',
  ),
  SosKeywordRule(
    keyword: '켈로이드',
    grade: SosGrade.s2,
    headline: '켈로이드 체질 의심',
    narrative:
        '흉터 반응 위험이 있습니다. 레이저·니들 전 소구역 패치 테스트를 권장합니다.',
  ),
  // S3
  SosKeywordRule(
    keyword: '활성 여드름',
    grade: SosGrade.s3,
    headline: '활성 여드름',
    narrative:
        '염증 부위 타격은 번질 수 있습니다. 진정·항염 프로토콜을 우선하고 시술 연기를 검토하세요.',
  ),
  SosKeywordRule(
    keyword: '여드름',
    grade: SosGrade.s3,
    headline: '활성 여드름',
    narrative:
        '염증 부위 타격은 번질 수 있습니다. 진정·항염 프로토콜을 우선하고 시술 연기를 검토하세요.',
  ),
  SosKeywordRule(
    keyword: '홍조',
    grade: SosGrade.s3,
    headline: '심한 홍조',
    narrative:
        '혈관 확장 상태에서 열·마찰 자극이 악화됩니다. 냉각 진정 후 재평가하세요.',
  ),
  SosKeywordRule(
    keyword: '극건조',
    grade: SosGrade.s3,
    headline: '극건조',
    narrative:
        '장벽 붕괴 위험이 있습니다. 산 성분·물리 마찰을 금지하고 보습 처방을 우선하세요.',
  ),
  SosKeywordRule(
    keyword: '레이저',
    grade: SosGrade.s3,
    headline: '레이저 금기 가능',
    narrative:
        '피부 상태에 따라 레이저 출력을 낮추거나 연기해야 합니다. 장벽 슬라이더로 재확인하세요.',
  ),
];
