class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.naverPlaceUrl,
    this.ownerName,
    this.phone,
    this.address,
  });

  final String id;
  final String name;
  final String naverPlaceUrl;
  final String? ownerName;
  final String? phone;
  final String? address;

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
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'naver_place_url': naverPlaceUrl,
        'address': address,
      };

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerName: map['owner_name'] as String?,
      phone: map['phone'] as String?,
      naverPlaceUrl: map['naver_place_url'] as String? ?? '',
      address: map['address'] as String?,
    );
  }
}
