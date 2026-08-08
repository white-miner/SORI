import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/visit_trigger_service.dart';
import 'package:sori/views/my_app.dart';

void main() {
  testWidgets('Dashboard shows pending message count', (WidgetTester tester) async {
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
