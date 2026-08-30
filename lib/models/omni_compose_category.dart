enum OmniComposeCategory {
  whisper,
  baShare,
  seminar,
  reviewMarket;

  String get label => switch (this) {
        OmniComposeCategory.whisper => 'Whisper',
        OmniComposeCategory.baShare => 'B/A 공유',
        OmniComposeCategory.seminar => '세미나 모집',
        OmniComposeCategory.reviewMarket => '리뷰/중고',
      };
}
