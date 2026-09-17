import '../utils/db_map.dart';

/// Community 계층형 댓글 (SSOT).
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.content,
    this.authorUserId,
    this.authorShopId,
    this.parentId,
    this.authorName = '',
    this.authorShopName = '',
    this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String postId;
  final String? authorUserId;
  final String? authorShopId;
  final String? parentId;
  final String content;
  final String authorName;
  final String authorShopName;
  final DateTime? createdAt;
  final List<CommunityComment> replies;

  String get displayName {
    final n = authorName.trim();
    if (n.isNotEmpty) return n;
    final s = authorShopName.trim();
    if (s.isNotEmpty) return s;
    return '원장';
  }

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    return CommunityComment(
      id: DbMap.asText(map['id']),
      postId: DbMap.asText(map['post_id'] ?? map['postId']),
      authorUserId: DbMap.asTextOrNull(
        map['author_user_id'] ?? map['authorUserId'],
      ),
      authorShopId: DbMap.asTextOrNull(
        map['author_shop_id'] ?? map['authorShopId'],
      ),
      parentId: DbMap.asTextOrNull(map['parent_id'] ?? map['parentId']),
      content: DbMap.asText(map['content'] ?? map['body']),
      authorName: DbMap.asText(
        map['author_name'] ?? map['authorName'],
      ),
      authorShopName: DbMap.asText(
        map['author_shop_name'] ?? map['authorShopName'],
      ),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }

  CommunityComment copyWith({List<CommunityComment>? replies}) {
    return CommunityComment(
      id: id,
      postId: postId,
      authorUserId: authorUserId,
      authorShopId: authorShopId,
      parentId: parentId,
      content: content,
      authorName: authorName,
      authorShopName: authorShopName,
      createdAt: createdAt,
      replies: replies ?? this.replies,
    );
  }

  /// flat list → nested tree (parent_id).
  static List<CommunityComment> nest(List<CommunityComment> flat) {
    final byId = {for (final c in flat) c.id: c};
    final roots = <CommunityComment>[];
    final children = <String, List<CommunityComment>>{};
    for (final c in flat) {
      final p = c.parentId?.trim() ?? '';
      if (p.isEmpty || !byId.containsKey(p)) {
        roots.add(c);
      } else {
        children.putIfAbsent(p, () => []).add(c);
      }
    }
    CommunityComment attach(CommunityComment node) {
      final kids = children[node.id] ?? const [];
      return node.copyWith(replies: kids.map(attach).toList(growable: false));
    }

    return roots.map(attach).toList(growable: false);
  }
}
