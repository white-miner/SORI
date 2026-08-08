import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/visit_trigger_service.dart';
import 'package:sori/views/admin_chart_page.dart';
import 'package:sori/views/customer_review_page.dart';
import 'package:sori/views/my_app.dart';

void main() {
  testWidgets('Landing shows brand slogan and social logins', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('소통하는 리뷰, SORI'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('네이버로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
    expect(find.text('Apple로 시작하기'), findsOneWidget);
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
  });

  test('social onboarding director enables mode toggle and tutorial', () {
    final store = SoriStore();
    store.beginSocialLogin(
      provider: SocialProvider.kakao,
      name: '김원장',
      phone: '010-9999-8888',
    );
    store.completeRoleSelection(UserRole.director);
    expect(store.session!.onboardingComplete, isFalse);

    store.completeShopSetup(
      shopName: '테스트샵',
      shopPhone: '02-111-2222',
      naverPlaceUrl: 'https://m.place.naver.com/place/test',
    );
    expect(store.session!.canToggleMode, isTrue);
    expect(store.session!.showFirstChartTutorial, isTrue);
    expect(store.shop.naverPlaceUrl, contains('naver.com'));

    store.toggleActiveMode();
    expect(store.session!.activeMode, UserRole.customer);
  });

  test('phone matching and hash review url', () {
    final store = SoriStore();
    expect(store.findCustomerByPhone('01012345678')?.name, '김민지');
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
