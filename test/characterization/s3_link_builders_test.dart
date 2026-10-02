// S3-0 특성 테스트: 고객에게 보내는 링크(케어 리포트, 후기)를 만드는 방식.
//
// 지금은 chartId / 클라이언트가 만든 feedbackToken 을 URL에 그대로 넣고,
// 케어 리포트 URL을 방문 리포트 JSON(care_report_json)에도 저장한다.
// 보안 S3 PR 3-4에서 create_customer_link 토큰으로 바뀌면 이 기대값을 그 PR에서 고친다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/report/visit_care_report.dart';
import 'package:sori/features/visit/report/visit_care_report_generator.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/kakao_alimtalk_actions.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

const _chartId = '418de1ef-0000-4000-8000-000000000001';

void main() {
  group('S3-0 링크 빌더 특성', () {
    test('케어 리포트 URL은 해시 라우팅 + chartId 경로다', () {
      final url = SoriStore.buildCareReportUrl(_chartId);
      expect(url, endsWith('#/care-report/$_chartId'));
      // 앞부분은 앱 진입 URL과 같은 base 를 쓴다.
      final entry = SoriStore.buildAppEntryUrl();
      expect(entry, endsWith('#/'));
      expect(url, startsWith(entry.substring(0, entry.length - 2)));
    });

    test('케어 리포트 URL: chartId 앞뒤 공백은 지우고 경로 성분으로 인코딩한다', () {
      expect(
        SoriStore.buildCareReportUrl('  $_chartId  '),
        SoriStore.buildCareReportUrl(_chartId),
      );
      expect(
        SoriStore.buildCareReportUrl('a b/c'),
        endsWith('#/care-report/a%20b%2Fc'),
      );
    });

    test('후기 URL은 #/review?token= 에 토큰을 쿼리 인코딩해 넣는다', () {
      expect(
        SoriStore.buildCustomerReviewUrl('tok-123'),
        endsWith('#/review?token=tok-123'),
      );
      expect(
        SoriStore.buildCustomerReviewUrl('a b&c=d'),
        endsWith('#/review?token=a+b%26c%3Dd'),
      );
    });

    test('후기 토큰은 방문 확인 때 클라이언트에서 만들어 차트에 붙는다', () {
      final store = SoriStore();
      final chart = store.saveChartAndConfirmVisit(
        customerId: '1',
        visitNumber: 2,
        customChartNo: 'S3-LINK',
        careName: '재생케어',
        treatmentSummary: '2회차',
        directorInsight: '안정',
        concernChips: const ['건조/장벽'],
        firstVisitFearChips: const [],
        revisitFeedbackChips: const [],
      );
      final token = chart.feedbackToken;
      expect(token, isNotNull);
      expect(token, isNotEmpty);
      expect(store.findChartByToken(token!)?.id, chart.id);
      expect(SoriStore.buildCustomerReviewUrl(token), contains(token));
    });

    test('케어 리포트 알림톡 본문은 chartId URL을 마지막 줄에 넣는다', () {
      const chart = CustomerChart(
        id: _chartId,
        shopId: 'shop-demo',
        customerId: '1',
        visitNumber: 3,
        careName: ' 수분케어 ',
      );
      final body = buildCareReportAlimtalkBody(
        chart: chart,
        customerName: '김민지',
        shopName: 'SORI 에스테틱',
      );
      expect(body, startsWith('김민지 고객님, 오늘 수분케어 잘 받으셨죠?'));
      expect(body, contains('SORI 에스테틱에서 준비한 케어 리포트'));
      expect(body.split('\n').last, SoriStore.buildCareReportUrl(_chartId));
    });

    test('케어명이 비면 알림톡 본문은 "오늘의 케어"를 쓴다', () {
      const chart = CustomerChart(
        id: _chartId,
        shopId: 'shop-demo',
        customerId: '1',
        visitNumber: 1,
      );
      final body = buildCareReportAlimtalkBody(
        chart: chart,
        customerName: '고객',
        shopName: '샵',
      );
      expect(body, contains('오늘 오늘의 케어 잘 받으셨죠?'));
    });

    test('방문 리포트 생성기는 chartId URL을 publicReportUrl 과 JSON에 저장한다', () {
      final now = DateTime.now();
      final session = VisitSession(
        id: 'vs-s3',
        shopId: 'shop-demo',
        customerId: '1',
        customerName: '김민지',
        phase: VisitPhase.consult,
        startedAt: now.subtract(const Duration(hours: 1)),
      );
      final timer = VisitOperationTimer(
        id: 't-s3',
        visitSessionId: 'vs-s3',
        shopId: 'shop-demo',
        consultationStartedAt: now.subtract(const Duration(hours: 1)),
        careStartedAt: now.subtract(const Duration(minutes: 40)),
        careEndedAt: now,
        status: VisitTimerStatus.postCare,
      );
      const chart = CustomerChart(
        id: _chartId,
        shopId: 'shop-demo',
        customerId: '1',
        visitNumber: 2,
        careName: '재생케어',
      );

      final report = VisitCareReportGenerator.generate(
        session: session,
        timer: timer,
        chart: chart,
        shopName: 'SORI 에스테틱',
        customerName: '김민지',
        presetName: '',
      );

      expect(report, isNotNull);
      final expected = SoriStore.buildCareReportUrl(_chartId);
      expect(report!.publicReportUrl, expected);
      expect(report.toJson()['public_report_url'], expected);
      expect(report.kakaoLongMessage, contains(expected));
      expect(
        VisitCareReport.fromJson(report.toJson()).publicReportUrl,
        expected,
      );
    });
  });
}
