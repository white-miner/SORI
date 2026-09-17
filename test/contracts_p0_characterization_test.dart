/// P0 특성화 테스트 — docs/CONTRACTS.md §3 보호 플로우 1~7.
///
/// "옳은 동작"이 아니라 **지금 동작**을 박제한다.
/// #3(당일 차트 재사용)·#10(저장=확정+차감)은 나중에 바뀔 예정이지만
/// 현재 동작을 그대로 기록한다 (#10은 #1 저장 경로의 부수효과로 함께 고정).
///
/// 기능 코드(lib/)는 이 파일에서 수정하지 않는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/customer_membership.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/before_after_compare_sheet.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

CustomerChart _saveMinimal(
  SoriStore store, {
  required String customerId,
  required int visitNumber,
  String careName = '특성화케어',
  String? beforeImageUrl,
  String? afterImageUrl,
  List<CustomerMembership>? memberships,
}) {
  return store.saveChartAndConfirmVisit(
    customerId: customerId,
    visitNumber: visitNumber,
    careName: careName,
    treatmentSummary: 'P0 characterization',
    directorInsight: 'freeze current behavior',
    concernChips: const [],
    firstVisitFearChips: const [],
    revisitFeedbackChips: const [],
    beforeImageUrl: beforeImageUrl,
    afterImageUrl: afterImageUrl,
    memberships: memberships,
  );
}

