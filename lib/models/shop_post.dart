import '../utils/db_map.dart';

/// 샵 Home 「최근 소식」 쓰레드 포스트.
class ShopPost {
  const ShopPost({
    required this.id,
    required this.shopId,
    required this.body,
    this.authorUserId,
    this.imageUrls = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String? authorUserId;
  final String body;
  final List<String> imageUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get primaryImageUrl {
    for (final u in imageUrls) {
      final t = u.trim();
      if (t.startsWith('http')) return t;
    }
    return null;
  }

  factory ShopPost.fromMap(Map<String, dynamic> map) {
    final urlsRaw = map['image_urls'] ?? map['imageUrls'];
    final urls = <String>[];
    if (urlsRaw is List) {
      for (final e in urlsRaw) {
        final t = e?.toString().trim() ?? '';
        if (t.isNotEmpty) urls.add(t);
      }
    }
    return ShopPost(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      authorUserId: DbMap.asTextOrNull(
        map['author_user_id'] ?? map['authorUserId'],
      ),
      body: DbMap.asText(map['body']),
      imageUrls: urls,
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: DbMap.asDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'shop_id': shopId,
        if (authorUserId != null && authorUserId!.isNotEmpty)
          'author_user_id': authorUserId,
        'body': body.trim(),
        'image_urls': imageUrls,
      };
}
