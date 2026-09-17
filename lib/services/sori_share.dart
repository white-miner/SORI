import 'package:share_plus/share_plus.dart';

import '../services/sori_store.dart';

/// 카카오톡/문자 등 시스템 공유 시트.
abstract final class SoriShare {
  static Future<void> shareReviewLink({
    required String url,
    String customerName = '고객',
    String? careName,
  }) async {
    final care = (careName != null && careName.trim().isNotEmpty)
        ? careName.trim()
        : '오늘 케어';
    final text =
        '$customerName님, $care 시술 리포트와 AI 리뷰 작성 링크입니다.\n\n$url\n\n— 소통하는 리뷰, SORI';
    await Share.share(text, subject: 'SORI 케어 리뷰 링크');
  }

  static Future<void> shareShopEntry({
    required String shopName,
    String? url,
  }) async {
    final link = url ?? SoriStore.buildAppEntryUrl();
    final text =
        '[$shopName]\n고객님 전용 SORI 리뷰 작성 페이지입니다.\n아래 링크로 들어와 후기를 남겨 주세요.\n\n$link';
    await Share.share(text, subject: '$shopName 리뷰 작성');
  }
}
