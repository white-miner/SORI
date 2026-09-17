import '../../../models/customer.dart';
import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../../visit_kernel/visit_store.dart';
import '../../operation/visit_timer_store.dart';
import 'visit_care_report.dart';
import 'visit_care_report_generator.dart';

/// PRD v6.0 — orchestrates visit end → report persist → session complete.
class VisitEndPipelineResult {
  const VisitEndPipelineResult({
    this.report,
    this.skippedReason,
  });

  final VisitCareReport? report;
  final String? skippedReason;

  bool get hasReport => report != null;
}

class VisitEndPipeline {
  const VisitEndPipeline({
    required this.store,
    required this.visitStore,
    required this.timerStore,
  });

  final SoriStore store;
  final VisitStore visitStore;
  final VisitTimerStore timerStore;

  Future<VisitEndPipelineResult> run({
    required VisitSession session,
  }) async {
    final timer = timerStore.active;
    if (timer == null || timer.isStandalone) {
      await _legacyEndWithoutReport(session);
      return const VisitEndPipelineResult(
        skippedReason: 'standalone_or_no_timer',
      );
    }

    if (timer.visitSessionId.trim() != session.id.trim()) {
      await _legacyEndWithoutReport(session);
      return const VisitEndPipelineResult(
        skippedReason: 'timer_session_mismatch',
      );
    }

    final chart = store.chartForVisitSession(session);
    if (chart == null) {
      await _legacyEndWithoutReport(session);
      return const VisitEndPipelineResult(skippedReason: 'no_chart');
    }

    final customer = store.findCustomer(chart.customerId);
    final preset = timerStore.presetAt(timerStore.selectedPresetSlot);
    final presetName = preset.isEmpty ? chart.careName : preset.name;

    final report = VisitCareReportGenerator.generate(
      session: session,
      timer: timer,
      chart: chart,
      shopName: store.shop.name,
      customerName: _customerDisplayName(customer, session),
      presetName: presetName,
    );

    if (report == null) {
      await _legacyEndWithoutReport(session);
      return const VisitEndPipelineResult(skippedReason: 'generate_failed');
    }

    final summary = chart.treatmentSummary.trim();
    final nextSummary = summary.isEmpty
        ? report.internalAuditBlock
        : '${summary}\n\n${report.internalAuditBlock}';

    await store.updateCustomerChartFields(
      chartId: chart.id,
      treatmentSummary: nextSummary,
      careReportJson: report.toJson(),
      careReportGeneratedAt: DateTime.now(),
    );

    await timerStore.endVisitWithOvertime(
      overtimeSeconds: report.overtimeSeconds,
    );
    await visitStore.completeVisit(session.id);

    return VisitEndPipelineResult(report: report);
  }

  Future<void> _legacyEndWithoutReport(VisitSession session) async {
    final audit = await timerStore.buildReportBlock();
    final chart = store.chartForVisitSession(session);
    if (chart != null && audit.isNotEmpty) {
      final summary = chart.treatmentSummary.trim();
      final next = summary.isEmpty ? audit : '$summary\n\n$audit';
      await store.updateCustomerChartFields(
        chartId: chart.id,
        treatmentSummary: next,
      );
    }
    await timerStore.endVisit();
    await visitStore.completeVisit(session.id);
  }

  static String _customerDisplayName(Customer? customer, VisitSession session) {
    final fromCustomer = customer?.name.trim() ?? '';
    if (fromCustomer.isNotEmpty) return fromCustomer;
    return session.customerName.trim().isEmpty
        ? '고객'
        : session.customerName.trim();
  }
}
