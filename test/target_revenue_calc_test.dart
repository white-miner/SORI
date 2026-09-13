import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/market_strategy/target_revenue_calc.dart';

void main() {
  test('golden: 고정비 600만 · 이익 300만 · 객단가 9만 · 변동 2.7만 · 25일', () {
    final result = TargetRevenueCalc.compute(
      const TargetRevenueInput(
        fixedCostKrw: 6000000,
        targetProfitKrw: 3000000,
        averageTicketKrw: 90000,
        variableCostPerVisitKrw: 27000,
        openDaysPerMonth: 25,
        trade: 'skin',
      ),
    );
    expect(result.contributionKrw, 63000);
    expect(result.contributionRate, closeTo(0.70, 0.0001));
    expect(result.monthlyVisits, 143);
    expect(result.dailyVisits, 6);
  });

  test('rejects negative money, zero ticket, variable >= ticket, bad days', () {
    expect(
      () => TargetRevenueCalc.compute(
        const TargetRevenueInput(
          fixedCostKrw: -1,
          targetProfitKrw: 1,
          averageTicketKrw: 1000,
          variableCostPerVisitKrw: 100,
          openDaysPerMonth: 20,
          trade: 'hair',
        ),
      ),
      throwsA(isA<TargetRevenueError>().having((e) => e.code, 'code', 'NEGATIVE_AMOUNT')),
    );
    expect(
      () => TargetRevenueCalc.compute(
        const TargetRevenueInput(
          fixedCostKrw: 1,
          targetProfitKrw: 1,
          averageTicketKrw: 0,
          variableCostPerVisitKrw: 0,
          openDaysPerMonth: 20,
          trade: 'hair',
        ),
      ),
      throwsA(isA<TargetRevenueError>().having((e) => e.code, 'code', 'ZERO_TICKET')),
    );
    expect(
      () => TargetRevenueCalc.compute(
        const TargetRevenueInput(
          fixedCostKrw: 1,
          targetProfitKrw: 1,
          averageTicketKrw: 1000,
          variableCostPerVisitKrw: 1000,
          openDaysPerMonth: 20,
          trade: 'hair',
        ),
      ),
      throwsA(isA<TargetRevenueError>().having((e) => e.code, 'code', 'VARIABLE_GE_TICKET')),
    );
    expect(
      () => TargetRevenueCalc.compute(
        const TargetRevenueInput(
          fixedCostKrw: 1,
          targetProfitKrw: 1,
          averageTicketKrw: 1000,
          variableCostPerVisitKrw: 100,
          openDaysPerMonth: 0,
          trade: 'hair',
        ),
      ),
      throwsA(isA<TargetRevenueError>().having((e) => e.code, 'code', 'OPEN_DAYS_RANGE')),
    );
  });

  test('API error shape has code, message, requestId', () {
    final err = TargetRevenueError('ZERO_TICKET', '평균 객단가는 0원일 수 없습니다.');
    expect(err.toJson().keys, containsAll(['code', 'message', 'requestId']));
  });

  test('additional visits is required minus actual, floored at 0', () {
    expect(
      TargetRevenueCalc.additionalMonthlyVisits(
        requiredMonthlyVisits: 143,
        actualMonthlyVisits: 100,
      ),
      43,
    );
    expect(
      TargetRevenueCalc.additionalMonthlyVisits(
        requiredMonthlyVisits: 143,
        actualMonthlyVisits: 200,
      ),
      0,
    );
  });

  test('extra daily visits is null without actuals and signed when present', () {
    expect(
      TargetRevenueCalc.extraDailyVisitsNeeded(
        targetDailyVisits: 6,
        monthVisitCount: 0,
        openDays: 25,
      ),
      isNull,
    );
    expect(
      TargetRevenueCalc.extraDailyVisitsNeeded(
        targetDailyVisits: 6,
        monthVisitCount: 50,
        openDays: 25,
      ),
      4,
    );
    expect(
      TargetRevenueCalc.extraDailyVisitsNeeded(
        targetDailyVisits: 6,
        monthVisitCount: 200,
        openDays: 25,
      ),
      lessThan(0),
    );
  });
}
