import 'visit_care_report.dart';
import 'visit_care_report_generator.dart';

/// PRD v6.0 — warm customer-facing copy from timer SSOT.
abstract final class VisitReportNarrativeEngine {
  static VisitCareReport render(
    VisitCareReport draft, {
    required String lastStepLabel,
  }) {
    final customer = draft.customerName.trim();
    final honorific = customer.endsWith('님') ? customer : '$customer님';

    final short = _buildShortMessage(
      draft: draft,
      honorific: honorific,
      lastStepLabel: lastStepLabel,
    );
    final long = _buildLongMessage(
      draft: draft,
      honorific: honorific,
      lastStepLabel: lastStepLabel,
    );
    final audit = _buildInternalAuditBlock(draft);

    return VisitCareReport(
      visitSessionId: draft.visitSessionId,
      chartId: draft.chartId,
      customerId: draft.customerId,
      customerName: draft.customerName,
      shopName: draft.shopName,
      presetName: draft.presetName,
      visitDate: draft.visitDate,
      visitNumber: draft.visitNumber,
      totalVisitSeconds: draft.totalVisitSeconds,
      consultationSeconds: draft.consultationSeconds,
      chartSeconds: draft.chartSeconds,
      careSeconds: draft.careSeconds,
      plannedCareSeconds: draft.plannedCareSeconds,
      overtimeSeconds: draft.overtimeSeconds,
      steps: draft.steps,
      hadOvertime: draft.hadOvertime,
      afterPhotoCaptured: draft.afterPhotoCaptured,
      publicReportUrl: draft.publicReportUrl,
      kakaoShortMessage: short,
      kakaoLongMessage: long,
      internalAuditBlock: audit,
    );
  }

  static String _buildShortMessage({
    required VisitCareReport draft,
    required String honorific,
    required String lastStepLabel,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      '$honorific, 오늘 ${draft.shopName}에서 ${draft.presetName} 케어 잘 받으셨습니다.',
    );
    buf.writeln();
    buf.writeln(
      '오늘 $honorific을 위해 총 ${draft.totalVisitMinutes}분의 시간을 들여 '
      '꼼꼼히 케어해 드렸어요.',
    );

    if (draft.hadOvertime && draft.overtimeMinutes > 0) {
      buf.writeln(
        '케어 본 시간은 ${draft.careMinutes}분이었고, '
        '특히 마지막 $lastStepLabel에 ${draft.overtimeMinutes}분의 정성을 더 담았습니다.',
      );
    } else {
      buf.writeln(
        '베드에서 ${draft.careMinutes}분 동안 각 단계를 세심하게 진행했습니다.',
      );
    }

    if (!draft.afterPhotoCaptured) {
      buf.writeln();
      buf.writeln('※ 오늘 애프터 사진은 다음 방문 시 함께 기록해 드릴게요.');
    }

    return buf.toString().trim();
  }

  static String _buildLongMessage({
    required VisitCareReport draft,
    required String honorific,
    required String lastStepLabel,
  }) {
    final buf = StringBuffer(_buildShortMessage(
      draft: draft,
      honorific: honorific,
      lastStepLabel: lastStepLabel,
    ));
    buf.writeln();
    buf.writeln();
    buf.writeln(
      '아래 링크에서 오늘 케어 리포트와 B/A 사진, 3일 홈케어 가이드를 확인해 보세요.',
    );
    buf.writeln(draft.publicReportUrl);
    return buf.toString().trim();
  }

  static String _buildInternalAuditBlock(VisitCareReport draft) {
    final buf = StringBuffer('--- 케어 시간 리포트 (SORI) ---\n');
    buf.writeln('총 방문: ${formatReportDuration(draft.totalVisitSeconds)}');
    buf.writeln(
      '상담: ${formatReportDuration(draft.consultationSeconds)} | '
      '차트: ${formatReportDuration(draft.chartSeconds)} | '
      '케어: ${formatReportDuration(draft.careSeconds)}',
    );
    buf.writeln('프리셋: ${draft.presetName}');
    for (final step in draft.steps) {
      buf.writeln(
        '· ${step.label}: ${formatReportDuration(step.actualSeconds)} '
        '(예정 ${step.plannedMinutes}분)',
      );
    }
    if (draft.overtimeSeconds > 0) {
      buf.writeln(
        '· 정성 시간: ${formatReportDuration(draft.overtimeSeconds)}',
      );
    } else if (draft.hadOvertime) {
      buf.writeln('· 정성 오버타임 포함');
    }
    buf.write(
      draft.afterPhotoCaptured ? '애프터: 촬영완료' : '애프터: 미촬영',
    );
    return buf.toString();
  }
}
