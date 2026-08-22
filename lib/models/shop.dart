import '../utils/db_map.dart';
import 'shop_business_hours.dart';
import 'shop_equipment_item.dart';
import 'shop_service_item.dart';
import 'shop_tier_badge.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.naverPlaceUrl,
    this.naverBookingUrl = '',
    this.naverReviewWriteUrl = '',
    this.ownerName,
    this.phone,
    this.address,
    this.operatingHours = '',
    this.businessHours = const ShopBusinessHours(openDays: {}),
    this.snsBlogUrl = '',
    this.snsInstagramUrl = '',
    this.bio = '',
    this.profileImageUrl,
    this.coverImageUrl,
    this.serviceMenu = const [],
    this.equipmentItems = const [],
    this.kakaoPoint = 0,
    this.isPro = false,
    this.monthlyCapa = 100,
    this.tierBadge = ShopTierBadge.none,
    this.soriCashBalance = 0,
    this.totalSeminarCount = 0,
    this.totalFundingAmount = 0,
    this.totalLikes = 0,
    this.sharedCaseCount = 0,
    this.seminarRequestCount = 0,
    this.completedSeminarCount = 0,
    this.followerCount = 0,
    this.ownerUserId,
  });

  final String id;
  final String name;
  final String naverPlaceUrl;

  /// 네이버 예약 직행 URL (피드 CTA). 비어 있으면 [naverPlaceUrl] Fallback.
  final String naverBookingUrl;

  /// 네이버 플레이스 리뷰 작성 직행 URL (계산대 1분 컷 CTA).
  final String naverReviewWriteUrl;
  final String? ownerName;
  final String? phone;
  final String? address;

  /// 휴무일 및 운영시간 안내 (표시용 문자열, [businessHours]와 동기화).
  final String operatingHours;

  /// 구조화 영업시간 (요일 + 오픈/마감).
  final ShopBusinessHours businessHours;

  /// SNS — 블로그 / 인스타그램.
  final String snsBlogUrl;
  final String snsInstagramUrl;

  /// 샵 소개말(Bio).
  final String bio;

  /// 원장 프로필 아바타 public URL.
  final String? profileImageUrl;

  /// 마이페이지 Hero 간판 public URL.
  final String? coverImageUrl;

  /// 샵에서 제공하는 서비스 메뉴 (이름 + 고객 안내 설명).
  final List<ShopServiceItem> serviceMenu;

  /// 사용 기기/제품 카드 (이미지 선택).
  final List<ShopEquipmentItem> equipmentItems;

  /// 잔여 카카오 알림톡 포인트.
  final int kakaoPoint;

  /// 프로 플랜 여부.
  final bool isPro;

  /// 월간 소화 CAPA(회). Hell-Zone = 잔여 총합 > CAPA * 1.2.
  final int monthlyCapa;

  /// 누적 공유 케이스 기반 B2B 티어.
  final ShopTierBadge tierBadge;

  /// 세미나 정산 SORI Cash 잔액 (원).
  final int soriCashBalance;

  /// 완료된 누적 세미나 클래스 수.
  final int totalSeminarCount;

  /// 완료 클래스 기준 누적 펀딩 금액 (원).
  final int totalFundingAmount;

  final int totalLikes;
  final int sharedCaseCount;
  final int seminarRequestCount;
  final int completedSeminarCount;
  final int followerCount;

  /// 샵 원장 auth user id (`shops.owner_user_id`).
  final String? ownerUserId;

  /// 뷰어용 영업시간 문구 — JSON 우선, 없으면 legacy 텍스트.
  String get hoursDisplayLabel {
    if (!businessHours.isEmpty) return businessHours.formatDisplay();
    final legacy = operatingHours.trim();
    return legacy;
  }

  ShopTierProgressSnapshot get tierProgress =>
      ShopTierProgressSnapshot.fromMetrics(
        current: tierBadge,
        shared: sharedCaseCount,
        likes: totalLikes,
        followers: followerCount,
        requests: seminarRequestCount,
        seminars: completedSeminarCount > 0
            ? completedSeminarCount
            : totalSeminarCount,
        funding: totalFundingAmount,
      );

  /// 차트·회원권 드롭다운용 서비스명 목록.
  List<String> get serviceNames => serviceMenu
      .map((e) => e.name.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  /// 서비스명으로 등록된 사용 기기 (없으면 null).
  String? deviceInfoForMenu(String careName) {
    final key = careName.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final item in serviceMenu) {
      if (item.name.trim().toLowerCase() == key) {
        final d = item.deviceInfo?.trim() ?? '';
        return d.isEmpty ? null : d;
      }
    }
    return null;
  }

  bool get hasNaverPlace => naverPlaceUrl.trim().isNotEmpty;

  bool get hasNaverBookingUrl => naverBookingUrl.trim().isNotEmpty;

  /// 피드 「네이버 예약」 CTA — booking 우선, 없으면 place.
  String get naverBookingOrPlaceUrl {
    final booking = naverBookingUrl.trim();
    if (booking.isNotEmpty) return booking;
    return naverPlaceUrl.trim();
  }

  bool get hasNaverReviewWriteUrl => naverReviewWriteUrl.trim().isNotEmpty;

  bool get hasProfileImage =>
      profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;

  /// 리뷰 작성 직행 URL — 명시 필드 우선, 없으면 플레이스 URL 휴리스틱.
  String get naverReviewDeepLink {
    final write = naverReviewWriteUrl.trim();
    if (write.isNotEmpty) return write;
    final url = naverPlaceUrl.trim();
    if (url.isEmpty) return url;
    if (url.contains('review')) return url;
    if (url.endsWith('/')) return '${url}review';
    return '$url/review';
  }

  Shop copyWith({
    String? id,
    String? name,
    String? naverPlaceUrl,
    String? naverBookingUrl,
    String? naverReviewWriteUrl,
    String? ownerName,
    String? phone,
    String? address,
    String? operatingHours,
    ShopBusinessHours? businessHours,
    String? snsBlogUrl,
    String? snsInstagramUrl,
    String? bio,
    String? profileImageUrl,
    bool clearProfileImageUrl = false,
    String? coverImageUrl,
    bool clearCoverImageUrl = false,
    List<ShopServiceItem>? serviceMenu,
    List<ShopEquipmentItem>? equipmentItems,
    int? kakaoPoint,
    bool? isPro,
    int? monthlyCapa,
    ShopTierBadge? tierBadge,
    int? soriCashBalance,
    int? totalSeminarCount,
    int? totalFundingAmount,
    int? totalLikes,
    int? sharedCaseCount,
    int? seminarRequestCount,
    int? completedSeminarCount,
    int? followerCount,
    String? ownerUserId,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
      naverBookingUrl: naverBookingUrl ?? this.naverBookingUrl,
      naverReviewWriteUrl: naverReviewWriteUrl ?? this.naverReviewWriteUrl,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      operatingHours: operatingHours ?? this.operatingHours,
      businessHours: businessHours ?? this.businessHours,
      snsBlogUrl: snsBlogUrl ?? this.snsBlogUrl,
      snsInstagramUrl: snsInstagramUrl ?? this.snsInstagramUrl,
      bio: bio ?? this.bio,
      profileImageUrl: clearProfileImageUrl
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
      coverImageUrl: clearCoverImageUrl
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      serviceMenu: serviceMenu ?? this.serviceMenu,
      equipmentItems: equipmentItems ?? this.equipmentItems,
      kakaoPoint: kakaoPoint ?? this.kakaoPoint,
      isPro: isPro ?? this.isPro,
      monthlyCapa: monthlyCapa ?? this.monthlyCapa,
      tierBadge: tierBadge ?? this.tierBadge,
      soriCashBalance: soriCashBalance ?? this.soriCashBalance,
      totalSeminarCount: totalSeminarCount ?? this.totalSeminarCount,
      totalFundingAmount: totalFundingAmount ?? this.totalFundingAmount,
      totalLikes: totalLikes ?? this.totalLikes,
      sharedCaseCount: sharedCaseCount ?? this.sharedCaseCount,
      seminarRequestCount: seminarRequestCount ?? this.seminarRequestCount,
      completedSeminarCount:
          completedSeminarCount ?? this.completedSeminarCount,
      followerCount: followerCount ?? this.followerCount,
      ownerUserId: ownerUserId ?? this.ownerUserId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'naver_place_url': naverPlaceUrl,
        'naver_booking_url': naverBookingUrl,
        'naver_review_write_url': naverReviewWriteUrl,
        'address': address,
        'operating_hours': operatingHours,
        'business_hours': businessHours.isEmpty ? <String, dynamic>{} : businessHours.toJson(),
        'sns_blog_url': snsBlogUrl,
        'sns_instagram_url': snsInstagramUrl,
        'bio': bio,
        'profile_image_url': profileImageUrl,
        'cover_image_url': coverImageUrl,
        'service_menu': serviceMenu.map((e) => e.toMap()).toList(),
        'equipment_items': equipmentItems.map((e) => e.toMap()).toList(),
        'kakao_point': kakaoPoint,
        'is_pro': isPro,
        'monthly_capa': monthlyCapa,
        'tier_badge': tierBadge.dbValue,
        'sori_cash_balance': soriCashBalance,
        'total_seminar_count': totalSeminarCount,
        'total_funding_amount': totalFundingAmount,
        'total_likes': totalLikes,
        'shared_case_count': sharedCaseCount,
        'seminar_request_count': seminarRequestCount,
        'completed_seminar_count': completedSeminarCount,
        'follower_count': followerCount,
        'owner_user_id': ownerUserId,
      };

  factory Shop.fromMap(Map<String, dynamic> map) {
    try {
      final rawMenu = map['service_menu'];
      final menu = <ShopServiceItem>[];
      if (rawMenu is List) {
        for (final item in rawMenu) {
          try {
            final parsed = ShopServiceItem.fromDynamic(item);
            if (parsed.name.trim().isEmpty) continue;
            menu.add(parsed);
          } catch (_) {
            // 개별 메뉴 항목 파싱 실패는 건너뜀
          }
        }
      }

      final rawEquip = map['equipment_items'] ?? map['equipmentItems'];
      final equipment = <ShopEquipmentItem>[];
      if (rawEquip is List) {
        for (final item in rawEquip) {
          try {
            final parsed = ShopEquipmentItem.fromDynamic(item);
            if (parsed.name.trim().isEmpty) continue;
            equipment.add(parsed);
          } catch (_) {}
        }
      }

      final operatingHours = DbMap.asText(
        map['operating_hours'] ?? map['operatingHours'],
      );
      final businessHoursRaw =
          map['business_hours'] ?? map['businessHours'];
      final businessHours = businessHoursRaw == null ||
              (businessHoursRaw is Map && businessHoursRaw.isEmpty)
          ? const ShopBusinessHours(openDays: {})
          : ShopBusinessHours.fromJson(businessHoursRaw);
      final snsBlogUrl = DbMap.asText(
        map['sns_blog_url'] ?? map['snsBlogUrl'],
      );
      final snsInstagramUrl = DbMap.asText(
        map['sns_instagram_url'] ??
            map['sns_insta_url'] ??
            map['snsInstagramUrl'] ??
            map['snsInstaUrl'],
      );
      final bio = DbMap.asText(
        map['bio'] ?? map['description'] ?? map['shop_bio'],
      );
      final profileImageUrl = DbMap.asTextOrNull(
        map['profile_image_url'] ?? map['profileImageUrl'],
      );
      final coverImageUrl = DbMap.asTextOrNull(
        map['cover_image_url'] ?? map['coverImageUrl'],
      );
      final naverReviewWriteUrl = DbMap.asText(
        map['naver_review_write_url'] ?? map['naverReviewWriteUrl'],
      );
      final naverBookingUrl = DbMap.asText(
        map['naver_booking_url'] ??
            map['naverBookingUrl'] ??
            map['shop_naver_booking_url'],
      );

      return Shop(
        id: DbMap.asText(map['id']),
        name: DbMap.asText(map['name'], 'SORI 샵'),
        ownerName: DbMap.asTextOrNull(map['owner_name']),
        phone: DbMap.asTextOrNull(map['phone']),
        naverPlaceUrl: DbMap.asText(map['naver_place_url']),
        naverBookingUrl: naverBookingUrl,
        naverReviewWriteUrl: naverReviewWriteUrl,
        address: DbMap.asTextOrNull(map['address']),
        operatingHours: operatingHours,
        businessHours: businessHours,
        snsBlogUrl: snsBlogUrl,
        snsInstagramUrl: snsInstagramUrl,
        bio: bio,
        profileImageUrl: profileImageUrl,
        coverImageUrl: coverImageUrl,
        serviceMenu: menu,
        equipmentItems: equipment,
        kakaoPoint: (map.containsKey('kakao_point') ||
                map.containsKey('kakaoPoint'))
            ? DbMap.asInt(map['kakao_point'] ?? map['kakaoPoint'])
            : 1000,
        isPro: DbMap.asBool(map['is_pro'] ?? map['isPro']),
        monthlyCapa: DbMap.asInt(
          map['monthly_capa'] ?? map['monthlyCapa'],
          100,
        ),
        tierBadge: ShopTierBadge.fromDb(
          DbMap.asText(map['tier_badge'] ?? map['shop_tier_badge']),
        ),
        soriCashBalance: DbMap.asInt(
          map['sori_cash_balance'] ?? map['soriCashBalance'],
        ),
        totalSeminarCount: DbMap.asInt(
          map['total_seminar_count'] ?? map['totalSeminarCount'],
        ),
        totalFundingAmount: DbMap.asInt(
          map['total_funding_amount'] ?? map['totalFundingAmount'],
        ),
        totalLikes: DbMap.asInt(map['total_likes'] ?? map['totalLikes']),
        sharedCaseCount: DbMap.asInt(
          map['shared_case_count'] ?? map['sharedCaseCount'],
        ),
        seminarRequestCount: DbMap.asInt(
          map['seminar_request_count'] ?? map['seminarRequestCount'],
        ),
        completedSeminarCount: DbMap.asInt(
          map['completed_seminar_count'] ??
              map['completedSeminarCount'] ??
              map['total_seminar_count'],
        ),
        followerCount: DbMap.asInt(
          map['follower_count'] ?? map['followerCount'],
        ),
        ownerUserId: DbMap.asTextOrNull(
          map['owner_user_id'] ??
              map['shop_owner_user_id'] ??
              map['ownerUserId'],
        ),
      );
    } catch (_) {
      return Shop(
        id: DbMap.asText(map['id']),
        name: DbMap.asText(map['name'], 'SORI 샵'),
        ownerName: DbMap.asTextOrNull(map['owner_name']),
        phone: DbMap.asTextOrNull(map['phone']),
        naverPlaceUrl: DbMap.asText(map['naver_place_url']),
        naverBookingUrl: DbMap.asText(
          map['naver_booking_url'] ??
              map['naverBookingUrl'] ??
              map['shop_naver_booking_url'],
        ),
        naverReviewWriteUrl: DbMap.asText(
          map['naver_review_write_url'] ?? map['naverReviewWriteUrl'],
        ),
        address: DbMap.asTextOrNull(map['address']),
        bio: DbMap.asText(map['bio'] ?? map['description']),
        profileImageUrl: DbMap.asTextOrNull(map['profile_image_url']),
        coverImageUrl: DbMap.asTextOrNull(
          map['cover_image_url'] ?? map['coverImageUrl'],
        ),
        kakaoPoint: (map.containsKey('kakao_point') ||
                map.containsKey('kakaoPoint'))
            ? DbMap.asInt(map['kakao_point'] ?? map['kakaoPoint'])
            : 1000,
        isPro: DbMap.asBool(map['is_pro'] ?? map['isPro']),
        monthlyCapa: DbMap.asInt(
          map['monthly_capa'] ?? map['monthlyCapa'],
          100,
        ),
        tierBadge: ShopTierBadge.fromDb(
          DbMap.asText(map['tier_badge'] ?? map['shop_tier_badge']),
        ),
        soriCashBalance: DbMap.asInt(
          map['sori_cash_balance'] ?? map['soriCashBalance'],
        ),
        totalSeminarCount: DbMap.asInt(
          map['total_seminar_count'] ?? map['totalSeminarCount'],
        ),
        totalFundingAmount: DbMap.asInt(
          map['total_funding_amount'] ?? map['totalFundingAmount'],
        ),
        totalLikes: DbMap.asInt(map['total_likes'] ?? map['totalLikes']),
        sharedCaseCount: DbMap.asInt(
          map['shared_case_count'] ?? map['sharedCaseCount'],
        ),
        seminarRequestCount: DbMap.asInt(
          map['seminar_request_count'] ?? map['seminarRequestCount'],
        ),
        completedSeminarCount: DbMap.asInt(
          map['completed_seminar_count'] ??
              map['completedSeminarCount'] ??
              map['total_seminar_count'],
        ),
        followerCount: DbMap.asInt(
          map['follower_count'] ?? map['followerCount'],
        ),
        ownerUserId: DbMap.asTextOrNull(
          map['owner_user_id'] ??
              map['shop_owner_user_id'] ??
              map['ownerUserId'],
        ),
      );
    }
  }
}
