import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/market_strategy/diagnosis_engine.dart';
import 'package:sori/features/market_strategy/market_strategy_models.dart';
import 'package:sori/features/market_strategy/target_revenue_calc.dart';

InternalPeriodMetrics _base({
  int customers = 200,
  int ticket = 90000,
  int revenue = 18000000,
  int visits = 200,
  int neu = 50,
  int ret = 150,
  double revisit = 0.6,
  double nextCare = 0.4,
  int discount = 200000,
  int variable = 5000000,
  String label = '현재',
}) {
  return InternalPeriodMetrics(
    label: label,
    revenueKrw: revenue,
    visitCount: visits,
    customerCount: customers,
    newCustomerCount: neu,
    returningCustomerCount: ret,
    averageTicketKrw: ticket,
    revisitRate: revisit,
    nextCareBookRate: nextCare,
    discountKrw: discount,
    variableCostKrw: variable,
  );
}

void main() {
  test('rule a: customers -8%+, ticket flat, competition +5%+', () {
    final out = DiagnosisEngine.diagnose(
      current: _base(customers: 180, ticket: 89000, label: '최근'),
      previous: _base(customers: 200, ticket: 90000, label: '이전'),
      external: const ExternalPeriodMetrics(competitorChangePct: 6),
    );
    expect(out.cards.map((c) => c.ruleId), contains('a'));
  });

  test('rule b: revisit -5%p and competition stable', () {
    final out = DiagnosisEngine.diagnose(
      current: _base(revisit: 0.50),
      previous: _base(revisit: 0.58),
      external: const ExternalPeriodMetrics(competitorChangePct: 1),
    );
    expect(out.cards.map((c) => c.ruleId), contains('b'));
  });

  test('rule c: new down, returning flat, foot -5%+', () {
    final out = DiagnosisEngine.diagnose(
      current: _base(neu: 30, ret: 150),
      previous: _base(neu: 50, ret: 150),
      external: const ExternalPeriodMetrics(footChangePct: -6),
    );
    expect(out.cards.map((c) => c.ruleId), contains('c'));
  });

  test('rule d: customers flat, ticket -5%+', () {
    final out = DiagnosisEngine.diagnose(
      current: _base(customers: 200, ticket: 80000),
      previous: _base(customers: 200, ticket: 90000),
    );
    expect(out.cards.map((c) => c.ruleId), contains('d'));
  });

  test('rule e: revenue flat, contribution down', () {
    final out = DiagnosisEngine.diagnose(
      current: _base(revenue: 18000000, variable: 8000000),
      previous: _base(revenue: 18000000, variable: 5000000),
    );
    expect(out.cards.map((c) => c.ruleId), contains('e'));
  });

  test('missing metrics produce data list instead of hypothesis', () {
    const empty = InternalPeriodMetrics(
      label: 'x',
      revenueKrw: 0,
      visitCount: 0,
      customerCount: 0,
      newCustomerCount: 0,
      returningCustomerCount: 0,
      averageTicketKrw: 0,
      revisitRate: 0,
      nextCareBookRate: 0,
      discountKrw: 0,
      variableCostKrw: 0,
    );
    final out = DiagnosisEngine.diagnose(current: empty, previous: empty);
    expect(out.cards, isEmpty);
    expect(out.missing, isNotEmpty);
  });

  test('high density suggests field survey without claiming best location', () {
    CompetitorShop shop(int i) => CompetitorShop(
          id: '$i',
          name: 's$i',
          trade: MarketTrade.skin,
          lat: 35.85,
          lng: 129.2,
          address: '',
          distanceM: i,
        );
    final snap = MarketSnapshot(
      status: MarketDataStatus.live,
      centerLat: 35.85,
      centerLng: 129.2,
      radiusKm: 0.2,
      trade: MarketTrade.skin,
      competitors: [for (var i = 0; i < 4; i++) shop(i)],
      competitionMeta: const IndicatorMeta(
        source: 's',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '0.2km',
      ),
      populationMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      footMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      trendMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
    );
    final cards = DiagnosisEngine.areaPriority(snap: snap);
    expect(snap.densityPerKm2 >= 8, isTrue);
    expect(cards.map((c) => c.ruleId), contains('density'));
    expect(cards.first.title.contains('최고'), isFalse);
  });

  test('high daily visits adds ticket/revisit/new-inflow scenario', () {
    CompetitorShop shop(int i) => CompetitorShop(
          id: '$i',
          name: 's$i',
          trade: MarketTrade.skin,
          lat: 35.85,
          lng: 129.2,
          address: '',
          distanceM: i,
        );
    final snap = MarketSnapshot(
      status: MarketDataStatus.live,
      centerLat: 35.85,
      centerLng: 129.2,
      radiusKm: 3,
      trade: MarketTrade.skin,
      competitors: [shop(1)],
      competitionMeta: const IndicatorMeta(
        source: 's',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '3km',
      ),
      populationMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      footMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
      trendMeta: const IndicatorMeta(
        source: '',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '',
        available: false,
      ),
    );
    final plan = TargetRevenueCalc.compute(
      const TargetRevenueInput(
        fixedCostKrw: 6000000,
        targetProfitKrw: 3000000,
        averageTicketKrw: 90000,
        variableCostPerVisitKrw: 27000,
        openDaysPerMonth: 12,
        trade: MarketTrade.skin,
      ),
    );
    expect(plan.dailyVisits >= 8, isTrue);
    final cards = DiagnosisEngine.areaPriority(snap: snap, plan: plan);
    expect(cards.map((c) => c.ruleId), contains('daily'));
    expect(cards.any((c) => c.possibleReading.contains('객단가')), isTrue);
  });
}
