import '../services/sori_store.dart';
import '../widgets/post/post_view_data.dart';

/// Resolves post ownership for kebab menu (author vs viewer).
abstract final class PostAuthor {
  static String? userId(PostViewData data) {
    final fromPost = data.post?.authorUserId?.trim();
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;
    return data.caseItem?.authorId;
  }

  static String? blockKey(PostViewData data) {
    final uid = userId(data);
    if (uid != null && uid.isNotEmpty) return 'user:$uid';
    final shopId = data.post?.shopId.trim() ??
        data.caseItem?.shop.id.trim() ??
        data.seminar?.directorShopId.trim();
    if (shopId != null && shopId.isNotEmpty) return 'shop:$shopId';
    return null;
  }

  static bool isAuthor(PostViewData data, SoriStore store) {
    final uid = store.session?.id.trim() ?? '';
    final aid = userId(data)?.trim() ?? '';
    if (uid.isNotEmpty && aid.isNotEmpty && uid == aid) return true;

    final shopId = store.shop.id.trim();
    if (shopId.isEmpty) return false;

    if (data.post?.shopId.trim() == shopId) return true;
    if (data.caseItem?.shop.id.trim() == shopId) return true;
    if (data.seminar?.directorShopId.trim() == shopId) return true;
    return false;
  }
}
