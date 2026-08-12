import '../utils/db_map.dart';
import 'shop_service_item.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.naverPlaceUrl,
    this.ownerName,
    this.phone,
    this.address,
    this.operatingHours = '',
    this.snsBlogUrl = '',
    this.snsInstagramUrl = '',
    this.serviceMenu = const [],
    this.kakaoPoint = 0,
    this.isPro = false,
  });

  final String id;
  final String name;
  final String naverPlaceUrl;
  final String? ownerName;
  final String? phone;
  final String? address;

  /// 휴무일 및 운영시간 안내.
  final String operatingHours;

  /// SNS — 블로그 / 인스타그램.
  final String snsBlogUrl;
  final String snsInstagramUrl;

  /// 샵에서 제공하는 서비스 메뉴 (이름 + 고객 안내 설명).
  final List<ShopServiceItem> serviceMenu;

  /// 잔여 카카오 알림톡 포인트.
  final int kakaoPoint;

  /// 프로 플랜 여부.
  final bool isPro;

  /// 차트·회원권 드롭다운용 서비스명 목록.
  List<String> get serviceNames => serviceMenu
      .map((e) => e.name.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  bool get hasNaverPlace => naverPlaceUrl.trim().isNotEmpty;

  /// 네이버 플레이스 리뷰 작성에 가까운 URL로 정규화.
  String get naverReviewDeepLink {
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
    String? ownerName,
    String? phone,
    String? address,
    String? operatingHours,
    String? snsBlogUrl,
    String? snsInstagramUrl,
    List<ShopServiceItem>? serviceMenu,
    int? kakaoPoint,
    bool? isPro,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      operatingHours: operatingHours ?? this.operatingHours,
      snsBlogUrl: snsBlogUrl ?? this.snsBlogUrl,
      snsInstagramUrl: snsInstagramUrl ?? this.snsInstagramUrl,
      serviceMenu: serviceMenu ?? this.serviceMenu,
      kakaoPoint: kakaoPoint ?? this.kakaoPoint,
      isPro: isPro ?? this.isPro,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'naver_place_url': naverPlaceUrl,
        'address': address,
        'operating_hours': operatingHours,
        'sns_blog_url': snsBlogUrl,
        'sns_instagram_url': snsInstagramUrl,
        'service_menu': serviceMenu.map((e) => e.toMap()).toList(),
        'kakao_point': kakaoPoint,
        'is_pro': isPro,
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

      // null/누락·별칭(sns_insta_url) 모두 ''로 흡수
      final operatingHours = DbMap.asText(
        map['operating_hours'] ?? map['operatingHours'],
      );
      final snsBlogUrl = DbMap.asText(
        map['sns_blog_url'] ?? map['snsBlogUrl'],
      );
      final snsInstagramUrl = DbMap.asText(
        map['sns_instagram_url'] ??
            map['sns_insta_url'] ??
            map['snsInstagramUrl'] ??
            map['snsInstaUrl'],
      );

      return Shop(
        id: DbMap.asText(map['id']),
        name: DbMap.asText(map['name'], 'SORI 샵'),
        ownerName: DbMap.asTextOrNull(map['owner_name']),
        phone: DbMap.asTextOrNull(map['phone']),
        naverPlaceUrl: DbMap.asText(map['naver_place_url']),
        address: DbMap.asTextOrNull(map['address']),
        operatingHours: operatingHours,
        snsBlogUrl: snsBlogUrl,
        snsInstagramUrl: snsInstagramUrl,
        serviceMenu: menu,
        kakaoPoint: (map.containsKey('kakao_point') ||
                map.containsKey('kakaoPoint'))
            ? DbMap.asInt(map['kakao_point'] ?? map['kakaoPoint'])
            : 1000,
        isPro: DbMap.asBool(map['is_pro'] ?? map['isPro']),
      );
    } catch (_) {
      return Shop(
        id: DbMap.asText(map['id']),
        name: DbMap.asText(map['name'], 'SORI 샵'),
        ownerName: DbMap.asTextOrNull(map['owner_name']),
        phone: DbMap.asTextOrNull(map['phone']),
        naverPlaceUrl: DbMap.asText(map['naver_place_url']),
        address: DbMap.asTextOrNull(map['address']),
        kakaoPoint: (map.containsKey('kakao_point') ||
                map.containsKey('kakaoPoint'))
            ? DbMap.asInt(map['kakao_point'] ?? map['kakaoPoint'])
            : 1000,
        isPro: DbMap.asBool(map['is_pro'] ?? map['isPro']),
      );
    }
  }
}
