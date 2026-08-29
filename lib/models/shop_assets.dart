import '../utils/db_map.dart';
import 'fan_supporter.dart';

/// Asset 탭 Tier 1 — 관심 지표 (Echo보다 우선).
class ShopAssetTier1 {
  const ShopAssetTier1({
    this.chartCountTotal = 0,
    this.baPublishedCount = 0,
    this.baViewTotal = 0,
    this.bookmarkTotal = 0,
  });

  final int chartCountTotal;
  final int baPublishedCount;
  final int baViewTotal;
  final int bookmarkTotal;

  factory ShopAssetTier1.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ShopAssetTier1();
    return ShopAssetTier1(
      chartCountTotal: DbMap.asInt(
        map['chart_count_total'] ?? map['chartCountTotal'],
      ),
      baPublishedCount: DbMap.asInt(
        map['ba_published_count'] ?? map['baPublishedCount'],
      ),
      baViewTotal: DbMap.asInt(map['ba_view_total'] ?? map['baViewTotal']),
      bookmarkTotal: DbMap.asInt(
        map['bookmark_total'] ?? map['bookmarkTotal'],
      ),
    );
  }
}

/// Asset 탭 Tier 2 — 수익·평판.
class ShopAssetTier2 {
  const ShopAssetTier2({
    this.seminarHostedCount = 0,
    this.seminarRequestReceivedCount = 0,
    this.seminarRequestSentCount = 0,
    this.followerCount = 0,
    this.supporterCount = 0,
    this.mentoringRevenueEchoTotal = 0,
  });

  final int seminarHostedCount;
  final int seminarRequestReceivedCount;
  final int seminarRequestSentCount;
  final int followerCount;
  final int supporterCount;
  final int mentoringRevenueEchoTotal;

  factory ShopAssetTier2.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ShopAssetTier2();
    return ShopAssetTier2(
      seminarHostedCount: DbMap.asInt(
        map['seminar_hosted_count'] ?? map['seminarHostedCount'],
      ),
      seminarRequestReceivedCount: DbMap.asInt(
        map['seminar_request_received_count'] ??
            map['seminarRequestReceivedCount'],
      ),
      seminarRequestSentCount: DbMap.asInt(
        map['seminar_request_sent_count'] ?? map['seminarRequestSentCount'],
      ),
      followerCount: DbMap.asInt(
        map['follower_count'] ?? map['followerCount'],
      ),
      supporterCount: DbMap.asInt(
        map['supporter_count'] ?? map['supporterCount'],
      ),
      mentoringRevenueEchoTotal: DbMap.asInt(
        map['mentoring_revenue_echo_total'] ??
            map['mentoringRevenueEchoTotal'],
      ),
    );
  }
}

/// Asset Tier 3 preview row.
class ShopAssetSupporterPreview {
  const ShopAssetSupporterPreview({
    required this.customerId,
    required this.displayName,
    this.avatarUrl,
    this.echoTotal = 0,
    this.lastInteractionAt,
  });

  final String customerId;
  final String displayName;
  final String? avatarUrl;
  final int echoTotal;
  final DateTime? lastInteractionAt;

  factory ShopAssetSupporterPreview.fromMap(Map<String, dynamic> map) {
    return ShopAssetSupporterPreview(
      customerId: DbMap.asText(
        map['customer_id'] ?? map['customerId'],
      ),
      displayName: DbMap.asText(
        map['display_name'] ?? map['displayName'] ?? map['name'],
        'Supporter',
      ),
      avatarUrl: DbMap.asTextOrNull(
        map['avatar_url'] ?? map['avatarUrl'],
      ),
      echoTotal: DbMap.asInt(map['echo_total'] ?? map['echoTotal']),
      lastInteractionAt: DbMap.asDateTime(
        map['last_interaction_at'] ?? map['lastInteractionAt'],
      ),
    );
  }

  FanSupporterEntry toFanSupporterEntry() => FanSupporterEntry(
        name: displayName,
        echoSpent: echoTotal,
        customerId: customerId.isEmpty ? null : customerId,
        avatarUrl: avatarUrl,
      );

  factory ShopAssetSupporterPreview.fromFanSupporter(FanSupporterEntry e) {
    return ShopAssetSupporterPreview(
      customerId: e.customerId ?? '',
      displayName: e.name,
      avatarUrl: e.avatarUrl,
      echoTotal: e.echoSpent,
    );
  }
}

