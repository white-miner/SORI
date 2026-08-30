/// Visit OS SSOT — Phase 1 "The Visit".
enum VisitPhase {
  shoot,
  consult,
  consent,
  publish,
  done;

  String get dbValue => name;

  String get label => switch (this) {
        VisitPhase.shoot => '촬영',
        VisitPhase.consult => '상담',
        VisitPhase.consent => '동의',
        VisitPhase.publish => '발행',
        VisitPhase.done => '완료',
      };

  static VisitPhase fromDb(String? raw) {
    return VisitPhase.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => VisitPhase.shoot,
    );
  }

  VisitPhase? get next {
    return switch (this) {
      VisitPhase.shoot => VisitPhase.consult,
      VisitPhase.consult => VisitPhase.consent,
      VisitPhase.consent => VisitPhase.publish,
      VisitPhase.publish => VisitPhase.done,
      VisitPhase.done => null,
    };
  }
}

class VisitSession {
  const VisitSession({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.customerName,
    required this.startedAt,
    this.chartDraftId,
    this.phase = VisitPhase.shoot,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String customerName;
  final String? chartDraftId;
  final VisitPhase phase;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  bool get isActive => phase != VisitPhase.done;

  bool isSameDay(DateTime day) {
    return startedAt.year == day.year &&
        startedAt.month == day.month &&
        startedAt.day == day.day;
  }

  VisitSession copyWith({
    String? chartDraftId,
    VisitPhase? phase,
    DateTime? completedAt,
  }) {
    return VisitSession(
      id: id,
      shopId: shopId,
      customerId: customerId,
      customerName: customerName,
      chartDraftId: chartDraftId ?? this.chartDraftId,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'customer_name': customerName,
      'chart_draft_id': chartDraftId,
      'phase': phase.dbValue,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  factory VisitSession.fromMap(Map<String, dynamic> map) {
    final startedRaw = map['started_at']?.toString() ?? '';
    final completedRaw = map['completed_at']?.toString();
    return VisitSession(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      chartDraftId: map['chart_draft_id']?.toString(),
      phase: VisitPhase.fromDb(map['phase']?.toString()),
      startedAt: DateTime.tryParse(startedRaw)?.toLocal() ?? DateTime.now(),
      completedAt: completedRaw == null
          ? null
          : DateTime.tryParse(completedRaw)?.toLocal(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

/// Visit Launcher — 오늘 방문 세션 집계.
class VisitDaySnapshot {
  const VisitDaySnapshot({
    required this.day,
    required this.sessions,
    required this.activeCount,
    required this.completedCount,
  });

  final DateTime day;
  final List<VisitSession> sessions;
  final int activeCount;
  final int completedCount;

  double get progressRatio {
    if (sessions.isEmpty) return 0;
    return completedCount / sessions.length;
  }
}
