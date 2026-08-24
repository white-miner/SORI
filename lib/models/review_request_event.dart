import '../utils/db_map.dart';

enum ReviewRequestChannel {
  qr,
  link,
  alimtalk,
  manual,
}

extension ReviewRequestChannelX on ReviewRequestChannel {
  String get dbValue => name;

  static ReviewRequestChannel fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'link':
        return ReviewRequestChannel.link;
      case 'alimtalk':
        return ReviewRequestChannel.alimtalk;
      case 'manual':
        return ReviewRequestChannel.manual;
      case 'qr':
      default:
        return ReviewRequestChannel.qr;
    }
  }

  String get label => switch (this) {
        ReviewRequestChannel.qr => 'QR',
        ReviewRequestChannel.link => '링크',
        ReviewRequestChannel.alimtalk => '알림톡',
        ReviewRequestChannel.manual => '직접',
      };
}

enum ReviewRequestStatus {
  sent,
  opened,
  converted,
  expired,
  cancelled,
}

extension ReviewRequestStatusX on ReviewRequestStatus {
  String get dbValue => name;

  static ReviewRequestStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'opened':
        return ReviewRequestStatus.opened;
      case 'converted':
        return ReviewRequestStatus.converted;
      case 'expired':
        return ReviewRequestStatus.expired;
      case 'cancelled':
        return ReviewRequestStatus.cancelled;
      case 'sent':
      default:
        return ReviewRequestStatus.sent;
    }
  }

  String get label => switch (this) {
        ReviewRequestStatus.sent => '요청됨',
        ReviewRequestStatus.opened => '열람',
        ReviewRequestStatus.converted => '작성완료',
        ReviewRequestStatus.expired => '만료',
        ReviewRequestStatus.cancelled => '취소',
      };

  bool get isOpen =>
      this == ReviewRequestStatus.sent || this == ReviewRequestStatus.opened;
}

class ReviewRequestEvent {
  const ReviewRequestEvent({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.chartId,
    this.channel = ReviewRequestChannel.qr,
    this.status = ReviewRequestStatus.sent,
    this.sentAt,
    this.openedAt,
    this.convertedReviewId,
    this.remindAt,
    this.remindedAt,
    this.createdBy,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String? chartId;
  final ReviewRequestChannel channel;
  final ReviewRequestStatus status;
  final DateTime? sentAt;
  final DateTime? openedAt;
  final String? convertedReviewId;
  final DateTime? remindAt;
  final DateTime? remindedAt;
  final String? createdBy;

  bool get isDueForRemind {
    if (!status.isOpen || remindedAt != null || remindAt == null) return false;
    return !remindAt!.isAfter(DateTime.now());
  }

  ReviewRequestEvent copyWith({
    ReviewRequestStatus? status,
    String? convertedReviewId,
    DateTime? remindedAt,
    bool clearRemindedAt = false,
  }) {
    return ReviewRequestEvent(
      id: id,
      shopId: shopId,
      customerId: customerId,
      chartId: chartId,
      channel: channel,
      status: status ?? this.status,
      sentAt: sentAt,
      openedAt: openedAt,
      convertedReviewId: convertedReviewId ?? this.convertedReviewId,
      remindAt: remindAt,
      remindedAt:
          clearRemindedAt ? null : (remindedAt ?? this.remindedAt),
      createdBy: createdBy,
    );
  }

  factory ReviewRequestEvent.fromMap(Map<String, dynamic> map) {
    return ReviewRequestEvent(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      customerId: DbMap.asText(map['customer_id'] ?? map['customerId']),
      chartId: DbMap.asTextOrNull(map['chart_id'] ?? map['chartId']),
      channel: ReviewRequestChannelX.fromDb(
        DbMap.asText(map['channel'], 'qr'),
      ),
      status: ReviewRequestStatusX.fromDb(
        DbMap.asText(map['status'], 'sent'),
      ),
      sentAt: DbMap.asDateTime(map['sent_at'] ?? map['sentAt']),
      openedAt: DbMap.asDateTime(map['opened_at'] ?? map['openedAt']),
      convertedReviewId: DbMap.asTextOrNull(
        map['converted_review_id'] ?? map['convertedReviewId'],
      ),
      remindAt: DbMap.asDateTime(map['remind_at'] ?? map['remindAt']),
      remindedAt: DbMap.asDateTime(map['reminded_at'] ?? map['remindedAt']),
      createdBy: DbMap.asTextOrNull(map['created_by'] ?? map['createdBy']),
    );
  }
}

class CareRatingStat {
  const CareRatingStat({
    required this.careName,
    required this.avgRating,
    required this.count,
  });

  final String careName;
  final double avgRating;
  final int count;
}
