import '../utils/db_map.dart';

/// 스마트 회원권 지갑 카드용 뷰 모델 (샵 Join 포함).
class MembershipTicket {
  const MembershipTicket({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.shopName,
    required this.ticketName,
    required this.totalVisits,
    required this.usedVisits,
    this.customerPhoneDigits = '',
    this.expiresAt,
    this.naverPlaceUrl = '',
    this.isActive = true,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String customerPhoneDigits;
  final String shopName;
  final String ticketName;
  final int totalVisits;
  final int usedVisits;
  final DateTime? expiresAt;
  final String naverPlaceUrl;
  final bool isActive;

  int get remainingVisits => (totalVisits - usedVisits).clamp(0, 999);

  bool get isLow => remainingVisits > 0 && remainingVisits <= 2;

  double get progress {
    if (totalVisits <= 0) return 0;
    return (remainingVisits / totalVisits).clamp(0.0, 1.0);
  }

  bool get hasNaverPlace => naverPlaceUrl.trim().isNotEmpty;

  MembershipTicket copyWith({
    String? id,
    String? shopId,
    String? customerId,
    String? customerPhoneDigits,
    String? shopName,
    String? ticketName,
    int? totalVisits,
    int? usedVisits,
    DateTime? expiresAt,
    String? naverPlaceUrl,
    bool? isActive,
    bool clearExpiresAt = false,
  }) {
    return MembershipTicket(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      customerId: customerId ?? this.customerId,
      customerPhoneDigits: customerPhoneDigits ?? this.customerPhoneDigits,
      shopName: shopName ?? this.shopName,
      ticketName: ticketName ?? this.ticketName,
      totalVisits: totalVisits ?? this.totalVisits,
      usedVisits: usedVisits ?? this.usedVisits,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  factory MembershipTicket.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? shop;
    final rawShop = map['shops'];
    if (rawShop is Map) {
      shop = Map<String, dynamic>.from(rawShop);
    }

    return MembershipTicket(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? shop?['id']),
      customerId: DbMap.asText(map['customer_id']),
      customerPhoneDigits: DbMap.asText(map['customer_phone_digits']),
      shopName: DbMap.asText(
        map['shop_name'] ?? shop?['name'],
        'SORI 샵',
      ),
      ticketName: DbMap.asText(
        map['ticket_name'] ?? map['service_name'],
        '회원권',
      ),
      totalVisits: DbMap.asInt(map['total_visits']),
      usedVisits: DbMap.asInt(map['used_visits']),
      expiresAt: DbMap.asDateTime(map['expires_at']),
      naverPlaceUrl: DbMap.asText(
        map['naver_place_url'] ?? shop?['naver_place_url'],
      ),
      isActive: DbMap.asBool(map['is_active'], true),
    );
  }
}
