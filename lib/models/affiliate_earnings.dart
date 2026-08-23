import '../utils/db_map.dart';

class AffiliateLink {
  const AffiliateLink({
    required this.id,
    required this.shopId,
    required this.destinationUrl,
    this.partnerId,
    this.postId,
    this.postTagId,
    this.label = '',
    this.commissionPerClick = 500,
  });

  final String id;
  final String shopId;
  final String? partnerId;
  final String? postId;
  final String? postTagId;
  final String destinationUrl;
  final String label;
  final int commissionPerClick;

  factory AffiliateLink.fromMap(Map<String, dynamic> map) {
    return AffiliateLink(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      partnerId: DbMap.asTextOrNull(map['partner_id'] ?? map['partnerId']),
      postId: DbMap.asTextOrNull(map['post_id'] ?? map['postId']),
      postTagId: DbMap.asTextOrNull(map['post_tag_id'] ?? map['postTagId']),
      destinationUrl: DbMap.asText(
        map['destination_url'] ?? map['destinationUrl'],
      ),
      label: DbMap.asText(map['label']),
      commissionPerClick: DbMap.asInt(
        map['commission_per_click'] ?? map['commissionPerClick'],
        500,
      ),
    );
  }
}

class AffiliateCommission {
  const AffiliateCommission({
    required this.id,
    required this.shopId,
    required this.linkId,
    required this.amount,
    this.status = 'pending',
    this.createdAt,
    this.linkLabel = '',
    this.destinationUrl = '',
  });

  final String id;
  final String shopId;
  final String linkId;
  final int amount;
  final String status;
  final DateTime? createdAt;
  final String linkLabel;
  final String destinationUrl;

  factory AffiliateCommission.fromMap(Map<String, dynamic> map) {
    return AffiliateCommission(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      linkId: DbMap.asText(map['link_id'] ?? map['linkId']),
      amount: DbMap.asInt(map['amount']),
      status: DbMap.asText(map['status'], 'pending'),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      linkLabel: DbMap.asText(map['link_label'] ?? map['label']),
      destinationUrl: DbMap.asText(
        map['destination_url'] ?? map['destinationUrl'],
      ),
    );
  }
}

/// 마이페이지 제휴 정산 요약.
class AffiliateEarningsSummary {
  const AffiliateEarningsSummary({
    this.clickCount = 0,
    this.pendingAmount = 0,
    this.confirmedAmount = 0,
    this.paidAmount = 0,
    this.recentCommissions = const [],
  });

  final int clickCount;
  final int pendingAmount;
  final int confirmedAmount;
  final int paidAmount;
  final List<AffiliateCommission> recentCommissions;

  int get totalEarned => pendingAmount + confirmedAmount + paidAmount;
}
