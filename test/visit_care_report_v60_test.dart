import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/report/visit_care_report.dart';
import 'package:sori/features/visit/report/visit_care_report_generator.dart';
import 'package:sori/features/visit/report/visit_report_narrative_engine.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

void main() {
  group('VisitReportNarrativeEngine v6.0', () {
    test('renders warm copy with overtime minutes', () {
      final draft = VisitCareReport(
        visitSessionId: 's1',
        chartId: 'c1',
        customerId: 'cu1',
        customerName: '김민정',
        shopName: '테라노바 경주',
        presetName: '복부 슬리밍',
        visitDate: DateTime(2026, 9, 1),
        totalVisitSeconds: 87 * 60,
        consultationSeconds: 25 * 60,
        chartSeconds: 0,
        careSeconds: 62 * 60,
        plannedCareSeconds: 54 * 60,
        overtimeSeconds: 8 * 60,
        steps: const [
          VisitCareStepLine(
            label: '마무리 림프',
            plannedMinutes: 12,
            actualSeconds: 20 * 60,
            deltaSeconds: 8 * 60,
          ),
        ],
        hadOvertime: true,
        afterPhotoCaptured: true,
        publicReportUrl: 'https://example.com/report',
        kakaoShortMessage: '',
        kakaoLongMessage: '',
        internalAuditBlock: '',
      );

      final out = VisitReportNarrativeEngine.render(
        draft,
        lastStepLabel: '마무리 림프',
      );

      expect(out.kakaoShortMessage, contains('김민정님'));
      expect(out.kakaoShortMessage, contains('총 87분'));
      expect(out.kakaoShortMessage, contains('62분'));
      expect(out.kakaoShortMessage, contains('8분의 정성'));
      expect(out.kakaoShortMessage, isNot(contains('차트')));
      expect(out.kakaoLongMessage, contains('https://example.com/report'));
      expect(out.internalAuditBlock, contains('정성 시간'));
    });

    test('allows send when after photo missing (Q3)', () {
      final draft = VisitCareReport(
        visitSessionId: 's1',
        chartId: 'c1',
        customerId: 'cu1',
        customerName: '이수진',
        shopName: 'SORI',
        presetName: '케어',
        visitDate: DateTime.now(),
        totalVisitSeconds: 3600,
        consultationSeconds: 600,
        chartSeconds: 600,
        careSeconds: 2400,
        plannedCareSeconds: 2400,
        overtimeSeconds: 0,
        steps: const [],
        hadOvertime: false,
        afterPhotoCaptured: false,
        publicReportUrl: 'https://x',
        kakaoShortMessage: '',
        kakaoLongMessage: '',
        internalAuditBlock: '',
      );

      final out = VisitReportNarrativeEngine.render(
        draft,
        lastStepLabel: '마무리',
      );
      expect(out.kakaoShortMessage, contains('애프터 사진'));
      expect(out.kakaoLongMessage, isNotEmpty);
    });
  });

  group('VisitCareReportGenerator v6.0', () {
    test('skips standalone timers (Q5)', () {
      final session = VisitSession(
        id: 'vs1',
        shopId: 'shop',
        customerId: 'cu',
        customerName: '테스트',
        phase: VisitPhase.consult,
        startedAt: DateTime.now(),
      );
      final timer = VisitOperationTimer(
        id: 't1',
        visitSessionId: '',
        shopId: 'shop',
        utilitySource: 'standalone_timer',
        consultationStartedAt: DateTime.now().subtract(const Duration(hours: 1)),
        careStartedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        careEndedAt: DateTime.now(),
        status: VisitTimerStatus.postCare,
      );
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop',
        customerId: 'cu',
        visitNumber: 1,
      );

      expect(
        VisitCareReportGenerator.generate(
          session: session,
          timer: timer,
          chart: chart,
          shopName: 'SORI',
          customerName: '테스트',
          presetName: '케어',
        ),
        isNull,
      );
    });

    test('json round-trip preserves overtime', () {
      final report = VisitCareReport(
        visitSessionId: 's1',
        chartId: 'c1',
        customerId: 'cu1',
        customerName: '박지',
        shopName: 'SORI',
        presetName: '케어',
        visitDate: DateTime(2026, 9, 1, 14),
        totalVisitSeconds: 5400,
        consultationSeconds: 900,
        chartSeconds: 600,
        careSeconds: 3900,
        plannedCareSeconds: 3600,
        overtimeSeconds: 300,
        steps: const [],
        hadOvertime: true,
        afterPhotoCaptured: true,
        publicReportUrl: 'https://x',
        kakaoShortMessage: 'short',
        kakaoLongMessage: 'long',
        internalAuditBlock: 'audit',
      );
      final decoded = VisitCareReport.fromJson(report.toJson());
      expect(decoded.overtimeSeconds, 300);
      expect(decoded.careMinutes, 65);
    });
  });
}
