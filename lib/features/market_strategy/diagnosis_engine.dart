import 'market_strategy_models.dart';
import 'target_revenue_calc.dart';

/// 매출 감소 가설 규칙. 단정하지 않고 가능한 해석만 붙인다.
abstract final class DiagnosisEngine {
  static DiagnosisOutcome diagnose({
    required InternalPeriodMetrics current,
    required InternalPeriodMetrics previous,
    ExternalPeriodMetrics? external,
  }) {
    final missing = <String>[];
    if (current.customerCount <= 0 && previous.customerCount <= 0) {
      missing.add('고객 수');
    }
    if (current.averageTicketKrw <= 0 && previous.averageTicketKrw <= 0) {
      missing.add('객단가');
    }
    if (current.revenueKrw <= 0 && previous.revenueKrw <= 0) {
      missing.add('매출');
    }
    if (missing.isNotEmpty) {
      return DiagnosisOutcome(cards: const [], missing: missing);
    }

    final cards = <DiagnosisCard>[];
    final custDelta = _pct(current.customerCount, previous.customerCount);
    final ticketDelta = _pct(current.averageTicketKrw, previous.averageTicketKrw);
    final newDelta = _pct(current.newCustomerCount, previous.newCustomerCount);
    final returnDelta =
        _pct(current.returningCustomerCount, previous.returningCustomerCount);
    final revenueDelta = _pct(current.revenueKrw, previous.revenueKrw);
    final contribDelta =
        _pct(current.contributionKrw, previous.contributionKrw);
    final revisitDeltaPp = (current.revisitRate - previous.revisitRate) * 100;
    final comp = external?.competitorChangePct;
    final foot = external?.footChangePct;

    if (custDelta != null &&
        custDelta <= -8 &&
        ticketDelta != null &&
        ticketDelta.abs() <= 3 &&
        comp != null &&
        comp >= 5) {
      cards.add(
        DiagnosisCard(
          id: 'rule-a',
          ruleId: 'a',
          title: '신규 발견성 약화 또는 경쟁 증가 가능성',
          observation: '고객 수는 줄었고 객단가는 비슷합니다.',
          evidence:
              '고객 수 ${fmtPct(custDelta)}, 객단가 ${fmtPct(ticketDelta)}, 경쟁 업소 ${fmtPct(comp)}',
          possibleReading: '주변 동종 업소가 늘면서 신규 유입이 분산됐을 수 있습니다. 원인은 확정할 수 없습니다.',
          toVerify: '신규 유입 경로, 검색/지도 노출, 최근 오픈 업소 위치를 현장과 대조해 보세요.',
          todayAction: '최근 30일 신규 고객 유입 경로를 수기로 3건만 적어 보세요.',
          weekAction: '반경 안 동종 업소 3곳을 방문해 가격·대기·예약 방식을 메모하세요.',
          metric30d: '신규 고객 수와 지도/검색 문의 건수를 각각 기록',
          limitation: '경쟁 증가는 참고 지표이며 폐업·오분류가 섞일 수 있습니다.',
        ),
      );
    }

    if (revisitDeltaPp <= -5 && (comp == null || comp.abs() <= 3)) {
      cards.add(
        DiagnosisCard(
          id: 'rule-b',
          ruleId: 'b',
          title: '서비스 경험 또는 다음 케어 흐름 단절 가능성',
          observation: '재방문율이 떨어졌고 주변 경쟁 변화는 크지 않습니다.',
          evidence:
              '재방문율 ${revisitDeltaPp.toStringAsFixed(1)}%p, 다음 케어 예약률 ${(current.nextCareBookRate * 100).toStringAsFixed(0)}%',
          possibleReading: '시술 후 다음 케어 안내가 끊겼거나 경험 편차가 생겼을 수 있습니다.',
          toVerify: '미예약 고객 목록, 케어 간격, 불만 메모를 확인하세요.',
          todayAction: '오늘 시술한 고객 중 다음 케어가 비어 있는 사람을 목록으로 만드세요.',
          weekAction: '재방문 간격이 길어진 고객 10명에게 다음 케어 안내를 보내 보세요.',
          metric30d: '다음 케어 예약률과 재방문율 변화',
          limitation: '재방문율만으로 서비스 품질을 단정하지 않습니다.',
        ),
      );
    }

    if (newDelta != null &&
        newDelta < 0 &&
        returnDelta != null &&
        returnDelta >= -1 &&
        foot != null &&
        foot <= -5) {
      cards.add(
        DiagnosisCard(
          id: 'rule-c',
          ruleId: 'c',
          title: '외부 유입 감소 가능성',
          observation: '신규는 줄었고 재방문은 유지되는 편입니다.',
          evidence:
              '신규 ${fmtPct(newDelta)}, 재방문 고객 ${fmtPct(returnDelta)}, 유동 ${fmtPct(foot)}',
          possibleReading: '길목 유동이나 상권 방문 자체가 줄었을 수 있습니다.',
          toVerify: '같은 거리의 평일/주말 보행, 행사·공사 여부를 확인해 보세요.',
          todayAction: '샵 앞 30분 보행 수를 수기로 세어 기록하세요.',
          weekAction: '주중·주말 각 1회 같은 시간대 보행을 비교하세요.',
          metric30d: '신규 고객 수와 수기 보행 기록',
          limitation: '유동 지수는 추정값이며 실제 보행과 다를 수 있습니다.',
        ),
      );
    }

    if (custDelta != null &&
        custDelta.abs() <= 2 &&
        ticketDelta != null &&
        ticketDelta <= -5) {
      cards.add(
        DiagnosisCard(
          id: 'rule-d',
          ruleId: 'd',
          title: '할인·메뉴 믹스·가격 압박 가능성',
          observation: '고객 수는 유지됐는데 객단가가 낮아졌습니다.',
          evidence:
              '고객 수 ${fmtPct(custDelta)}, 객단가 ${fmtPct(ticketDelta)}, 할인액 ${current.discountKrw}원',
          possibleReading: '할인 비중이나 저가 메뉴 비중이 늘었을 수 있습니다.',
          toVerify: '메뉴별 판매 건수와 할인 적용 비율을 확인해 보세요.',
          todayAction: '이번 주 할인 적용 건을 메뉴별로 적어 보세요.',
          weekAction: '객단가를 끌어올린 메뉴와 할인한 메뉴를 비교하세요.',
          metric30d: '객단가와 할인액 비중',
          limitation: '객단가 하락이 곧 가격 실패는 아닙니다.',
        ),
      );
    }

    if (revenueDelta != null &&
        revenueDelta.abs() <= 2 &&
        contribDelta != null &&
        contribDelta < 0) {
      cards.add(
        DiagnosisCard(
          id: 'rule-e',
          ruleId: 'e',
          title: '변동비·할인·수수료 증가 가능성',
          observation: '매출은 비슷한데 공헌이익이 줄었습니다.',
          evidence:
              '매출 ${fmtPct(revenueDelta)}, 공헌이익 ${fmtPct(contribDelta)}, 변동비 ${current.variableCostKrw}원',
          possibleReading: '재료비, 할인, 결제 수수료가 매출보다 빨리 늘었을 수 있습니다.',
          toVerify: '재료 매입, 카드 수수료, 패키지 할인율을 기간별로 비교하세요.',
          todayAction: '이번 달 재료 매입 영수증 합계를 적어 보세요.',
          weekAction: '결제 수단별 수수료와 할인 건수를 나눠 보세요.',
          metric30d: '매출 대비 변동비 비율',
          limitation: '공헌이익 감소만으로 원인을 확정하지 않습니다.',
        ),
      );
    }

    return DiagnosisOutcome(cards: cards, missing: const []);
  }

