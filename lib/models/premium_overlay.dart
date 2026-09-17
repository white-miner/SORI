import '../utils/db_map.dart';

/// VIP 스페셜 후원 오버레이 (기존 boost_placements 와 별도 스택).
class PremiumOverlay {
  const PremiumOverlay({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.chartId,
    this.beneficiaryShopId = '',
    this.tier = '',
    this.sku = '',
    this.fanCustomerId,
    this.fanDisplayName = '',
    this.echoSpent = 0,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String? chartId;
  final String beneficiaryShopId;
  final String tier;
  final String sku;
  final String? fanCustomerId;
  final String fanDisplayName;
  final int echoSpent;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isGold => tier == 'gold';
  bool get isPlatinum => tier == 'platinum';

  bool get isActive {
    final end = endsAt;
    if (end == null) return true;
    return end.isAfter(DateTime.now());
  }

  String? get pinKey {
    if (chartId != null && chartId!.trim().isNotEmpty) return chartId;
    if (targetType == 'chart') return targetId;
    return null;
  }

  factory PremiumOverlay.fromMap(Map<String, dynamic> map) {
    return PremiumOverlay(
      id: DbMap.asText(map['id']),
      targetType: DbMap.asText(map['target_type'] ?? map['targetType'], 'chart'),
      targetId: DbMap.asText(map['target_id'] ?? map['targetId']),
      chartId: DbMap.asTextOrNull(map['chart_id'] ?? map['chartId']),
      beneficiaryShopId: DbMap.asText(
        map['beneficiary_shop_id'] ?? map['beneficiaryShopId'],
      ),
      tier: DbMap.asText(map['tier']),
      sku: DbMap.asText(map['sku']),
      fanCustomerId: DbMap.asTextOrNull(
        map['fan_customer_id'] ?? map['fanCustomerId'],
      ),
      fanDisplayName: DbMap.asText(
        map['fan_display_name'] ?? map['fanDisplayName'],
      ),
      echoSpent: DbMap.asInt(map['echo_spent'] ?? map['echoSpent']),
      startsAt: DbMap.asDateTime(map['starts_at'] ?? map['startsAt']),
      endsAt: DbMap.asDateTime(map['ends_at'] ?? map['endsAt']),
    );
  }
}
