import '../utils/db_map.dart';
import 'my_boost_gift.dart';

/// 고객 — 후원 1건의 기여 지표 (E5-lite).
class BoostGiftImpactReport extends MyBoostGiftItem {
  const BoostGiftImpactReport({
    required super.fanGiftId,
    required super.targetType,
    super.chartId,
    super.shopId = '',
    super.shopName = '',
    super.sku = '',
    super.echoSpent = 0,
    super.giftKind = 'boost',
    super.createdAt,
    super.caseTitle = '',
    super.hasThankYou = false,
    super.thankYouPostId,
    this.bookmarksSinceGift = 0,
    this.estimatedReach = 0,
    this.boostStillActive = false,
  });

  final int bookmarksSinceGift;
  final int estimatedReach;
  final bool boostStillActive;

  factory BoostGiftImpactReport.fromMap(Map<String, dynamic> map) {
    final base = MyBoostGiftItem.fromMap(map);
    return BoostGiftImpactReport(
      fanGiftId: base.fanGiftId,
      targetType: base.targetType,
      chartId: base.chartId,
      shopId: base.shopId,
      shopName: base.shopName,
      sku: base.sku,
      echoSpent: base.echoSpent,
      giftKind: base.giftKind,
      createdAt: base.createdAt,
      caseTitle: base.caseTitle,
      hasThankYou: base.hasThankYou,
      thankYouPostId: base.thankYouPostId,
      bookmarksSinceGift: DbMap.asInt(
        map['bookmarks_since_gift'] ?? map['bookmarksSinceGift'],
      ),
      estimatedReach: DbMap.asInt(
        map['estimated_reach'] ?? map['estimatedReach'],
      ),
      boostStillActive:
          map['boost_still_active'] == true || map['boostStillActive'] == true,
    );
  }

  String get impactLine {
    final parts = <String>[];
    if (estimatedReach > 0) {
      parts.add('노출 약 ${estimatedReach}회');
    }
    if (bookmarksSinceGift > 0) {
      parts.add('저장 ${bookmarksSinceGift}건');
    }
    if (parts.isEmpty) {
      return boostStillActive ? '부스터 노출 진행 중' : '기여 집계 중';
    }
    return parts.join(' · ');
  }
}

/// 원장 — 샵 후원 기여 요약 (E5-lite).
class ShopSponsorshipImpact {
  const ShopSponsorshipImpact({
    this.periodDays = 30,
    this.giftCount = 0,
    this.echoTotal = 0,
    this.bookmarksReceived = 0,
    this.thankYousSent = 0,
    this.pendingThanks = 0,
    this.estimatedTotalReach = 0,
  });

  final int periodDays;
  final int giftCount;
  final int echoTotal;
  final int bookmarksReceived;
  final int thankYousSent;
  final int pendingThanks;
  final int estimatedTotalReach;

  factory ShopSponsorshipImpact.fromMap(Map<String, dynamic> map) {
    return ShopSponsorshipImpact(
      periodDays: DbMap.asInt(map['period_days'] ?? map['periodDays'], 30),
      giftCount: DbMap.asInt(map['gift_count'] ?? map['giftCount']),
      echoTotal: DbMap.asInt(map['echo_total'] ?? map['echoTotal']),
      bookmarksReceived: DbMap.asInt(
        map['bookmarks_received'] ?? map['bookmarksReceived'],
      ),
      thankYousSent: DbMap.asInt(map['thank_yous_sent'] ?? map['thankYousSent']),
      pendingThanks: DbMap.asInt(map['pending_thanks'] ?? map['pendingThanks']),
      estimatedTotalReach: DbMap.asInt(
        map['estimated_total_reach'] ?? map['estimatedTotalReach'],
      ),
    );
  }

  static const empty = ShopSponsorshipImpact();
}
