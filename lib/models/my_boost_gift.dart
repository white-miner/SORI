import '../utils/db_map.dart';

/// 고객 「내가 후원한 케이스」항목.
class MyBoostGiftItem {
  const MyBoostGiftItem({
    required this.fanGiftId,
    required this.targetType,
    this.chartId,
    this.shopId = '',
    this.shopName = '',
    this.sku = '',
    this.echoSpent = 0,
    this.giftKind = 'boost',
    this.createdAt,
    this.caseTitle = '',
    this.hasThankYou = false,
    this.thankYouPostId,
  });

  final String fanGiftId;
  final String targetType;
  final String? chartId;
  final String shopId;
  final String shopName;
  final String sku;
  final int echoSpent;
  final String giftKind;
  final DateTime? createdAt;
  final String caseTitle;
  final bool hasThankYou;
  final String? thankYouPostId;

  bool get isSpecialGift =>
      giftKind == 'boost_special_gold' ||
      giftKind == 'boost_special_platinum';

  String get tierLabel => switch (giftKind) {
        'boost_special_platinum' => '플래티넘 스페셜',
        'boost_special_gold' => '골드 스페셜',
        _ => '부스터 후원',
      };

  factory MyBoostGiftItem.fromMap(Map<String, dynamic> map) {
    return MyBoostGiftItem(
      fanGiftId: DbMap.asText(map['fan_gift_id'] ?? map['fanGiftId']),
      targetType: DbMap.asText(map['target_type'] ?? map['targetType'], 'chart'),
      chartId: DbMap.asTextOrNull(map['chart_id'] ?? map['chartId']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      shopName: DbMap.asText(map['shop_name'] ?? map['shopName']),
      sku: DbMap.asText(map['sku']),
      echoSpent: DbMap.asInt(map['echo_spent'] ?? map['echoSpent']),
      giftKind: DbMap.asText(map['gift_kind'] ?? map['giftKind'], 'boost'),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      caseTitle: DbMap.asText(map['case_title'] ?? map['caseTitle'], '케이스'),
      hasThankYou: map['has_thank_you'] == true || map['hasThankYou'] == true,
      thankYouPostId: DbMap.asTextOrNull(
        map['thank_you_post_id'] ?? map['thankYouPostId'],
      ),
    );
  }
}

/// 원장 후원 알림 — 감사 위스퍼 숏컷용.
class SupporterNotificationItem {
  const SupporterNotificationItem({
    required this.id,
    this.kind = 'fan_boost',
    this.title = '',
    this.body = '',
    this.createdAt,
    this.fanGiftId,
    this.chartId,
    this.supporterName = '후원자',
    this.supporterCustomerId,
    this.hasThankYou = false,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime? createdAt;
  final String? fanGiftId;
  final String? chartId;
  final String supporterName;
  final String? supporterCustomerId;
  final bool hasThankYou;

  bool get canThank =>
      fanGiftId != null && fanGiftId!.trim().isNotEmpty && !hasThankYou;

  factory SupporterNotificationItem.fromMap(Map<String, dynamic> map) {
    final payload = map['payload'];
    Map<String, dynamic> p = const {};
    if (payload is Map) {
      p = Map<String, dynamic>.from(payload);
    }
    return SupporterNotificationItem(
      id: DbMap.asText(map['id'] ?? map['notification_id']),
      kind: DbMap.asText(map['kind'], 'fan_boost'),
      title: DbMap.asText(map['title']),
      body: DbMap.asText(map['body']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      fanGiftId: DbMap.asTextOrNull(
        map['fan_gift_id'] ?? map['fanGiftId'] ?? p['fan_gift_id'],
      ),
      chartId: DbMap.asTextOrNull(
        map['chart_id'] ?? map['chartId'] ?? p['chart_id'],
      ),
      supporterName: DbMap.asText(
        map['supporter_name'] ??
            map['supporterName'] ??
            p['supporter_name'] ??
            p['fan_name'],
        '후원자',
      ),
      supporterCustomerId: DbMap.asTextOrNull(
        map['supporter_customer_id'] ??
            map['supporterCustomerId'] ??
            p['customer_id'],
      ),
      hasThankYou:
          map['has_thank_you'] == true || map['hasThankYou'] == true,
    );
  }
}
