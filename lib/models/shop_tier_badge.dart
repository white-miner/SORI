/// 샵 누적 공유 케이스 기반 B2B 티어 뱃지.
enum ShopTierBadge {
  none,
  bronze,
  silver,
  gold,
  master;

  String get dbValue => switch (this) {
        ShopTierBadge.none => 'none',
        ShopTierBadge.bronze => 'Bronze',
        ShopTierBadge.silver => 'Silver',
        ShopTierBadge.gold => 'Gold',
        ShopTierBadge.master => 'Master',
      };

  String get label => switch (this) {
        ShopTierBadge.none => '',
        ShopTierBadge.bronze => 'Bronze',
        ShopTierBadge.silver => 'Silver',
        ShopTierBadge.gold => 'Gold',
        ShopTierBadge.master => 'Master',
      };

  String get emoji => switch (this) {
        ShopTierBadge.none => '',
        ShopTierBadge.bronze => '🥉',
        ShopTierBadge.silver => '🥈',
        ShopTierBadge.gold => '🥇',
        ShopTierBadge.master => '👑',
      };

  static ShopTierBadge fromDb(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return switch (v) {
      'bronze' => ShopTierBadge.bronze,
      'silver' => ShopTierBadge.silver,
      'gold' => ShopTierBadge.gold,
      'master' => ShopTierBadge.master,
      _ => ShopTierBadge.none,
    };
  }

  bool get isVisible => this != ShopTierBadge.none;
}
