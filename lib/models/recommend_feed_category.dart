import 'unified_feed_item.dart';

/// PRD v7.8 C4 — 추천 탭 카테고리 (초안 id 고정).
/// 기존 UnifiedFeedKind를 매핑만 하며, kind enum은 삭제·리네임하지 않는다.
enum RecommendFeedCategory {
  baCase('ba_case', '전후'),
  seminar('seminar', '세미나'),
  tipDevice('tip_device', '기기 리뷰'),
  tipProduct('tip_product', '제품 리뷰'),
  news('news', '소식'),
  mentorAsk('mentor_ask', '멘토 요청'),
  mentorOffer('mentor_offer', '멘토 지원'),
  /// PRD 7종 외 — 기존 소스 유지용 (뱃지 표시)
  whisper('whisper', 'Whisper'),
  interior('interior', '인테리어'),
  usedMarket('used_market', '중고');

  const RecommendFeedCategory(this.id, this.label);
  final String id;
  final String label;

  /// 통합 피드 아이템 → 카테고리 (마이그레이션 없이 파생).
  static RecommendFeedCategory fromUnified(UnifiedFeedItem item) {
    switch (item.kind) {
      case UnifiedFeedKind.ba:
        if (item.caseItem?.hasActiveMentoring == true) {
          return RecommendFeedCategory.mentorOffer;
        }
        return RecommendFeedCategory.baCase;
      case UnifiedFeedKind.seminar:
        return RecommendFeedCategory.seminar;
      case UnifiedFeedKind.deviceReview:
        return RecommendFeedCategory.tipDevice;
      case UnifiedFeedKind.marketplace:
        return item.isMarketplaceUsed
            ? RecommendFeedCategory.usedMarket
            : RecommendFeedCategory.tipProduct;
      case UnifiedFeedKind.whisper:
        return _fromPostTags(item) ?? RecommendFeedCategory.whisper;
      case UnifiedFeedKind.interior:
        return RecommendFeedCategory.interior;
    }
  }

  static RecommendFeedCategory? _fromPostTags(UnifiedFeedItem item) {
    final tags = item.post?.styleTags ?? const <String>[];
    final blob = tags.join(' ');
    if (blob.contains('요청')) return RecommendFeedCategory.mentorAsk;
    if (blob.contains('멘토') || blob.contains('조언') || blob.contains('지원')) {
      return RecommendFeedCategory.mentorOffer;
    }
    if (blob.contains('소식') || blob.contains('뉴스')) {
      return RecommendFeedCategory.news;
    }
    return null;
  }

  /// 캘린더 일 버킷 라벨 (추천 탭 일 단위 노출).
  static String daySectionLabel(DateTime sortAt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final local = sortAt.toLocal();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '이번 주';
    return '이전';
  }
}
