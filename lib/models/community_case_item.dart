import 'customer_chart.dart';
import 'customer_review.dart';
import 'fan_supporter.dart';
import 'shop.dart';
import '../utils/case_persona.dart';

/// 전국/단골 B/A 커뮤니티 피드 항목.
class CommunityCaseItem {
  const CommunityCaseItem({
    required this.chart,
    required this.shop,
    this.review,
    this.careTags = const [],
    this.customerAge,
    this.customerGenderLabel,
    this.isBoosted = false,
    this.boostEndsAt,
    this.boostSource = 'shop_ad',
    this.fanDisplayName = '',
    this.fanSupporters = const [],
    this.authorNickname = '',
    this.authorAvatarUrl = '',
  });

  final CustomerChart chart;
  final Shop shop;
  final CustomerReview? review;

  /// 피드 해시태그 (care_tags / concern_chips).
  final List<String> careTags;

  /// 공개 피드용 익명 나이 (생년월일 미노출).
  final int? customerAge;

  /// 공개 피드용 성별 라벨 (`여성` / `남성`).
  final String? customerGenderLabel;

  /// 우리 지역 탭 핀 — 활성 부스터.
  final bool isBoosted;
  final DateTime? boostEndsAt;

  /// shop_ad | fan_boost
  final String boostSource;
  final String fanDisplayName;

  /// Fan-Boost 기여자 랭킹 (Echo DESC). Facepile / 시트용.
  final List<FanSupporterEntry> fanSupporters;

  /// Weverse Line1 — personal nickname (061).
  final String authorNickname;

  /// Author avatar URL (profiles.avatar_url).
  final String authorAvatarUrl;

  bool get isFanBoosted => isBoosted && boostSource == 'fan_boost';

  /// Line1 display — nickname → owner → shop.
  String get displayAuthorNickname {
    final n = authorNickname.trim();
    if (n.isNotEmpty) return n;
    final owner = shop.ownerName?.trim() ?? '';
    if (owner.isNotEmpty) return owner;
    final shopName = shop.name.trim();
    return shopName.isEmpty ? 'SORI' : shopName;
  }

  /// Avatar — author first, then shop.
  String get displayAuthorAvatarUrl {
    final a = authorAvatarUrl.trim();
    if (a.isNotEmpty) return a;
    return shop.profileImageUrl?.trim() ?? '';
  }

  /// Line2 affiliation shop name (always shown — plan A).
  String get displayShopAffiliation {
    final n = shop.name.trim();
    return n.isEmpty ? 'SORI' : n;
  }

  List<FanSupporterEntry> get effectiveFanSupporters {
    if (fanSupporters.isNotEmpty) {
      return FanSupporterEntry.ranked(fanSupporters);
    }
    final n = fanDisplayName.trim();
    if (n.isEmpty) return const [];
    return [FanSupporterEntry(name: n, echoSpent: 0)];
  }

  bool get hasVerifiedReview =>
      review != null && review!.displayText.trim().isNotEmpty;

  List<String> get displayCareTags {
    if (careTags.isNotEmpty) return careTags;
    return chart.careTags;
  }

  /// 본문 요약 — 보관함과 동일한 페르소나 한 줄.
  String get personaLine => CasePersona.feedLine(
        chart: chart,
        age: customerAge ?? chart.age,
        genderLabel: customerGenderLabel ?? chart.gender,
      );

  /// 작성자 auth id — 차트 필드 우선, 없으면 샵 원장.
  String? get authorId {
    final fromChart = chart.authorId?.trim() ?? '';
    if (fromChart.isNotEmpty) return fromChart;
    final fromShop = shop.ownerUserId?.trim() ?? '';
    return fromShop.isEmpty ? null : fromShop;
  }

  /// 현재 로그인 유저가 이 차트 작성자인지 (둘 다 비어 있으면 false).
  bool isAuthoredBy(String? currentUserId) {
    final uid = currentUserId?.trim() ?? '';
    final aid = authorId ?? '';
    return uid.isNotEmpty && aid.isNotEmpty && uid == aid;
  }

  CommunityCaseItem copyWith({
    bool? isBoosted,
    DateTime? boostEndsAt,
    String? boostSource,
    String? fanDisplayName,
    List<FanSupporterEntry>? fanSupporters,
    CustomerReview? review,
    String? authorNickname,
    String? authorAvatarUrl,
  }) {
    return CommunityCaseItem(
      chart: chart,
      shop: shop,
      review: review ?? this.review,
      careTags: careTags,
      customerAge: customerAge,
      customerGenderLabel: customerGenderLabel,
      isBoosted: isBoosted ?? this.isBoosted,
      boostEndsAt: boostEndsAt ?? this.boostEndsAt,
      boostSource: boostSource ?? this.boostSource,
      fanDisplayName: fanDisplayName ?? this.fanDisplayName,
      fanSupporters: fanSupporters ?? this.fanSupporters,
      authorNickname: authorNickname ?? this.authorNickname,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
