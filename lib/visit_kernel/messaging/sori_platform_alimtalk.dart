/// SORI 플랫폼 공식 중앙 채널 알림톡 — MVP 구조 (PO: 개별 샵 채널 X).
abstract final class SoriPlatformAlimtalk {
  static const channelId = 'sori_official';
  static const channelName = 'SORI 공식';

  static const templates = SoriAlimtalkTemplates();
}

class SoriAlimtalkTemplates {
  const SoriAlimtalkTemplates();

  String get careReminder => 'SORI_CARE_REMINDER_V1';
  String get reviewRequest => 'SORI_REVIEW_REQUEST_V1';
  String get scheduleLeadAck => 'SORI_SCHEDULE_LEAD_ACK_V1';
}

class SoriPlatformAlimtalkMessage {
  const SoriPlatformAlimtalkMessage({
    required this.templateCode,
    required this.recipientPhone,
    required this.shopId,
    required this.shopName,
    this.variables = const {},
  });

  final String templateCode;
  final String recipientPhone;
  final String shopId;
  final String shopName;
  final Map<String, String> variables;
}