/// Supporter 상호작용 명세 1행.
class SupporterInteractionLine {
  const SupporterInteractionLine({
    required this.occurredAt,
    required this.kind,
    this.echoAmount = 0,
    this.targetLabel = '',
    this.targetId,
    this.metadata = const {},
  });

  final DateTime? occurredAt;
  final String kind;
  final int echoAmount;
  final String targetLabel;
  final String? targetId;
  final Map<String, dynamic> metadata;

  String get kindLabel => switch (kind) {
        'supporter_gift' => 'Supporter gift',
        'mentoring_purchase' => 'Premium Mentoring',
        'case_bookmark' => 'Bookmark',
        'whisper' => 'Whisper',
        _ => kind,
      };

  factory SupporterInteractionLine.fromMap(Map<String, dynamic> map) {
    return SupporterInteractionLine(
      occurredAt: DbMap.asDateTime(
        map['occurred_at'] ?? map['occurredAt'],
      ),
      kind: DbMap.asText(map['kind'], 'unknown'),
      echoAmount: DbMap.asInt(map['echo_amount'] ?? map['echoAmount']),
      targetLabel: DbMap.asText(
        map['target_label'] ?? map['targetLabel'],
      ),
      targetId: DbMap.asTextOrNull(map['target_id'] ?? map['targetId']),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
    );
  }
}

/// `get_shop_assets` RPC 응답.
class ShopAssetsSnapshot {
  const ShopAssetsSnapshot({
    this.tier1 = const ShopAssetTier1(),
    this.tier2 = const ShopAssetTier2(),
    this.supporterPreview = const [],
    this.refreshedAt,
  });

  final ShopAssetTier1 tier1;
  final ShopAssetTier2 tier2;
  final List<ShopAssetSupporterPreview> supporterPreview;
  final DateTime? refreshedAt;

  factory ShopAssetsSnapshot.fromMap(Map<String, dynamic> map) {
    final t3 = map['tier3_preview'] ?? map['tier3Preview'];
    final rows = <ShopAssetSupporterPreview>[];
    if (t3 is List) {
      for (final e in t3) {
        if (e is Map) {
          rows.add(
            ShopAssetSupporterPreview.fromMap(
              Map<String, dynamic>.from(e),
            ),
          );
        }
      }
    }
    return ShopAssetsSnapshot(
      tier1: ShopAssetTier1.fromMap(
        map['tier1'] is Map
            ? Map<String, dynamic>.from(map['tier1'] as Map)
            : null,
      ),
      tier2: ShopAssetTier2.fromMap(
        map['tier2'] is Map
            ? Map<String, dynamic>.from(map['tier2'] as Map)
            : null,
      ),
      supporterPreview: rows,
      refreshedAt: DbMap.asDateTime(
        map['refreshed_at'] ?? map['refreshedAt'],
      ),
    );
  }

  /// RPC 미적용 시 로컬 store 집계 fallback.
  factory ShopAssetsSnapshot.localFallback({
    required int chartCountTotal,
    required int baPublishedCount,
    required int bookmarkTotal,
    required int followerCount,
    required int supporterCount,
    required List<FanSupporterEntry> supporters,
    int seminarHostedCount = 0,
    int seminarRequestReceivedCount = 0,
    int seminarRequestSentCount = 0,
  }) {
    return ShopAssetsSnapshot(
      tier1: ShopAssetTier1(
        chartCountTotal: chartCountTotal,
        baPublishedCount: baPublishedCount,
        baViewTotal: 0,
        bookmarkTotal: bookmarkTotal,
      ),
      tier2: ShopAssetTier2(
        seminarHostedCount: seminarHostedCount,
        seminarRequestReceivedCount: seminarRequestReceivedCount,
        seminarRequestSentCount: seminarRequestSentCount,
        followerCount: followerCount,
        supporterCount: supporterCount,
      ),
      supporterPreview: supporters
          .map(
            (s) => ShopAssetSupporterPreview(
              customerId: s.customerId ?? '',
              displayName: s.name,
              avatarUrl: s.avatarUrl,
              echoTotal: s.echoSpent,
            ),
          )
          .toList(),
      refreshedAt: DateTime.now(),
    );
  }
}
