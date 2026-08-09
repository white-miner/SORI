import '../utils/db_map.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.naverPlaceUrl,
    this.ownerName,
    this.phone,
    this.address,
    this.serviceMenu = const [],
  });

  final String id;
  final String name;
  final String naverPlaceUrl;
  final String? ownerName;
  final String? phone;
  final String? address;

  /// 샵에서 제공하는 서비스명 목록 (드롭다운 소스).
  final List<String> serviceMenu;

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
    List<String>? serviceMenu,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      serviceMenu: serviceMenu ?? this.serviceMenu,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'naver_place_url': naverPlaceUrl,
        'address': address,
        'service_menu': serviceMenu,
      };

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: DbMap.asText(map['id']),
      name: DbMap.asText(map['name'], 'SORI 샵'),
      ownerName: DbMap.asTextOrNull(map['owner_name']),
      phone: DbMap.asTextOrNull(map['phone']),
      naverPlaceUrl: DbMap.asText(map['naver_place_url']),
      address: DbMap.asTextOrNull(map['address']),
      serviceMenu: DbMap.asStringList(map['service_menu'])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
