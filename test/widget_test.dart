import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/shop.dart';
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

  testWidgets('Customer review requires last-4 then shows Ikea composer',
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

    expect(find.textContaining('조립하는 후기'), findsOneWidget);
    expect(find.text('속당김 해결'), findsOneWidget);
    expect(find.textContaining('네이버에 리뷰'), findsOneWidget);
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

  test('membership ticket deducts on visit confirm and syncs remaining', () {
    final store = SoriStore();
    final before = store.findCustomer('2')!;
    expect(before.membershipTotalVisits, 10);
    expect(before.membershipUsedVisits, 8);
    expect(before.membershipRemainingVisits, 2);
    expect(before.isMembershipLow, isTrue);

    store.saveChartAndConfirmVisit(
      customerId: '2',
      visitNumber: store.nextVisitNumber('2'),
      careName: '수분케어',
      treatmentSummary: '회원권 차감 테스트',
      directorInsight: '보습 유지',
      concernChips: const [],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
      membershipServiceName: before.membershipServiceName,
      membershipTotalVisits: before.membershipTotalVisits,
      membershipUsedVisits: before.membershipUsedVisits,
    );

    final after = store.findCustomer('2')!;
    expect(after.membershipUsedVisits, 9);
    expect(after.membershipRemainingVisits, 1);
    expect(after.membershipBadgeLabel, '진행 9회 / 잔여 1회');
  });

  test('repository bootstrap loads memory snapshot async', () async {
    final store = SoriStore(repository: MemorySoriRepository());
    expect(store.customers, isNotEmpty);
    await store.bootstrap();
    expect(store.bootstrapComplete, isTrue);
    expect(store.isLoading, isFalse);
    expect(store.isRemoteEnabled, isFalse);
    expect(store.findCustomer('2')!.membershipRemainingVisits, 2);
  });

  test('fromMap tolerates null updated_at and bad timestamps', () {
    final shop = Shop.fromMap({
      'id': 'shop-1',
      'name': '테스트샵',
      'naver_place_url': 'https://example.com',
      'updated_at': null,
      'created_at': null,
    });
    expect(shop.id, 'shop-1');

    final customer = Customer.fromMap({
      'id': 'c-1',
      'shop_id': 'shop-1',
      'name': '홍길동',
      'phone': '01012345678',
      'last_treatment_date': null,
      'updated_at': null,
      'birth_date': 'not-a-date',
    });
    expect(customer.name, '홍길동');
    expect(customer.birthDate, isNull);

    final chart = CustomerChart.fromMap({
      'id': 'chart-1',
      'shop_id': 'shop-1',
      'customer_id': 'c-1',
      'visit_number': '2',
      'visit_checked': 'true',
      'updated_at': null,
      'visit_checked_at': '',
    });
    expect(chart.visitNumber, 2);
    expect(chart.visitChecked, isTrue);
    expect(chart.visitCheckedAt, isNull);
  });
}
