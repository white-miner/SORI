import '../utils/db_map.dart';

/// Fan-Boost 기여자 1명 (차트/게시물 단위 집계).
class FanSupporterEntry {
  const FanSupporterEntry({
    required this.name,
    required this.echoSpent,
    this.customerId,
    this.walletId,
    this.avatarUrl,
    this.boostCount = 1,
  });

  final String name;
  final int echoSpent;
  final String? customerId;
  final String? walletId;
  final String? avatarUrl;
  final int boostCount;

  String get initial {
    final n = name.trim();
    if (n.isEmpty) return '?';
    return String.fromCharCode(n.runes.first).toUpperCase();
  }

  factory FanSupporterEntry.fromMap(Map<String, dynamic> map) {
    return FanSupporterEntry(
      name: DbMap.asText(
        map['fan_display_name'] ??
            map['fanDisplayName'] ??
            map['display_name'] ??
            map['name'],
        '후원자',
      ),
      echoSpent: DbMap.asInt(
        map['echo_spent'] ?? map['echoSpent'] ?? map['points_spent'],
      ),
      customerId: DbMap.asTextOrNull(
        map['paid_by_customer_id'] ??
            map['customerId'] ??
            map['supporter_customer_id'],
      ),
      walletId: DbMap.asTextOrNull(
        map['paid_by_wallet_id'] ?? map['walletId'],
      ),
      avatarUrl: DbMap.asTextOrNull(
        map['avatar_url'] ?? map['avatarUrl'] ?? map['profile_image_url'],
      ),
      boostCount: DbMap.asInt(map['boost_count'] ?? map['boostCount'], 1),
    );
  }

  Map<String, dynamic> toMap() => {
        'fan_display_name': name,
        'echo_spent': echoSpent,
        'paid_by_customer_id': customerId,
        'paid_by_wallet_id': walletId,
        'avatar_url': avatarUrl,
        'boost_count': boostCount,
      };

  /// Echo DESC 정렬 후 Top N + overflow 계산용.
  static List<FanSupporterEntry> ranked(Iterable<FanSupporterEntry> raw) {
    final list = raw
        .where((e) => e.name.trim().isNotEmpty || e.echoSpent > 0)
        .toList()
      ..sort((a, b) {
        final c = b.echoSpent.compareTo(a.echoSpent);
        if (c != 0) return c;
        return a.name.compareTo(b.name);
      });
    return list;
  }
}
