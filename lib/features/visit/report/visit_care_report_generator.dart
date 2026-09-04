import '../../../models/customer_chart.dart';
import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import 'visit_care_report.dart';
import 'visit_report_narrative_engine.dart';

/// PRD v6.0 — aggregates timer + chart data into VisitCareReport.
abstract final class VisitCareReportGenerator {
  static VisitCareReport? generate({
    required VisitSession session,
    required VisitOperationTimer timer,
    required CustomerChart chart,
    required String shopName,
    required String customerName,
    required String presetName,
  }) {
    if (timer.isStandalone) return null;
    if (timer.visitSessionId.trim().isEmpty) return null;

    final endAt = DateTime.now();
    final snap = VisitTimerLiveSnapshot.compute(timer, now: endAt);

    var plannedCareSeconds = 0;
    for (final step in timer.templateSnapshot) {
      plannedCareSeconds += step.seconds;
    }

    final overtimeSeconds =
        (snap.careSeconds - plannedCareSeconds).clamp(0, 86400);
    final consultationSeconds = (snap.totalSeconds -
            snap.chartSeconds -
            snap.careSeconds)
        .clamp(0, 86400);

    final steps = <VisitCareStepLine>[
      for (final r in timer.stepResults)
        VisitCareStepLine(
          label: r.label,
          plannedMinutes: r.plannedMinutes,
          actualSeconds: r.actualSeconds,
          deltaSeconds: r.actualSeconds - (r.plannedMinutes * 60),
        ),
    ];

    final lastStepLabel =
        steps.isNotEmpty ? steps.last.label.trim() : '마무리';

    final reportUrl = SoriStore.buildCareReportUrl(chart.id);
    final careLabel = presetName.trim().isEmpty
        ? (chart.careName.trim().isEmpty ? '오늘의 케어' : chart.careName.trim())
        : presetName.trim();

    final draft = VisitCareReport(
      visitSessionId: session.id,
      chartId: chart.id,
      customerId: chart.customerId,
      customerName: customerName.trim(),
      shopName: shopName.trim(),
      presetName: careLabel,
      visitDate: endAt,
      visitNumber: chart.visitNumber,
      totalVisitSeconds: snap.totalSeconds,
      consultationSeconds: consultationSeconds,
      chartSeconds: snap.chartSeconds,
      careSeconds: snap.careSeconds,
      plannedCareSeconds: plannedCareSeconds,
      overtimeSeconds: overtimeSeconds,
      steps: steps,
      hadOvertime: overtimeSeconds > 0 || snap.isOvertime,
      afterPhotoCaptured: timer.afterPhotoCaptured,
      publicReportUrl: reportUrl,
      kakaoShortMessage: '',
      kakaoLongMessage: '',
      internalAuditBlock: '',
    );

    return VisitReportNarrativeEngine.render(
      draft,
      lastStepLabel: lastStepLabel,
    );
  }
}

/// Format seconds for audit blocks (reuse timer SSOT style).
String formatReportDuration(int seconds) {
  const snap = VisitTimerLiveSnapshot(
    totalSeconds: 0,
    chartSeconds: 0,
    careSeconds: 0,
    currentStepRemainingSeconds: 0,
    currentStepLabel: '',
    isOvertime: false,
    planRemainingSeconds: 0,
    overtimeElapsedSeconds: 0,
  );
  return snap.formatDuration(seconds);
}
