import '../../utils/db_map.dart';
import 'care_program_template.dart';

enum VisitTimerStatus {
  idle,
  consulting,
  prep,
  care,
  careOvertime,
  postCare,
  done;

  String get dbValue => switch (this) {
        VisitTimerStatus.idle => 'idle',
        VisitTimerStatus.consulting => 'consulting',
        VisitTimerStatus.prep => 'prep',
        VisitTimerStatus.care => 'care',
        VisitTimerStatus.careOvertime => 'care_overtime',
        VisitTimerStatus.postCare => 'post_care',
        VisitTimerStatus.done => 'done',
      };

  static VisitTimerStatus fromDb(String? raw) => switch (raw) {
        'consulting' => VisitTimerStatus.consulting,
        'prep' => VisitTimerStatus.prep,
        'care' => VisitTimerStatus.care,
        'care_overtime' => VisitTimerStatus.careOvertime,
        'post_care' => VisitTimerStatus.postCare,
        'done' => VisitTimerStatus.done,
        _ => VisitTimerStatus.idle,
      };
}

class VisitTimerStepResult {
  const VisitTimerStepResult({
    required this.label,
    required this.plannedMinutes,
    required this.actualSeconds,
    this.startedAt,
    this.endedAt,
  });

  final String label;
  final int plannedMinutes;
  final int actualSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, dynamic> toJson() => {
        'label': label,
        'planned_minutes': plannedMinutes,
        'actual_seconds': actualSeconds,
        if (startedAt != null)
          'started_at': startedAt!.toUtc().toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
      };

  factory VisitTimerStepResult.fromJson(Map<String, dynamic> json) {
    return VisitTimerStepResult(
      label: DbMap.asText(json['label']),
      plannedMinutes: DbMap.asInt(json['planned_minutes'], 0),
      actualSeconds: DbMap.asInt(json['actual_seconds'], 0),
      startedAt: DbMap.asDateTime(json['started_at']),
      endedAt: DbMap.asDateTime(json['ended_at']),
    );
  }
}

class VisitOperationTimer {
  const VisitOperationTimer({
    required this.id,
    required this.visitSessionId,
    required this.shopId,
    this.templateId,
    this.templateSnapshot = const [],
    this.consultationStartedAt,
    this.chartActiveSeconds = 0,
    this.chartOpenedAt,
    this.careStartedAt,
    this.careEndedAt,
    this.visitEndedAt,
    this.currentStepIndex = 0,
    this.currentStepStartedAt,
    this.stepResults = const [],
    this.afterPhotoCaptured = false,
    this.status = VisitTimerStatus.idle,
    this.updatedAt,
  });

  final String id;
  final String visitSessionId;
  final String shopId;
  final String? templateId;
  final List<CareProgramStep> templateSnapshot;
  final DateTime? consultationStartedAt;
  final int chartActiveSeconds;
  final DateTime? chartOpenedAt;
  final DateTime? careStartedAt;
  final DateTime? careEndedAt;
  final DateTime? visitEndedAt;
  final int currentStepIndex;
  final DateTime? currentStepStartedAt;
  final List<VisitTimerStepResult> stepResults;
  final bool afterPhotoCaptured;
  final VisitTimerStatus status;
  final DateTime? updatedAt;

  bool get canEndCare =>
      status == VisitTimerStatus.careOvertime ||
      (status == VisitTimerStatus.care &&
          templateSnapshot.isNotEmpty &&
          currentStepIndex >= templateSnapshot.length);

