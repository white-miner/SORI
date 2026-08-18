/// SORI 10단계 통합 티어 — 소셜(1~6) + 비즈니스(7~10).
enum ShopTierBadge {
  none,
  iron,
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  mentor,
  master,
  grandMaster,
  grandDirector;

  String get dbValue => switch (this) {
        ShopTierBadge.none => 'none',
        ShopTierBadge.iron => 'iron',
        ShopTierBadge.bronze => 'bronze',
        ShopTierBadge.silver => 'silver',
        ShopTierBadge.gold => 'gold',
        ShopTierBadge.platinum => 'platinum',
        ShopTierBadge.diamond => 'diamond',
        ShopTierBadge.mentor => 'mentor',
        ShopTierBadge.master => 'master',
        ShopTierBadge.grandMaster => 'grand_master',
        ShopTierBadge.grandDirector => 'grand_director',
      };

  String get label => switch (this) {
        ShopTierBadge.none => '',
        ShopTierBadge.iron => '아이언',
        ShopTierBadge.bronze => '브론즈',
        ShopTierBadge.silver => '실버',
        ShopTierBadge.gold => '골드',
        ShopTierBadge.platinum => '플래티넘',
        ShopTierBadge.diamond => '다이아몬드',
        ShopTierBadge.mentor => '멘토',
        ShopTierBadge.master => '마스터',
        ShopTierBadge.grandMaster => '그랜드 마스터',
        ShopTierBadge.grandDirector => '그랜드 디렉터',
      };

  String get emoji => switch (this) {
        ShopTierBadge.none => '',
        ShopTierBadge.iron => '⬛',
        ShopTierBadge.bronze => '🥉',
        ShopTierBadge.silver => '🥈',
        ShopTierBadge.gold => '🥇',
        ShopTierBadge.platinum => '💠',
        ShopTierBadge.diamond => '💎',
        ShopTierBadge.mentor => '🎓',
        ShopTierBadge.master => '👑',
        ShopTierBadge.grandMaster => '🏛️',
        ShopTierBadge.grandDirector => '🌈',
      };

  bool get isSocialTrack => rank >= 1 && rank <= 6;
  bool get isBusinessTrack => rank >= 7;

  /// 0 = none … 10 = grand_director
  int get rank => switch (this) {
        ShopTierBadge.none => 0,
        ShopTierBadge.iron => 1,
        ShopTierBadge.bronze => 2,
        ShopTierBadge.silver => 3,
        ShopTierBadge.gold => 4,
        ShopTierBadge.platinum => 5,
        ShopTierBadge.diamond => 6,
        ShopTierBadge.mentor => 7,
        ShopTierBadge.master => 8,
        ShopTierBadge.grandMaster => 9,
        ShopTierBadge.grandDirector => 10,
      };

  ShopTierBadge get nextSocial => switch (this) {
        ShopTierBadge.none || ShopTierBadge.iron => ShopTierBadge.bronze,
        ShopTierBadge.bronze => ShopTierBadge.silver,
        ShopTierBadge.silver => ShopTierBadge.gold,
        ShopTierBadge.gold => ShopTierBadge.platinum,
        ShopTierBadge.platinum => ShopTierBadge.diamond,
        _ => ShopTierBadge.diamond,
      };

  ShopTierBadge get nextBusiness => switch (this) {
        ShopTierBadge.mentor => ShopTierBadge.master,
        ShopTierBadge.master => ShopTierBadge.grandMaster,
        ShopTierBadge.grandMaster ||
        ShopTierBadge.grandDirector =>
          ShopTierBadge.grandDirector,
        _ => ShopTierBadge.mentor,
      };

