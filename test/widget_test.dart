import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/visit_trigger_service.dart';
import 'package:sori/views/admin_chart_page.dart';
import 'package:sori/views/customer_review_page.dart';
import 'package:sori/views/my_app.dart';

void main() {
  testWidgets('Entry home shows role split CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('원장님으로 시작하기'), findsOneWidget);
    expect(find.text('고객 1:1 피부 일지'), findsOneWidget);
  });

  testWidgets('Admin chart has no psychology CTAs', (WidgetTester tester) async {
    final store = SoriStore();
    store.confirmVisit(chartId: 'chart-1');

    await tester.pumpWidget(
      MaterialApp(
        home: AdminChartPage(store: store, customerId: '1'),
      ),
    );
    await tester.pump();

    expect(find.text('새 차트 작성'), findsOneWidget);
    expect(find.text('후기 수락하기'), findsNothing);
    expect(find.text('수정하기'), findsNothing);
    expect(find.text('답글 피드백 요청'), findsNothing);
  });

  testWidgets('Customer review requires last-4 then shows psychology CTAs',
      (WidgetTester tester) async {
    final store = SoriStore();
    final opened = store.confirmVisit(chartId: 'chart-1');

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerReviewPage(
          store: store,
          token: opened.feedbackToken!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('본인 확인'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5678');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('후기 수락하기'), findsOneWidget);
    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('답글 피드백 요청'), findsOneWidget);
    expect(find.text('차트 관리'), findsNothing);
    expect(find.text('1-Click 전체 발송 승인하기'), findsNothing);
  });

  test('phone matching and last4 verification', () {
    final store = SoriStore();
    expect(store.findCustomerByPhone('01012345678')?.name, '김민지');
    expect(store.verifyPhoneLast4(expectedPhone: '010-1234-5678', inputLast4: '5678'), isTrue);
    expect(store.verifyPhoneLast4(expectedPhone: '010-1234-5678', inputLast4: '0000'), isFalse);
  });

  test('saveChartAndConfirmVisit creates hash-friendly token link', () {
    final store = SoriStore();
    final chart = store.saveChartAndConfirmVisit(
      customerId: '1',
      visitNumber: 2,
      customChartNo: 'EXT-2',
      careName: '재생케어',
      treatmentSummary: '2회차',
      directorInsight: '안정',
      concernChips: const ['건조/장벽'],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const ['시술 후 건조함'],
    );
    expect(chart.visitChecked, isTrue);
    expect(chart.customChartNo, 'EXT-2');
    expect(chart.feedbackToken, isNotNull);
    expect(SoriStore.buildCustomerReviewUrl(chart.feedbackToken!), contains('#/review?token='));
  });

  test('VisitTriggerService generates token on check', () {
    final service = VisitTriggerService();
    const chart = CustomerChart(
      id: 'chart',
      shopId: 'shop',
      customerId: 'cust',
      visitNumber: 2,
    );
    final opened = service.markVisitChecked(chart);
    expect(opened.visitChecked, isTrue);
    expect(opened.feedbackToken!.length, greaterThanOrEqualTo(16));
  });
}