  VisitOperationTimer copyWith({
    String? id,
    String? visitSessionId,
    String? shopId,
    String? templateId,
    List<CareProgramStep>? templateSnapshot,
    DateTime? consultationStartedAt,
    int? chartActiveSeconds,
    DateTime? chartOpenedAt,
    bool clearChartOpenedAt = false,
    DateTime? careStartedAt,
    bool clearCareStartedAt = false,
    DateTime? careEndedAt,
    bool clearCareEndedAt = false,
    DateTime? visitEndedAt,
    int? currentStepIndex,
    DateTime? currentStepStartedAt,
    bool clearCurrentStepStartedAt = false,
    List<VisitTimerStepResult>? stepResults,
    bool? afterPhotoCaptured,
    VisitTimerStatus? status,
    DateTime? updatedAt,
  }) {
    return VisitOperationTimer(
      id: id ?? this.id,
      visitSessionId: visitSessionId ?? this.visitSessionId,
      shopId: shopId ?? this.shopId,
      templateId: templateId ?? this.templateId,
      templateSnapshot: templateSnapshot ?? this.templateSnapshot,
      consultationStartedAt:
          consultationStartedAt ?? this.consultationStartedAt,
      chartActiveSeconds: chartActiveSeconds ?? this.chartActiveSeconds,
      chartOpenedAt:
          clearChartOpenedAt ? null : (chartOpenedAt ?? this.chartOpenedAt),
      careStartedAt:
          clearCareStartedAt ? null : (careStartedAt ?? this.careStartedAt),
      careEndedAt: clearCareEndedAt ? null : (careEndedAt ?? this.careEndedAt),
      visitEndedAt: visitEndedAt ?? this.visitEndedAt,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentStepStartedAt: clearCurrentStepStartedAt
          ? null
          : (currentStepStartedAt ?? this.currentStepStartedAt),
      stepResults: stepResults ?? this.stepResults,
      afterPhotoCaptured: afterPhotoCaptured ?? this.afterPhotoCaptured,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'visit_session_id': visitSessionId,
        'shop_id': shopId,
        if (templateId != null) 'template_id': templateId,
        'template_snapshot':
            templateSnapshot.map((s) => s.toJson()).toList(),
        if (consultationStartedAt != null)
          'consultation_started_at':
              consultationStartedAt!.toUtc().toIso8601String(),
        'chart_active_seconds': chartActiveSeconds,
        if (careStartedAt != null)
          'care_started_at': careStartedAt!.toUtc().toIso8601String(),
        if (careEndedAt != null)
          'care_ended_at': careEndedAt!.toUtc().toIso8601String(),
        if (visitEndedAt != null)
          'visit_ended_at': visitEndedAt!.toUtc().toIso8601String(),
        'current_step_index': currentStepIndex,
        'step_results': stepResults.map((s) => s.toJson()).toList(),
        'after_photo_captured': afterPhotoCaptured,
        'status': status.dbValue,
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  Map<String, dynamic> toLocalJson() => {
        ...toMap(),
        if (chartOpenedAt != null)
          'chart_opened_at': chartOpenedAt!.toUtc().toIso8601String(),
        if (currentStepStartedAt != null)
          'current_step_started_at':
              currentStepStartedAt!.toUtc().toIso8601String(),
      };

  factory VisitOperationTimer.fromMap(Map<String, dynamic> map) {
    final snapRaw = map['template_snapshot'];
    final snapshot = <CareProgramStep>[];
    if (snapRaw is List) {
      for (final item in snapRaw) {
        if (item is Map) {
          snapshot.add(
            CareProgramStep.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final resultsRaw = map['step_results'];
    final results = <VisitTimerStepResult>[];
    if (resultsRaw is List) {
      for (final item in resultsRaw) {
        if (item is Map) {
          results.add(
            VisitTimerStepResult.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return VisitOperationTimer(
      id: DbMap.asText(map['id']),
      visitSessionId: DbMap.asText(map['visit_session_id']),
      shopId: DbMap.asText(map['shop_id']),
      templateId: DbMap.asTextOrNull(map['template_id']),
      templateSnapshot: snapshot,
      consultationStartedAt: DbMap.asDateTime(map['consultation_started_at']),
      chartActiveSeconds: DbMap.asInt(map['chart_active_seconds'], 0),
      chartOpenedAt: DbMap.asDateTime(map['chart_opened_at']),
      careStartedAt: DbMap.asDateTime(map['care_started_at']),
      careEndedAt: DbMap.asDateTime(map['care_ended_at']),
      visitEndedAt: DbMap.asDateTime(map['visit_ended_at']),
      currentStepIndex: DbMap.asInt(map['current_step_index'], 0),
      currentStepStartedAt:
          DbMap.asDateTime(map['current_step_started_at']),
      stepResults: results,
      afterPhotoCaptured: DbMap.asBool(map['after_photo_captured']),
      status: VisitTimerStatus.fromDb(map['status']?.toString()),
      updatedAt: DbMap.asDateTime(map['updated_at']),
    );
  }
}

class VisitTimerLiveSnapshot {
  const VisitTimerLiveSnapshot({
    required this.totalSeconds,
    required this.chartSeconds,
    required this.careSeconds,
    required this.currentStepRemainingSeconds,
    required this.currentStepLabel,
    required this.isOvertime,
  });

  final int totalSeconds;
  final int chartSeconds;
  final int careSeconds;
  final int currentStepRemainingSeconds;
  final String currentStepLabel;
  final bool isOvertime;

  static VisitTimerLiveSnapshot compute(
    VisitOperationTimer timer, {
    DateTime? now,
  }) {
    final tick = now ?? DateTime.now();
    final started = timer.consultationStartedAt;
    final total = started == null
        ? 0
        : (timer.visitEndedAt ?? tick).difference(started).inSeconds;

    var chart = timer.chartActiveSeconds;
    if (timer.chartOpenedAt != null &&
        timer.status == VisitTimerStatus.consulting) {
      chart += tick.difference(timer.chartOpenedAt!).inSeconds;
    }

    var care = 0;
    if (timer.careStartedAt != null) {
      final end = timer.careEndedAt ?? tick;
      care = end.difference(timer.careStartedAt!).inSeconds;
    }

    var stepRemaining = 0;
    var stepLabel = '';
    var overtime = timer.status == VisitTimerStatus.careOvertime;

    if (timer.status == VisitTimerStatus.care &&
        timer.currentStepIndex < timer.templateSnapshot.length) {
      final step = timer.templateSnapshot[timer.currentStepIndex];
      stepLabel = step.label;
      final stepStart = timer.currentStepStartedAt ?? timer.careStartedAt;
      if (stepStart != null) {
        final elapsed = tick.difference(stepStart).inSeconds;
        stepRemaining = (step.seconds - elapsed).clamp(0, step.seconds);
      }
    } else if (timer.status == VisitTimerStatus.careOvertime) {
      stepLabel = '오버타임';
      overtime = true;
    }

    return VisitTimerLiveSnapshot(
      totalSeconds: total.clamp(0, 86400),
      chartSeconds: chart.clamp(0, 86400),
      careSeconds: care.clamp(0, 86400),
      currentStepRemainingSeconds: stepRemaining,
      currentStepLabel: stepLabel,
      isOvertime: overtime,
    );
  }

  String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rm = m % 60;
      return '${h}h ${rm.toString().padLeft(2, '0')}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String buildReportBlock() {
    final buf = StringBuffer('--- 케어 시간 리포트 (SORI) ---\n');
    buf.writeln('총 방문: ${formatDuration(totalSeconds)}');
    buf.writeln('차트 작성: ${formatDuration(chartSeconds)}');
    buf.writeln('케어: ${formatDuration(careSeconds)}');
    return buf.toString();
  }
}
