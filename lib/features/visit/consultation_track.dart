/// 상담 탭 Two-Track — 신규 vs 기존 고객 진입 경로.
enum ConsultationTrack {
  newCustomer,
  returning;

  String get label => switch (this) {
        ConsultationTrack.newCustomer => '신규 고객',
        ConsultationTrack.returning => '기존 고객',
      };
}
