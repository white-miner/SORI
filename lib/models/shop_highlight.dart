import '../utils/db_map.dart';

/// 샵 스토리 하이라이트 (Instagram 링).
class ShopHighlight {
  const ShopHighlight({
    required this.id,
    required this.shopId,
    required this.title,
    this.coverImageUrl,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String title;
  final String? coverImageUrl;
  final DateTime? createdAt;

  factory ShopHighlight.fromMap(Map<String, dynamic> map) {
    return ShopHighlight(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id']),
      title: DbMap.asText(map['title']),
      coverImageUrl: DbMap.asTextOrNull(map['cover_image_url']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'shop_id': shopId,
        'title': title,
        if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty)
          'cover_image_url': coverImageUrl!.trim(),
      };
}
