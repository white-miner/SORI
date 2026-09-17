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
    this.paidAmount = 0,
    this.perSessionValue = 0,
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
  final int paidAmount;
  final int perSessionValue;

  int get remainingVisits => (totalVisits - usedVisits).clamp(0, 999);

  int get effectivePerSession {
    if (perSessionValue > 0) return perSessionValue;
    if (paidAmount > 0 && totalVisits > 0) {
      return (paidAmount / totalVisits).round();
    }
    return 0;
  }

  int get laborDebtWon => effectivePerSession * remainingVisits;

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
    int? paidAmount,
    int? perSessionValue,
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
      paidAmount: paidAmount ?? this.paidAmount,
      perSessionValue: perSessionValue ?? this.perSessionValue,
    );
  }

  factory MembershipTicket.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? shop;
    final rawShop = map['shops'];
    if (rawShop is Map) {
      shop = Map<String, dynamic>.from(rawShop);
    }

    final total = DbMap.asInt(map['total_visits']);
    final paid = DbMap.asInt(map['paid_amount']);
    var per = DbMap.asInt(map['per_session_value']);
    if (per <= 0 && paid > 0 && total > 0) {
      per = (paid / total).round();
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
      totalVisits: total,
      usedVisits: DbMap.asInt(map['used_visits']),
      expiresAt: DbMap.asDateTime(map['expires_at']),
      naverPlaceUrl: DbMap.asText(
        map['naver_place_url'] ?? shop?['naver_place_url'],
      ),
      isActive: DbMap.asBool(map['is_active'], true),
      paidAmount: paid,
      perSessionValue: per,
    );
  }
}
