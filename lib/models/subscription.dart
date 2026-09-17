import '../utils/db_map.dart';
import '../services/presence_helper.dart';

/// Discover / Following subscription target.
enum SubscriptionTargetType { shop, director }

/// User → shop | director follow row (063).
class Subscription {
  const Subscription({
    required this.id,
    required this.followerUserId,
    required this.targetType,
    this.targetShopId,
    this.targetUserId,
    this.source = 'discover',
    this.notifyLevel = 'all',
    this.createdAt,
  });

  final String id;
  final String followerUserId;
  final SubscriptionTargetType targetType;
  final String? targetShopId;
  final String? targetUserId;
  final String source;
  final String notifyLevel;
  final DateTime? createdAt;

  factory Subscription.fromMap(Map<String, dynamic> map) {
    final typeRaw = DbMap.asText(map['target_type'] ?? map['targetType']);
    return Subscription(
      id: DbMap.asText(map['id']),
      followerUserId: DbMap.asText(
        map['follower_user_id'] ?? map['followerUserId'],
      ),
      targetType: typeRaw == 'director'
          ? SubscriptionTargetType.director
          : SubscriptionTargetType.shop,
      targetShopId: DbMap.asTextOrNull(
        map['target_shop_id'] ?? map['targetShopId'],
      ),
      targetUserId: DbMap.asTextOrNull(
        map['target_user_id'] ?? map['targetUserId'],
      ),
      source: DbMap.asText(map['source'], 'discover'),
      notifyLevel: DbMap.asText(
        map['notify_level'] ?? map['notifyLevel'],
        'all',
      ),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

/// Discover directory row (person + shop affiliation).
class DiscoverDirector {
  const DiscoverDirector({
    required this.shopId,
    required this.shopName,
    required this.nickname,
    this.ownerUserId,
    this.ownerName = '',
    this.avatarUrl = '',
    this.bio = '',
    this.address = '',
    this.followerCount = 0,
    this.sharedCaseCount = 0,
    this.isOfficial = false,
    this.slug = '',
    this.isSeed = false,
    this.lastSeenAt,
  });

  final String shopId;
  final String shopName;
  final String nickname;
  final String? ownerUserId;
  final String ownerName;
  final String avatarUrl;
  final String bio;
  final String address;
  final int followerCount;
  final int sharedCaseCount;
  final bool isOfficial;
  final String slug;
  final bool isSeed;
  final DateTime? lastSeenAt;

  bool get isOnline => PresenceHelper.isOnline(lastSeenAt);

  String get line2 {
    final parts = <String>[
      if (shopName.trim().isNotEmpty) shopName.trim(),
      if (address.trim().isNotEmpty) address.trim(),
    ];
    return parts.join(' · ');
  }

  factory DiscoverDirector.fromMap(Map<String, dynamic> map) {
    return DiscoverDirector(
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId'] ?? map['id']),
      shopName: DbMap.asText(map['shop_name'] ?? map['shopName'] ?? map['name']),
      nickname: DbMap.asText(
        map['nickname'] ?? map['owner_name'] ?? map['ownerName'],
        '원장',
      ),
      ownerUserId: DbMap.asTextOrNull(
        map['owner_user_id'] ?? map['ownerUserId'],
      ),
      ownerName: DbMap.asText(map['owner_name'] ?? map['ownerName']),
      avatarUrl: DbMap.asText(
        map['avatar_url'] ?? map['avatarUrl'] ?? map['profile_image_url'],
      ),
      bio: DbMap.asText(map['bio']),
      address: DbMap.asText(map['address']),
      followerCount: DbMap.asInt(
        map['follower_count'] ?? map['followerCount'],
      ),
      sharedCaseCount: DbMap.asInt(
        map['shared_case_count'] ?? map['sharedCaseCount'],
      ),
      isOfficial: DbMap.asBool(map['is_official'] ?? map['isOfficial']),
      slug: DbMap.asText(map['slug']),
      isSeed: DbMap.asBool(map['is_seed'] ?? map['isSeed']),
      lastSeenAt: DbMap.asDateTime(map['last_seen_at'] ?? map['lastSeenAt']),
    );
  }
}
