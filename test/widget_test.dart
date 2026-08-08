import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/visit_trigger_service.dart';
import 'package:sori/views/admin_chart_page.dart';
import 'package:sori/views/customer_review_page.dart';
import 'package:sori/views/my_app.dart';

void main() {
  testWidgets('Admin dashboard shows pending message count', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('1-Click 전체 발송 승인하기'), findsOneWidget);
    expect(find.text('발송 대기 메시지'), findsOneWidget);
    expect(find.text('김민지'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches to customer list', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('고객 관리'));
    await tester.pumpAndSettle();

    expect(find.text('고객 관리'), findsWidgets);
    expect(find.text('이수진'), findsOneWidget);
    expect(find.text('박서연'), findsOneWidget);
  });

  testWidgets('Admin chart shows link actions only, not psychology CTAs',
      (WidgetTester tester) async {
    final store = SoriStore();
    store.confirmVisit(chartId: 'chart-1');

    await tester.pumpWidget(
      MaterialApp(
        home: AdminChartPage(store: store, customerId: '1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('링크 복사'), findsOneWidget);
    expect(find.text('문자 발송'), findsOneWidget);
    expect(find.text('후기 수락하기'), findsNothing);
    expect(find.text('수정하기'), findsNothing);
    expect(find.text('답글 피드백 요청'), findsNothing);
  });

  testWidgets('Customer review page shows psychology CTAs without admin menu',
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
    await tester.pumpAndSettle();

    expect(find.text('후기 수락하기'), findsOneWidget);
    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('답글 피드백 요청'), findsOneWidget);
    expect(find.text('고객 관리'), findsNothing);
    expect(find.text('1-Click 전체 발송 승인하기'), findsNothing);
    expect(find.textContaining('진단 리포트'), findsOneWidget);
  });

  test('visit_checked opens feedback token without payment', () {
    final store = SoriStore();
    final chart = store.latestChart('1')!;
    expect(chart.visitChecked, isFalse);
    expect(chart.feedbackToken, isNull);

    final opened = store.confirmVisit(chartId: chart.id);
    expect(opened.visitChecked, isTrue);
    expect(opened.feedbackToken, isNotNull);
    expect(opened.feedbackLineOpenedAt, isNotNull);
    expect(store.reviewForChart(chart.id), isNotNull);
    expect(store.findChartByToken(opened.feedbackToken!), isNotNull);
  });

  test('first visit vs membership visit CTA flags', () {
    const first = CustomerChart(
      id: 'a',
      shopId: 's',
      customerId: 'c',
      visitNumber: 1,
    );
    const member = CustomerChart(
      id: 'b',
      shopId: 's',
      customerId: 'c',
      visitNumber: 6,
    );
    expect(first.isFirstVisit, isTrue);
    expect(member.isFirstVisit, isFalse);
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
