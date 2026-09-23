import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/chart_visit_record.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('같은 회차 번호를 두 번 저장하면 차트는 1행이다', () {
    final store = SoriStore();
    final customer = store.findCustomer('2')!;
    final visitNumber = store.nextVisitNumber(customer.id);
    final before = store.chartsForCustomer(customer.id).length;

    store.saveChartAndConfirmVisit(
      customerId: customer.id,
      visitNumber: visitNumber,
      careName: '첫번째',
      treatmentSummary: '첫 저장',
      directorInsight: '',
      concernChips: const [],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
    );
    final second = store.saveChartAndConfirmVisit(
      customerId: customer.id,
      visitNumber: visitNumber,
      careName: '두번째',
      treatmentSummary: '같은 회차 갱신',
      directorInsight: '',
      concernChips: const [],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
    );

    final same = store
        .chartsForCustomer(customer.id)
        .where((chart) => chart.visitNumber == visitNumber)
        .toList();
    expect(store.chartsForCustomer(customer.id).length, before + 1);
    expect(same, hasLength(1));
    expect(same.single.id, second.id);
    expect(same.single.careName, '두번째');
  });

  test('1년 안 전자동의는 차트 행을 더 만들지 않는다', () {
    final store = SoriStore();
    final customer = store.findCustomer('3')!;
    final before = store.chartsForCustomer(customer.id).length;
    final visitNumber = store.nextVisitNumber(customer.id);

    store.saveChartAndConfirmVisit(
      customerId: customer.id,
      visitNumber: visitNumber,
      careName: '동의',
      treatmentSummary: '고객 정보 및 관리 동의서 체결',
      directorInsight: '',
      concernChips: const [],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
      consentMandatory: true,
      signatureUrl: 'sig-1',
    );

    final existing = store.consentChartToRenew(customer.id);
    expect(existing, isNotNull);
    expect(existing!.visitNumber, visitNumber);

    store.saveChartAndConfirmVisit(
      customerId: customer.id,
      visitNumber: existing.visitNumber,
      chartId: existing.id,
      careName: existing.careName,
      treatmentSummary: existing.treatmentSummary,
      directorInsight: existing.directorInsight,
      concernChips: existing.concernChips,
      firstVisitFearChips: existing.firstVisitFearChips,
      revisitFeedbackChips: existing.revisitFeedbackChips,
      beforeImageUrl: existing.beforeImageUrl,
      afterImageUrl: existing.afterImageUrl,
      consentMandatory: true,
      signatureUrl: 'sig-2',
    );

    final signed = store
        .chartsForCustomer(customer.id)
        .where((chart) => chart.isConsentSigned)
        .toList();
    expect(store.chartsForCustomer(customer.id).length, before + 1);
    expect(signed, hasLength(1));
    expect(signed.single.signatureUrl, 'sig-2');
    expect(
      store.findChartById('chart-3')!.beforeImageUrl,
      'https://picsum.photos/seed/sori-b3/600/800',
    );
  });

  test('오늘 방문 초안을 두 번 열면 같은 차트다', () async {
    final store = SoriStore();
    final customer = store.findCustomer('2')!;
    final before = store.chartsForCustomer(customer.id).length;
    final record = ChartVisitRecord(
      flowStatus: 'draft',
      visitDate: DateTime.now(),
    );

    final first = await store.createChartVisitDraft(
      customerId: customer.id,
      record: record,
    );
    final second = await store.createChartVisitDraft(
      customerId: customer.id,
      record: record,
    );

    expect(second.id, first.id);
    expect(store.chartsForCustomer(customer.id).length, before + 1);

    final third = await store.createChartVisitDraft(
      customerId: customer.id,
      record: record,
      forceNew: true,
    );
    expect(third.id, isNot(first.id));
    expect(third.visitNumber, first.visitNumber + 1);
    expect(store.chartsForCustomer(customer.id).length, before + 2);
  });
}
