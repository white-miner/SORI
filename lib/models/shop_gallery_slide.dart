enum GalleryKind { shop, before, after }

class ShopGallerySlide {
  const ShopGallerySlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.assetLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final GalleryKind kind;
  final String? assetLabel;

  ShopGallerySlide copyWith({
    String? title,
    String? subtitle,
    String? assetLabel,
  }) {
    return ShopGallerySlide(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      kind: kind,
      assetLabel: assetLabel ?? this.assetLabel,
    );
  }
}