  static ShopTierBadge fromDb(String? raw) {
    final v = (raw ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return switch (v) {
      'iron' => ShopTierBadge.iron,
      'bronze' => ShopTierBadge.bronze,
      'silver' => ShopTierBadge.silver,
      'gold' => ShopTierBadge.gold,
      'platinum' => ShopTierBadge.platinum,
      'diamond' => ShopTierBadge.diamond,
      'mentor' => ShopTierBadge.mentor,
      'master' => ShopTierBadge.master,
      'grand_master' || 'grandmaster' => ShopTierBadge.grandMaster,
      'grand_director' || 'granddirector' => ShopTierBadge.grandDirector,
      _ => ShopTierBadge.none,
    };
  }

  bool get isVisible => this != ShopTierBadge.none;

  /// 에스크로 플랫폼 수수료율.
  double get platformFeePct => switch (this) {
        ShopTierBadge.grandDirector => 0.080,
        ShopTierBadge.grandMaster => 0.100,
        ShopTierBadge.master => 0.110,
        ShopTierBadge.mentor => 0.120,
        ShopTierBadge.diamond => 0.135,
        ShopTierBadge.platinum => 0.140,
        ShopTierBadge.gold => 0.145,
        ShopTierBadge.silver ||
        ShopTierBadge.bronze ||
        ShopTierBadge.iron ||
        ShopTierBadge.none =>
          0.150,
      };
}

class ShopTierThreshold {
  const ShopTierThreshold({
    required this.badge,
    this.shared = 0,
    this.likes = 0,
    this.followers = 0,
    this.requests = 0,
    this.seminars = 0,
    this.funding = 0,
  });

  final ShopTierBadge badge;
  final int shared;
  final int likes;
  final int followers;
  final int requests;
  final int seminars;
  final int funding;

  static const social = <ShopTierThreshold>[
    ShopTierThreshold(
      badge: ShopTierBadge.iron,
      shared: 3,
      likes: 15,
      followers: 5,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.bronze,
      shared: 10,
      likes: 60,
      followers: 25,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.silver,
      shared: 25,
      likes: 150,
      followers: 60,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.gold,
      shared: 45,
      likes: 350,
      followers: 120,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.platinum,
      shared: 70,
      likes: 700,
      followers: 250,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.diamond,
      shared: 100,
      likes: 1200,
      followers: 500,
    ),
  ];

  static const business = <ShopTierThreshold>[
    ShopTierThreshold(
      badge: ShopTierBadge.mentor,
      requests: 10,
      seminars: 1,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.master,
      requests: 50,
      seminars: 10,
      funding: 5000000,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.grandMaster,
      requests: 200,
      seminars: 50,
      funding: 20000000,
    ),
    ShopTierThreshold(
      badge: ShopTierBadge.grandDirector,
      requests: 1000,
      seminars: 100,
      funding: 100000000,
    ),
  ];
}

/// 마이페이지 승급 프로그레스용 스냅샷.
class ShopTierProgressSnapshot {
  const ShopTierProgressSnapshot({
    required this.current,
    required this.shared,
    required this.likes,
    required this.followers,
    required this.requests,
    required this.seminars,
    required this.funding,
    this.nextSocial,
    this.nextBusiness,
    this.socialRemain = const [],
    this.businessRemain = const [],
    this.socialRatio = 0,
    this.businessRatio = 0,
  });

  final ShopTierBadge current;
  final int shared;
  final int likes;
  final int followers;
  final int requests;
  final int seminars;
  final int funding;
  final ShopTierBadge? nextSocial;
  final ShopTierBadge? nextBusiness;
  final List<String> socialRemain;
  final List<String> businessRemain;
  final double socialRatio;
  final double businessRatio;

