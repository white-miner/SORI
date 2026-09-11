import '../utils/category_presentation_map.dart';

/// Omni / 빠른 등록 카테고리 (삭제·리네임 금지 — 값만 Expand).
enum OmniComposeCategory {
  whisper,
  baShare,
  seminar,
  reviewMarket,
  /// C6 Expand
  tipDevice,
  tipProduct,
  mentorAsk,
  mentorOffer;

  String get label => switch (this) {
        OmniComposeCategory.whisper =>
          CategoryPresentationMap.labelOf('whisper', fallback: '조용한 이야기'),
        OmniComposeCategory.baShare => '전후(B/A)',
        OmniComposeCategory.seminar =>
          CategoryPresentationMap.labelOf('seminar', fallback: '세미나'),
        OmniComposeCategory.reviewMarket => '중고',
        OmniComposeCategory.tipDevice =>
          CategoryPresentationMap.labelOf('tip_device', fallback: '현장 팁'),
        OmniComposeCategory.tipProduct =>
          CategoryPresentationMap.labelOf('tip_product', fallback: '현장 팁'),
        OmniComposeCategory.mentorAsk =>
          CategoryPresentationMap.labelOf('mentor_ask', fallback: '질문'),
        OmniComposeCategory.mentorOffer => '멘토 지원',
      };

  String get description => switch (this) {
        OmniComposeCategory.whisper =>
          CategoryPresentationMap.descriptionOf('whisper'),
        OmniComposeCategory.seminar =>
          CategoryPresentationMap.descriptionOf('seminar'),
        OmniComposeCategory.tipDevice =>
          CategoryPresentationMap.descriptionOf('tip_device'),
        OmniComposeCategory.tipProduct =>
          CategoryPresentationMap.descriptionOf('tip_product'),
        OmniComposeCategory.mentorAsk =>
          CategoryPresentationMap.descriptionOf('mentor_ask'),
        OmniComposeCategory.baShare => '전후 사진을 나눠요',
        OmniComposeCategory.reviewMarket => '중고 기기를 올려요',
        OmniComposeCategory.mentorOffer => '도움을 줄 수 있어요',
      };

  /// PRD v7.8 C6 — 빠른 등록 시트 칩 (B/A·세미나·팁·멘토).
  static const List<OmniComposeCategory> quickComposeCategories = [
    baShare,
    seminar,
    tipDevice,
    tipProduct,
    mentorAsk,
    mentorOffer,
  ];

  /// 기본 노출 최대 5 (R3) — whisper를 포함해 용어 체계를 고정.
  static const List<OmniComposeCategory> formCategoriesPrimary = [
    whisper,
    baShare,
    seminar,
    tipDevice,
    mentorAsk,
  ];

  /// 작성 폼에 노출하는 칩 (시트 6종 + Whisper·중고).
  static const List<OmniComposeCategory> formCategories = [
    baShare,
    seminar,
    tipDevice,
    tipProduct,
    mentorAsk,
    mentorOffer,
    whisper,
    reviewMarket,
  ];

  static List<OmniComposeCategory> get formCategoriesMore => formCategories
      .where((c) => !formCategoriesPrimary.contains(c))
      .toList(growable: false);

  static List<OmniComposeCategory> get quickComposePrimary =>
      quickComposeCategories.take(5).toList(growable: false);

  static List<OmniComposeCategory> get quickComposeMore =>
      quickComposeCategories.skip(5).toList(growable: false);
}
