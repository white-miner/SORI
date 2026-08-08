class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.naverPlaceUrl,
    this.address,
  });

  final String id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? naverPlaceUrl;
  final String? address;

  Shop copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? phone,
    String? naverPlaceUrl,
    String? address,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      naverPlaceUrl: naverPlaceUrl ?? this.naverPlaceUrl,
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
      naverPlaceUrl: map['naver_place_url'] as String?,
      address: map['address'] as String?,
    );
  }
}
