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

  String get displayText =>
      (editedText != null && editedText!.trim().isNotEmpty)
          ? editedText!
          : originalText;

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
      naverRegisteredAt: naverRegisteredAt ?? this.naverRegisteredAt,
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
      };

  factory CustomerReview.fromMap(Map<String, dynamic> map) {
    final puzzle = map['puzzle_selections'];
    return CustomerReview(
      id: map['id'] as String,
      chartId: map['chart_id'] as String,
      customerId: map['customer_id'] as String,
      shopId: map['shop_id'] as String,
      puzzleSelections: puzzle is List
          ? puzzle.map((e) => e.toString()).toList()
          : const [],
      originalText: map['original_text'] as String? ?? '',
      editedText: map['edited_text'] as String?,
      status: ReviewStatusX.fromDb(map['status'] as String? ?? 'draft'),
      requestAiReply: map['request_ai_reply'] as bool? ?? false,
      acceptedAt: map['accepted_at'] != null
          ? DateTime.parse(map['accepted_at'] as String)
          : null,
      naverRegistered: map['naver_registered'] as bool? ?? false,
      naverRegisteredAt: map['naver_registered_at'] != null
          ? DateTime.parse(map['naver_registered_at'] as String)
          : null,
    );
  }
}
