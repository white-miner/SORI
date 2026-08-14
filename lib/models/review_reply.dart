import '../utils/db_map.dart';

/// 리뷰 답글 이력 (review_replies).
class ReviewReply {
  const ReviewReply({
    required this.id,
    required this.reviewId,
    required this.shopId,
    required this.body,
    this.authorRole = 'director',
    this.createdAt,
  });

  final String id;
  final String reviewId;
  final String shopId;
  final String body;
  final String authorRole;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'review_id': reviewId,
        'shop_id': shopId,
        'author_role': authorRole,
        'body': body.trim(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory ReviewReply.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(map['id']);
    final reviewId = DbMap.asText(map['review_id']);
    final shopId = DbMap.asText(map['shop_id']);
    final body = DbMap.asText(map['body']);
    if (id.isEmpty || reviewId.isEmpty || shopId.isEmpty) {
      throw FormatException('review_replies row missing required fields');
    }
    return ReviewReply(
      id: id,
      reviewId: reviewId,
      shopId: shopId,
      body: body,
      authorRole: DbMap.asText(map['author_role'], 'director'),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