  /// 상권 밀도·목표 방문만으로 우선 행동을 만든다. 내부 매출이 없어도 동작.
  static List<DiagnosisCard> areaPriority({
    required MarketSnapshot snap,
    TargetRevenueResult? plan,
  }) {
    final cards = <DiagnosisCard>[];
    if (snap.status == MarketDataStatus.unavailable) {
      return cards;
    }
    if (snap.densityPerKm2 >= 8) {
      cards.add(
        const DiagnosisCard(
          id: 'area-density',
          ruleId: 'density',
          title: '반경 안 동종 밀도가 높습니다',
          observation: '같은 분야 업소가 면적 대비 많이 모여 있습니다.',
          evidence: '경쟁 밀도는 동종 업소 수 / 원면적입니다. 최고 입지라는 뜻은 아닙니다.',
          possibleReading: '가격·예약 방식·리뷰 응대가 더 잘 보일 수 있습니다.',
          toVerify: '가까운 경쟁 매장 5곳의 서비스·가격·리뷰·예약방식을 현장에서 확인하세요.',
          todayAction: '가장 가까운 동종 업소 2곳의 메뉴판과 예약 채널을 사진으로 남기세요.',
          weekAction: '5곳의 가격대와 대기 방식을 표로 정리하세요.',
          metric30d: '현장 조사 5곳 완료 여부',
          limitation: '공공 상가 정보는 폐업·오분류가 섞일 수 있습니다. 유사 업종은 밀도에 넣지 않습니다.',
        ),
      );
    }
    if (plan != null && plan.dailyVisits >= 8) {
      cards.add(
        DiagnosisCard(
          id: 'area-daily',
          ruleId: 'daily',
          title: '하루 필요 방문이 많습니다',
          observation: '목표를 맞추려면 하루 평균 ${plan.dailyVisits}명이 필요합니다.',
          evidence:
              '월 ${plan.monthlyVisits}회 / 영업일 ${plan.input.openDaysPerMonth}일',
          possibleReading: '객단가, 재방문, 신규 유입 중 어디를 먼저 올릴지 나눠 봐야 합니다.',
          toVerify: '최근 30일 신규·재방문·객단가를 각각 적어 보세요.',
          todayAction: '오늘 시술 고객의 다음 케어 예약 여부를 목록으로 만드세요.',
          weekAction: '신규 유입 경로 3가지를 수기로 적어 보세요.',
          metric30d: '하루 평균 방문과 객단가',
          limitation: '필요 방문은 목표 가정의 결과이며 실제 수요를 보장하지 않습니다.',
        ),
      );
    }
    return cards;
  }

  static double? _pct(num current, num previous) {
    if (previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  static String fmtPct(double v) {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}%';
  }
}
