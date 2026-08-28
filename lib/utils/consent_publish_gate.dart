import '../models/customer_chart.dart';

/// B/A 커뮤니티 발행 동의 게이트 (S-B SSOT).
enum ConsentPublishGate {
  ok,
  notSigned,
  offlineOnly,
  missingMarketing,
}

ConsentPublishGate canPublishBa(CustomerChart chart) {
  if (!chart.isConsentSigned) return ConsentPublishGate.notSigned;
  // 원내 자료만 동의 + SNS 마케팅 미동의 → 차단
  if (chart.consentOfflineOnly && !chart.consentMarketing) {
    return ConsentPublishGate.offlineOnly;
  }
  if (!chart.consentMarketing) return ConsentPublishGate.missingMarketing;
  return ConsentPublishGate.ok;
}

extension ConsentPublishGateX on ConsentPublishGate {
  bool get allowsPublish => this == ConsentPublishGate.ok;

  String get alertMessage => switch (this) {
        ConsentPublishGate.ok => '',
        ConsentPublishGate.notSigned =>
          '고객의 정보 활용 동의서 서명이 필요합니다.',
        ConsentPublishGate.offlineOnly ||
        ConsentPublishGate.missingMarketing =>
          '고객의 SNS 공유 동의가 필요합니다.',
      };

  /// UI 배지용 짧은 라벨.
  String get badgeLabel => switch (this) {
        ConsentPublishGate.ok => 'SNS 공유 가능',
        ConsentPublishGate.notSigned => '동의 미체결',
        ConsentPublishGate.offlineOnly => '원내만',
        ConsentPublishGate.missingMarketing => 'SNS 동의 필요',
      };
}
