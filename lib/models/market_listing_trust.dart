import '../utils/db_map.dart';

/// E3 — 신뢰순 마켓 리스팅 행.
class MarketListingScoredRow {
  const MarketListingScoredRow({
    required this.listingId,
    required this.postId,
    required this.shopId,
    this.shopName = '',
    this.deviceName = '',
    this.price = 0,
    this.listingStatus = 'active',
    this.sellerTrustScore = 0,
    this.sellerTrustLabel = '성장 중',
    this.escrowStatus = '',
    this.createdAt,
  });

  final String listingId;
  final String postId;
  final String shopId;
  final String shopName;
  final String deviceName;
  final int price;
  final String listingStatus;
  final int sellerTrustScore;
  final String sellerTrustLabel;
  final String escrowStatus;
  final DateTime? createdAt;

  bool get hasEscrowHeld => escrowStatus == 'held';

  factory MarketListingScoredRow.fromMap(Map<String, dynamic> map) {
    return MarketListingScoredRow(
      listingId: DbMap.asText(map['listing_id'] ?? map['listingId']),
      postId: DbMap.asText(map['post_id'] ?? map['postId']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      shopName: DbMap.asText(map['shop_name'] ?? map['shopName']),
      deviceName: DbMap.asText(map['device_name'] ?? map['deviceName']),
      price: DbMap.asInt(map['price']),
      listingStatus: DbMap.asText(
        map['listing_status'] ?? map['listingStatus'],
        'active',
      ),
      sellerTrustScore: DbMap.asInt(
        map['seller_trust_score'] ?? map['sellerTrustScore'],
      ),
      sellerTrustLabel: DbMap.asText(
        map['seller_trust_label'] ?? map['sellerTrustLabel'],
        '성장 중',
      ),
      escrowStatus: DbMap.asText(map['escrow_status'] ?? map['escrowStatus']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

class ListingInquiryResult {
  const ListingInquiryResult({
    required this.ok,
    this.inquiryId,
    this.listingId,
  });

  final bool ok;
  final String? inquiryId;
  final String? listingId;

  factory ListingInquiryResult.fromMap(Map<String, dynamic> map) {
    return ListingInquiryResult(
      ok: map['ok'] == true,
      inquiryId: DbMap.asTextOrNull(map['inquiry_id'] ?? map['inquiryId']),
      listingId: DbMap.asTextOrNull(map['listing_id'] ?? map['listingId']),
    );
  }
}

class MarketEscrowResult {
  const MarketEscrowResult({
    required this.ok,
    this.escrowId,
    this.status = '',
  });

  final bool ok;
  final String? escrowId;
  final String status;

  factory MarketEscrowResult.fromMap(Map<String, dynamic> map) {
    return MarketEscrowResult(
      ok: map['ok'] == true,
      escrowId: DbMap.asTextOrNull(map['escrow_id'] ?? map['escrowId']),
      status: DbMap.asText(map['status']),
    );
  }
}
