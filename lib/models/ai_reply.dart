enum AiReplyStatus {
  pending,
  generating,
  ready,
  failed,
}

extension AiReplyStatusX on AiReplyStatus {
  String get dbValue => switch (this) {
        AiReplyStatus.pending => 'pending',
        AiReplyStatus.generating => 'generating',
        AiReplyStatus.ready => 'ready',
        AiReplyStatus.failed => 'failed',
      };

  static AiReplyStatus fromDb(String value) => switch (value) {
        'generating' => AiReplyStatus.generating,
        'ready' => AiReplyStatus.ready,
        'failed' => AiReplyStatus.failed,
        _ => AiReplyStatus.pending,
      };
}

class AiReply {
  const AiReply({
    required this.id,
    required this.reviewId,
    required this.chartId,
    this.status = AiReplyStatus.pending,
    this.replyText,
    this.isCopied = false,
    this.copiedAt,
    this.generatedAt,
  });

  final String id;
  final String reviewId;
  final String chartId;
  final AiReplyStatus status;
  final String? replyText;
  final bool isCopied;
  final DateTime? copiedAt;
  final DateTime? generatedAt;

  AiReply copyWith({
    String? id,
    String? reviewId,
    String? chartId,
    AiReplyStatus? status,
    String? replyText,
    bool? isCopied,
    DateTime? copiedAt,
    DateTime? generatedAt,
  }) {
    return AiReply(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      chartId: chartId ?? this.chartId,
      status: status ?? this.status,
      replyText: replyText ?? this.replyText,
      isCopied: isCopied ?? this.isCopied,
      copiedAt: copiedAt ?? this.copiedAt,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'review_id': reviewId,
        'chart_id': chartId,
        'status': status.dbValue,
        'reply_text': replyText,
        'is_copied': isCopied,
        'copied_at': copiedAt?.toIso8601String(),
        'generated_at': generatedAt?.toIso8601String(),
      };

  factory AiReply.fromMap(Map<String, dynamic> map) {
    return AiReply(
      id: map['id'] as String,
      reviewId: map['review_id'] as String,
      chartId: map['chart_id'] as String,
      status: AiReplyStatusX.fromDb(map['status'] as String? ?? 'pending'),
      replyText: map['reply_text'] as String?,
      isCopied: map['is_copied'] as bool? ?? false,
      copiedAt: map['copied_at'] != null
          ? DateTime.parse(map['copied_at'] as String)
          : null,
      generatedAt: map['generated_at'] != null
          ? DateTime.parse(map['generated_at'] as String)
          : null,
    );
  }
}
