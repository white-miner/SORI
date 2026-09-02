import '../utils/db_map.dart';

/// PRD v7.0 — B/A 임시 촬영 세션의 수명 주기.
enum BaCaptureStatus {
  /// 캐러셀에 떠 있는 작업 중 세션.
  draft,

  /// 고객 차트에 연결 완료 — 관리 케이스 피드로 이관됨.
  linked,

  /// 30일 경과 등으로 정리된 세션.
  archived;

  String get dbValue => name;

  static BaCaptureStatus fromDb(String? raw) {
    return BaCaptureStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BaCaptureStatus.draft,
    );
  }
}

/// 🔴 판정 세부 사유 — 카드 배지 문구 분기용.
enum BaDraftReason {
  /// 두 장 모두 + 차트 매핑 완료 (🟢).
  complete,

  /// 아직 아무것도 촬영되지 않음.
  empty,

  /// Before 누락.
  missingBefore,

  /// After 누락.
  missingAfter,

  /// 두 장 다 있으나 고객 차트 미연동.
  unlinked;

  String get badgeLabel => switch (this) {
        BaDraftReason.complete => '완료',
        BaDraftReason.empty => '촬영 대기',
        BaDraftReason.missingBefore => 'Before 필요',
        BaDraftReason.missingAfter => 'After 필요',
        BaDraftReason.unlinked => '연결 대기',
      };
}

/// 캐러셀 카드 1장 = 이 모델 1개.
///
/// 차트를 열지 않은 상태에서도 Before/After를 촬영·보관할 수 있게 하는
/// 독립 임시 저장 단위이며, [chartId]가 채워지는 순간 🟢로 판정되어
/// 캐러셀에서 빠지고 관리 케이스 피드에 나타난다.
class BaCaptureSession {
  const BaCaptureSession({
    required this.id,
    required this.shopId,
    required this.sessionToken,
    this.authorId,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.beforeCapturedAt,
    this.afterCapturedAt,
    this.customerId,
    this.chartId,
    this.label = '',
    this.status = BaCaptureStatus.draft,
    this.deferredAt,
    this.linkedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;

  /// 기기 로컬 큐와의 멱등 키 — 승격 재실행 시 중복 생성을 막는다.
  final String sessionToken;
  final String? authorId;

  final String? beforeImageUrl;
  final String? afterImageUrl;
  final DateTime? beforeCapturedAt;
  final DateTime? afterCapturedAt;

  final String? customerId;
  final String? chartId;

  final String label;
  final BaCaptureStatus status;

  /// "완료"로 후순위화한 시각. 삭제가 아니라 정렬만 뒤로 밀린다.
  final DateTime? deferredAt;
  final DateTime? linkedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasBefore => (beforeImageUrl?.trim().isNotEmpty ?? false);
  bool get hasAfter => (afterImageUrl?.trim().isNotEmpty ?? false);
  bool get hasChart => (chartId?.trim().isNotEmpty ?? false);

  /// 신호등 SSOT — `ba_capture_sessions.is_complete` generated column과 동일 수식.
  bool get isComplete => hasBefore && hasAfter && hasChart;

  bool get isDeferred => deferredAt != null;

  BaDraftReason get reason {
    if (isComplete) return BaDraftReason.complete;
    if (!hasBefore && !hasAfter) return BaDraftReason.empty;
    if (!hasBefore) return BaDraftReason.missingBefore;
    if (!hasAfter) return BaDraftReason.missingAfter;
    return BaDraftReason.unlinked;
  }

  /// 캐러셀 노출 대상 — 미완성 draft만.
  bool get showsInCarousel =>
      status == BaCaptureStatus.draft && !isComplete;

  /// After 촬영 시 잔상 가이드로 넘길 Before URL.
  String? get ghostBeforeUrl => hasBefore ? beforeImageUrl : null;

  BaCaptureSession copyWith({
    String? id,
    String? beforeImageUrl,
    String? afterImageUrl,
    DateTime? beforeCapturedAt,
    DateTime? afterCapturedAt,
    String? customerId,
    String? chartId,
    String? label,
    BaCaptureStatus? status,
    DateTime? deferredAt,
    DateTime? linkedAt,
    DateTime? updatedAt,
  }) {
    return BaCaptureSession(
      id: id ?? this.id,
      shopId: shopId,
      sessionToken: sessionToken,
      authorId: authorId,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      beforeCapturedAt: beforeCapturedAt ?? this.beforeCapturedAt,
      afterCapturedAt: afterCapturedAt ?? this.afterCapturedAt,
      customerId: customerId ?? this.customerId,
      chartId: chartId ?? this.chartId,
      label: label ?? this.label,
      status: status ?? this.status,
      deferredAt: deferredAt ?? this.deferredAt,
      linkedAt: linkedAt ?? this.linkedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'author_id': DbMap.nullIfBlank(authorId),
      'session_token': sessionToken,
      'before_image_url': DbMap.nullIfBlank(beforeImageUrl),
      'after_image_url': DbMap.nullIfBlank(afterImageUrl),
      'before_captured_at': beforeCapturedAt?.toUtc().toIso8601String(),
      'after_captured_at': afterCapturedAt?.toUtc().toIso8601String(),
      'customer_id': DbMap.nullIfBlank(customerId),
      'chart_id': DbMap.nullIfBlank(chartId),
      'label': label,
      'status': status.dbValue,
      'deferred_at': deferredAt?.toUtc().toIso8601String(),
      'linked_at': linkedAt?.toUtc().toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  factory BaCaptureSession.fromMap(Map<String, dynamic> map) {
    return BaCaptureSession(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      sessionToken: DbMap.asText(map['session_token'] ?? map['sessionToken']),
      authorId: DbMap.asTextOrNull(map['author_id'] ?? map['authorId']),
      beforeImageUrl: DbMap.asTextOrNull(
        map['before_image_url'] ?? map['beforeImageUrl'],
      ),
      afterImageUrl: DbMap.asTextOrNull(
        map['after_image_url'] ?? map['afterImageUrl'],
      ),
      beforeCapturedAt: DbMap.asDateTime(
        map['before_captured_at'] ?? map['beforeCapturedAt'],
      )?.toLocal(),
      afterCapturedAt: DbMap.asDateTime(
        map['after_captured_at'] ?? map['afterCapturedAt'],
      )?.toLocal(),
      customerId: DbMap.asTextOrNull(map['customer_id'] ?? map['customerId']),
      chartId: DbMap.asTextOrNull(map['chart_id'] ?? map['chartId']),
      label: DbMap.asText(map['label']),
      status: BaCaptureStatus.fromDb(DbMap.asTextOrNull(map['status'])),
      deferredAt:
          DbMap.asDateTime(map['deferred_at'] ?? map['deferredAt'])?.toLocal(),
      linkedAt:
          DbMap.asDateTime(map['linked_at'] ?? map['linkedAt'])?.toLocal(),
      createdAt:
          DbMap.asDateTime(map['created_at'] ?? map['createdAt'])?.toLocal(),
      updatedAt:
          DbMap.asDateTime(map['updated_at'] ?? map['updatedAt'])?.toLocal(),
    );
  }

  /// 캐러셀 정렬 — 밀어둔 세션은 뒤로, 나머지는 최신순.
  static int carouselOrder(BaCaptureSession a, BaCaptureSession b) {
    if (a.isDeferred != b.isDeferred) return a.isDeferred ? 1 : -1;
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  }
}
