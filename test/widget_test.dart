import 'package:flutter_test/flutter_test.dart';

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
}
