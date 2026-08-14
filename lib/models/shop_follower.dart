import '../utils/db_map.dart';

/// 고객→샵 단골 팬(팔로우) 관계.
class ShopFollower {
  const ShopFollower({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final DateTime? createdAt;

  factory ShopFollower.fromMap(Map<String, dynamic> map) {
    return ShopFollower(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id']),
      customerId: DbMap.asText(map['customer_id']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
