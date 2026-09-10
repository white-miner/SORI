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
        OmniComposeCategory.whisper => 'Whisper',
        OmniComposeCategory.baShare => '전후(B/A)',
        OmniComposeCategory.seminar => '세미나',
        OmniComposeCategory.reviewMarket => '중고',
        OmniComposeCategory.tipDevice => '기기 리뷰',
        OmniComposeCategory.tipProduct => '제품 리뷰',
        OmniComposeCategory.mentorAsk => '멘토 요청',
        OmniComposeCategory.mentorOffer => '멘토 지원',
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
}
