import '../utils/db_map.dart';
import 'fan_supporter.dart';

/// 마이페이지 간판 — 팔로워 + 후원자 Facepile (Echo DESC).
class ShopSupporterHeader {
  const ShopSupporterHeader({
    this.followerCount = 0,
    this.supporterCount = 0,
    this.facepile = const [],
    this.topSupporter,
  });

  final int followerCount;
  final int supporterCount;
  final List<FanSupporterEntry> facepile;
  final FanSupporterEntry? topSupporter;

  factory ShopSupporterHeader.fromMap(Map<String, dynamic> map) {
    final pileRaw = map['facepile'];
    final pile = <FanSupporterEntry>[];
    if (pileRaw is List) {
      for (final e in pileRaw) {
        if (e is Map) {
          pile.add(FanSupporterEntry.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    final topRaw = map['top_supporter'];
    FanSupporterEntry? top;
    if (topRaw is Map && topRaw.isNotEmpty) {
      top = FanSupporterEntry.fromMap(Map<String, dynamic>.from(topRaw));
    } else if (pile.isNotEmpty) {
      top = pile.first;
    }
    return ShopSupporterHeader(
      followerCount: DbMap.asInt(
        map['follower_count'] ?? map['followerCount'],
      ),
      supporterCount: DbMap.asInt(
        map['supporter_count'] ?? map['supporterCount'],
      ),
      facepile: FanSupporterEntry.ranked(pile),
      topSupporter: top,
    );
  }

  String get metricsLine {
    final parts = <String>[];
    if (followerCount > 0) parts.add('팔로워 +$followerCount명');
    if (supporterCount > 0) parts.add('후원자 $supporterCount명');
    if (parts.isEmpty) return '팔로워와 후원자를 모아보세요';
    return parts.join(' · ');
  }
}