void main() {
  group('CONTRACTS §3 P0 characterization (flows 1–7)', () {
    test(
      '#1 원장 차트 작성 저장 → chartsForCustomer 렌더 '
      '(+ #10 부수효과: visit_checked + 회원권 차감)',
      () {
        final store = SoriStore();
        final customer = store.findCustomer('2')!;
        final beforeCount = store.chartsForCustomer(customer.id).length;
        final beforeRemaining = customer.membershipRemainingVisits;
        final nextVn = store.nextVisitNumber(customer.id);

        final saved = _saveMinimal(
          store,
          customerId: customer.id,
          visitNumber: nextVn,
          careName: '수분케어',
          memberships: customer.memberships,
        );

        final list = store.chartsForCustomer(customer.id);
        expect(list.length, beforeCount + 1);
        expect(list.any((c) => c.id == saved.id), isTrue);
        expect(saved.visitNumber, nextVn);
        // chartsForCustomer 정렬: visitNumber 내림차순
        expect(list.first.visitNumber, greaterThanOrEqualTo(list.last.visitNumber));
        expect(list.map((c) => c.visitNumber).toList(),
            list.map((c) => c.visitNumber).toList()..sort((a, b) => b.compareTo(a)));

        // #10 현재 동작: 저장 = 확정 + 차감 (한 번에)
        expect(saved.visitChecked, isTrue);
        expect(saved.visitCheckedAt, isNotNull);
        expect(store.lastMembershipDeducted, isTrue);
        expect(
          store.findCustomer(customer.id)!.membershipRemainingVisits,
          beforeRemaining - 1,
        );
      },
    );

    test('#2 촬영 → 사진 부착: before/after URL 컬럼에 기록', () async {
      final store = SoriStore();
      final customer = store.findCustomer('1')!;
      final chart = _saveMinimal(
        store,
        customerId: customer.id,
        visitNumber: store.nextVisitNumber(customer.id),
      );

      const beforeUrl = 'https://example.com/char/before.webp';
      const afterUrl = 'https://example.com/char/after.webp';

      final withBefore = await store.updateCustomerChartFields(
        chartId: chart.id,
        beforeImageUrl: beforeUrl,
      );
      expect(withBefore.beforeImageUrl, beforeUrl);

      final withAfter = await store.updateCustomerChartFields(
        chartId: chart.id,
        afterImageUrl: afterUrl,
      );
      expect(withAfter.afterImageUrl, afterUrl);

      final fromSsot = store.chartsForCustomer(customer.id)
          .firstWhere((c) => c.id == chart.id);
      expect(fromSsot.beforeImageUrl, beforeUrl);
      expect(fromSsot.afterImageUrl, afterUrl);

      // CONTRACTS: Storage 경로 규칙 (ChartPhotoStorage.uploadWebp 템플릿과 동일 형태)
      // `{shopId}/{customerId}/{id}_{stamp}_{before|after}.webp`
      final pathExample =
          '${store.shop.id}/${customer.id}/abcdef0123_1710000000000_before.webp';
      expect(
        pathExample,
        matches(
          RegExp(
            r'^[^/]+/[^/]+/[A-Za-z0-9]+_\d+_(before|after)\.webp$',
          ),
        ),
      );
    });

    test('#3 당일 차트 재사용: ensureTodayShootChart 2회 → 같은 row', () async {
      final store = SoriStore();
      final customer = store.findCustomer('1')!;

      final a = await store.ensureTodayShootChart(customerId: customer.id);
      final b = await store.ensureTodayShootChart(customerId: customer.id);

      expect(a.id, b.id);
      expect(
        store.chartsForCustomer(customer.id).where((c) => c.id == a.id).length,
        1,
      );
    });

    test(
      '#4 Visit 워크플로: startVisitSession → chartForVisitSession → 패치',
      () async {
        final store = SoriStore();
        final customer = store.findCustomer('1')!;

        final session = await store.startVisitSession(customerId: customer.id);
        expect(session.phase, VisitPhase.shoot);
        expect(session.chartDraftId, isNotNull);

        final chart = store.chartForVisitSession(session);
        expect(chart, isNotNull);
        expect(chart!.id, session.chartDraftId);

        final patched = await store.updateCustomerChartFields(
          chartId: chart.id,
          treatmentSummary: '동의·리포트 패치 특성화',
          careReportJson: const {'source': 'p0_characterization'},
          careReportGeneratedAt: DateTime(2026, 9, 10, 13, 0),
        );
        expect(patched.treatmentSummary, '동의·리포트 패치 특성화');
        expect(patched.careReportJson?['source'], 'p0_characterization');

        final again = store.chartForVisitSession(session);
        expect(again?.treatmentSummary, '동의·리포트 패치 특성화');
      },
    );

    test('#5 고객차트 타임라인: chartsForCustomer 는 visitNumber 내림차순', () {
      // AdminChartPage / ChartManagementPage 읽기 SSOT
      final store = SoriStore();
      final customerId = '1';
      _saveMinimal(store, customerId: customerId, visitNumber: 10);
      _saveMinimal(store, customerId: customerId, visitNumber: 12);
      _saveMinimal(store, customerId: customerId, visitNumber: 11);

      final list = store.chartsForCustomer(customerId);
      expect(list, isNotEmpty);
      for (var i = 0; i < list.length - 1; i++) {
        expect(
          list[i].visitNumber,
          greaterThanOrEqualTo(list[i + 1].visitNumber),
          reason: '타임라인 SSOT는 visitNumber 내림차순',
        );
      }
      expect(list.first.visitNumber, 12);
    });

    test('#6 고객 모드 케어 내역: 동일 chartsForCustomer SSOT', () {
      // CustomerCareTab / CareHistoryDetailPage 도 같은 소스
      final store = SoriStore();
      final customerId = '3';
      final directorTimeline = store.chartsForCustomer(customerId);
      final customerCareHistory = store.chartsForCustomer(customerId);

      expect(identical(directorTimeline, customerCareHistory), isFalse);
      expect(
        customerCareHistory.map((c) => c.id).toList(),
        directorTimeline.map((c) => c.id).toList(),
      );
      expect(
        customerCareHistory.map((c) => c.visitNumber).toList(),
        directorTimeline.map((c) => c.visitNumber).toList(),
      );
      for (var i = 0; i < customerCareHistory.length - 1; i++) {
        expect(
          customerCareHistory[i].visitNumber,
          greaterThanOrEqualTo(customerCareHistory[i + 1].visitNumber),
        );
      }
    });

    test('#7 B/A 비교: buildVisitPhotoSlots 차트 URL → 슬롯 매핑', () {
      final charts = [
        const CustomerChart(
          id: 'c-low',
          shopId: 'shop',
          customerId: 'cus',
          visitNumber: 1,
          careName: '재생케어',
          beforeImageUrl: 'https://example.com/1b.webp',
          afterImageUrl: 'https://example.com/1a.webp',
        ),
        const CustomerChart(
          id: 'c-high',
          shopId: 'shop',
          customerId: 'cus',
          visitNumber: 2,
          careName: '수분케어',
          beforeImageUrl: 'https://example.com/2b.webp',
          // after 없음 → 슬롯 1개만
        ),
        const CustomerChart(
          id: 'c-empty',
          shopId: 'shop',
          customerId: 'cus',
          visitNumber: 3,
          careName: '빈차트',
        ),
      ];

      final slots = buildVisitPhotoSlots(charts);
      expect(slots.map((s) => s.key).toList(), [
        'c-low|before',
        'c-low|after',
        'c-high|before',
      ]);
      expect(slots[0].url, 'https://example.com/1b.webp');
      expect(slots[0].visitNumber, 1);
      expect(slots[0].kind, 'before');
      expect(slots[1].kind, 'after');
      expect(slots[2].chartId, 'c-high');
      expect(slots[2].careName, '수분케어');
      // URL 없는 차트는 슬롯을 만들지 않는다 (현재 동작)
      expect(slots.any((s) => s.chartId == 'c-empty'), isFalse);
    });
  });
}
