import '../utils/db_map.dart';

enum ReviewStatus {
  draft,
  accepted,
  editing,
  replyRequested,
  published,
}

extension ReviewStatusX on ReviewStatus {
  String get dbValue => switch (this) {
        ReviewStatus.draft => 'draft',
        ReviewStatus.accepted => 'accepted',
        ReviewStatus.editing => 'editing',
        ReviewStatus.replyRequested => 'reply_requested',
        ReviewStatus.published => 'published',
      };

  static ReviewStatus fromDb(String value) => switch (value) {
        'accepted' => ReviewStatus.accepted,
        'editing' => ReviewStatus.editing,
        'reply_requested' => ReviewStatus.replyRequested,
        'published' => ReviewStatus.published,
        _ => ReviewStatus.draft,
      };
}

class CustomerReview {
  const CustomerReview({
    required this.id,
    required this.chartId,
    required this.customerId,
    required this.shopId,
    this.puzzleSelections = const [],
    this.originalText = '',
    this.editedText,
    this.status = ReviewStatus.draft,
    this.requestAiReply = false,
    this.acceptedAt,
    this.naverRegistered = false,
    this.naverRegisteredAt,
    this.rating,
    this.directorReply,
    this.directorRepliedAt,
    this.createdAt,
  });

  final String id;
  final String chartId;
  final String customerId;
  final String shopId;
  final List<String> puzzleSelections;
  final String originalText;
  final String? editedText;
  final ReviewStatus status;
  final bool requestAiReply;
  final DateTime? acceptedAt;
  final bool naverRegistered;
  final DateTime? naverRegisteredAt;

  /// 1~5. null이면 [effectiveRating]으로 추정.
  final int? rating;
  final String? directorReply;
  final DateTime? directorRepliedAt;
  final DateTime? createdAt;

  String get displayText =>
      (editedText != null && editedText!.trim().isNotEmpty)
          ? editedText!
          : originalText;

  bool get isInboxVisible =>
      status != ReviewStatus.draft && displayText.trim().isNotEmpty;

  /// 정렬/표시용 별점 (미입력 시 퍼즐 개수·완료 상태로 추정).
  int get effectiveRating {
    if (rating != null && rating! >= 1 && rating! <= 5) return rating!;
    if (!isInboxVisible) return 0;
    final n = puzzleSelections.length;
    if (n <= 0) return 5;
    return n.clamp(1, 5);
  }

  bool get hasDirectorReply =>
      directorReply != null && directorReply!.trim().isNotEmpty;

  CustomerReview copyWith({
    String? id,
    String? chartId,
    String? customerId,
    String? shopId,
    List<String>? puzzleSelections,
    String? originalText,
    String? editedText,
    ReviewStatus? status,
    bool? requestAiReply,
    DateTime? acceptedAt,
    bool? naverRegistered,
    DateTime? naverRegisteredAt,
    int? rating,
    String? directorReply,
    DateTime? directorRepliedAt,
    DateTime? createdAt,
    bool clearDirectorReply = false,
    bool clearNaverRegisteredAt = false,
  }) {
    return CustomerReview(
      id: id ?? this.id,
      chartId: chartId ?? this.chartId,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      puzzleSelections: puzzleSelections ?? this.puzzleSelections,
      originalText: originalText ?? this.originalText,
      editedText: editedText ?? this.editedText,
      status: status ?? this.status,
      requestAiReply: requestAiReply ?? this.requestAiReply,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      naverRegistered: naverRegistered ?? this.naverRegistered,
      naverRegisteredAt: clearNaverRegisteredAt
          ? null
          : (naverRegisteredAt ?? this.naverRegisteredAt),
      rating: rating ?? this.rating,
      directorReply:
          clearDirectorReply ? null : (directorReply ?? this.directorReply),
      directorRepliedAt: clearDirectorReply
          ? null
          : (directorRepliedAt ?? this.directorRepliedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'chart_id': chartId,
        'customer_id': customerId,
        'shop_id': shopId,
        'puzzle_selections': puzzleSelections,
        'original_text': originalText,
        'edited_text': editedText,
        'status': status.dbValue,
        'request_ai_reply': requestAiReply,
        'accepted_at': acceptedAt?.toIso8601String(),
        'naver_registered': naverRegistered,
        'naver_registered_at': naverRegisteredAt?.toIso8601String(),
        if (rating != null) 'rating': rating,
        'director_reply': directorReply,
        'director_replied_at': directorRepliedAt?.toIso8601String(),
      };

  factory CustomerReview.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(map['id']);
    final chartId = DbMap.asText(map['chart_id']);
    final customerId = DbMap.asText(map['customer_id']);
    final shopId = DbMap.asText(map['shop_id']);
    if (id.isEmpty || chartId.isEmpty || shopId.isEmpty) {
      throw FormatException(
        'customer_reviews row missing required fields '
        '(id/chart_id/shop_id)',
      );
    }
    final rawRating = map['rating'];
    int? rating;
    if (rawRating is int) {
      rating = rawRating.clamp(1, 5);
    } else if (rawRating is num) {
      rating = rawRating.toInt().clamp(1, 5);
    } else if (rawRating is String) {
      rating = int.tryParse(rawRating)?.clamp(1, 5);
    }
    return CustomerReview(
      id: id,
      chartId: chartId,
      customerId: customerId,
      shopId: shopId,
      puzzleSelections: DbMap.asStringList(map['puzzle_selections']),
      originalText: DbMap.asText(map['original_text']),
      editedText: DbMap.asTextOrNull(map['edited_text']),
      status: ReviewStatusX.fromDb(DbMap.asText(map['status'], 'draft')),
      requestAiReply: DbMap.asBool(map['request_ai_reply']),
      acceptedAt: DbMap.asDateTime(map['accepted_at']),
      naverRegistered: DbMap.asBool(map['naver_registered']),
      naverRegisteredAt: DbMap.asDateTime(map['naver_registered_at']),
      rating: rating,
      directorReply: DbMap.asTextOrNull(map['director_reply']),
      directorRepliedAt: DbMap.asDateTime(map['director_replied_at']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