  factory ShopTierProgressSnapshot.fromMetrics({
    required ShopTierBadge current,
    required int shared,
    required int likes,
    required int followers,
    required int requests,
    required int seminars,
    required int funding,
  }) {
    ShopTierThreshold? nextSocialTh;
    for (final t in ShopTierThreshold.social) {
      if (!_meetsSocial(t, shared, likes, followers)) {
        nextSocialTh = t;
        break;
      }
    }

    ShopTierThreshold? nextBizTh;
    for (final t in ShopTierThreshold.business) {
      if (!_meetsBusiness(t, requests, seminars, funding)) {
        nextBizTh = t;
        break;
      }
    }

    return ShopTierProgressSnapshot(
      current: current,
      shared: shared,
      likes: likes,
      followers: followers,
      requests: requests,
      seminars: seminars,
      funding: funding,
      nextSocial: nextSocialTh?.badge,
      nextBusiness: nextBizTh?.badge,
      socialRemain: nextSocialTh == null
          ? const []
          : _remainSocial(nextSocialTh, shared, likes, followers),
      businessRemain: nextBizTh == null
          ? const []
          : _remainBusiness(nextBizTh, requests, seminars, funding),
      socialRatio: nextSocialTh == null
          ? 1
          : _ratio3(
              shared / nextSocialTh.shared,
              likes / nextSocialTh.likes,
              followers / nextSocialTh.followers,
            ),
      businessRatio: nextBizTh == null
          ? 1
          : _ratioBusiness(nextBizTh, requests, seminars, funding),
    );
  }

  static bool _meetsSocial(
    ShopTierThreshold t,
    int shared,
    int likes,
    int followers,
  ) {
    return shared >= t.shared && likes >= t.likes && followers >= t.followers;
  }

  static bool _meetsBusiness(
    ShopTierThreshold t,
    int requests,
    int seminars,
    int funding,
  ) {
    if (requests < t.requests || seminars < t.seminars) return false;
    if (t.funding <= 0) return true;
    return funding >= t.funding;
  }

  static List<String> _remainSocial(
    ShopTierThreshold t,
    int shared,
    int likes,
    int followers,
  ) {
    final out = <String>[];
    final ds = t.shared - shared;
    final dl = t.likes - likes;
    final df = t.followers - followers;
    if (ds > 0) out.add('공유 차트 ${ds}개');
    if (dl > 0) out.add('좋아요 ${dl}개');
    if (df > 0) out.add('팔로워 ${df}명');
    return out;
  }

  static List<String> _remainBusiness(
    ShopTierThreshold t,
    int requests,
    int seminars,
    int funding,
  ) {
    final out = <String>[];
    final dr = t.requests - requests;
    final ds = t.seminars - seminars;
    final df = t.funding - funding;
    if (dr > 0) out.add('세미나 요청 ${dr}건');
    if (ds > 0) out.add('세미나 개최 ${ds}회');
    if (t.funding > 0 && df > 0) {
      out.add('펀딩 ${_formatWon(df)}');
    }
    return out;
  }

  static double _ratio3(double a, double b, double c) {
    final v = ((a.clamp(0, 1) + b.clamp(0, 1) + c.clamp(0, 1)) / 3);
    return v.clamp(0.04, 1);
  }

  static double _ratioBusiness(
    ShopTierThreshold t,
    int requests,
    int seminars,
    int funding,
  ) {
    final r = (requests / t.requests).clamp(0, 1);
    final s = (seminars / t.seminars).clamp(0, 1);
    final f = t.funding <= 0 ? 1.0 : (funding / t.funding).clamp(0, 1);
    return ((r + s + f) / 3).clamp(0.04, 1);
  }

  static String _formatWon(int amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(1)}억 원';
    }
    if (amount >= 10000) {
      return '${(amount / 10000).round()}만 원';
    }
    return '$amount원';
  }

  String get socialHint {
    if (nextSocial == null) return '소셜 트랙 최고 등급입니다';
    if (socialRemain.isEmpty) return '다음 ${nextSocial!.label} 조건 충족';
    return '다음 ${nextSocial!.label} 승급까지 ${socialRemain.join(', ')} 필요';
  }

  String get businessHint {
    if (nextBusiness == null) {
      return '그랜드 디렉터 유지: 최근 12개월 펀딩 1억 원 (매월 1일 점검)';
    }
    if (businessRemain.isEmpty) return '다음 ${nextBusiness!.label} 조건 충족';
    return '다음 ${nextBusiness!.label} 승급까지 ${businessRemain.join(', ')} 필요';
  }
}
