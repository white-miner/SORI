enum GalleryKind { shop, before, after }

/// 샵 홈 갤러리 슬라이드 (Storage URL 기반).
class ShopGallerySlide {
  const ShopGallerySlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.assetLabel,
    this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final GalleryKind kind;
  final String? assetLabel;
  final String? imageUrl;
  final int sortOrder;

  bool get hasNetworkImage {
    final u = imageUrl?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  ShopGallerySlide copyWith({
    String? title,
    String? subtitle,
    String? assetLabel,
    String? imageUrl,
    int? sortOrder,
  }) {
    return ShopGallerySlide(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      kind: kind,
      assetLabel: assetLabel ?? this.assetLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory ShopGallerySlide.fromMap(Map<String, dynamic> map) {
    final url = (map['image_url'] ?? map['imageUrl'] ?? '').toString().trim();
    final title = (map['title'] ?? '').toString().trim();
    final order = map['sort_order'] ?? map['sortOrder'] ?? 0;
    return ShopGallerySlide(
      id: (map['id'] ?? '').toString(),
      title: title.isEmpty ? '갤러리' : title,
      subtitle: '',
      kind: GalleryKind.shop,
      imageUrl: url.isEmpty ? null : url,
      sortOrder: order is int ? order : int.tryParse('$order') ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap({required String shopId}) => {
        'shop_id': shopId,
        'image_url': imageUrl ?? '',
        'title': title,
        'sort_order': sortOrder,
      };
}
