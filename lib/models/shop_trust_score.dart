import '../utils/db_map.dart';

/// 샵 신뢰 스코어 — 북마크·후원·리뷰·세미나 복합 (S5, 읽기 전용).
class ShopTrustScore {
  const ShopTrustScore({
    this.score = 0,
    this.tierLabel = '성장 중',
    this.bookmarkCount = 0,
    this.supporterEcho = 0,
    this.supporterGiftCount = 0,
    this.reviewAvg = 0,
    this.reviewCount = 0,
    this.seminarCount = 0,
    this.thankYouRate = 0,
  });

  final int score;
  final String tierLabel;
  final int bookmarkCount;
  final int supporterEcho;
  final int supporterGiftCount;
  final double reviewAvg;
  final int reviewCount;
  final int seminarCount;
  final double thankYouRate;

  static const empty = ShopTrustScore();

  factory ShopTrustScore.fromMap(Map<String, dynamic> map) {
    return ShopTrustScore(
      score: DbMap.asInt(map['score']),
      tierLabel: DbMap.asText(map['tier_label'] ?? map['tierLabel'], '성장 중'),
      bookmarkCount: DbMap.asInt(map['bookmark_count'] ?? map['bookmarkCount']),
      supporterEcho: DbMap.asInt(map['supporter_echo'] ?? map['supporterEcho']),
      supporterGiftCount: DbMap.asInt(
        map['supporter_gift_count'] ?? map['supporterGiftCount'],
      ),
      reviewAvg: _asDouble(map['review_avg'] ?? map['reviewAvg']),
      reviewCount: DbMap.asInt(map['review_count'] ?? map['reviewCount']),
      seminarCount: DbMap.asInt(map['seminar_count'] ?? map['seminarCount']),
      thankYouRate: _asDouble(map['thank_you_rate'] ?? map['thankYouRate']),
    );
  }

  String get summaryLine {
    final parts = <String>[];
    if (bookmarkCount > 0) parts.add('저장 $bookmarkCount');
    if (supporterGiftCount > 0) parts.add('후원 $supporterGiftCount');
    if (reviewCount > 0) parts.add('리뷰 ${reviewAvg.toStringAsFixed(1)}');
    if (parts.isEmpty) return '북마크·후원이 쌓이면 신뢰 지표가 올라갑니다';
    return parts.join(' · ');
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}
