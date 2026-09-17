/// AI 샵 경영 리포트 — DB 정산 API 연동 전 MOCK 스냅샷.
class AiShopReportMock {
  const AiShopReportMock({
    required this.periodLabel,
    required this.revenue,
    required this.portfolio,
    required this.targetSegment,
    required this.goldenTime,
    required this.careMessage,
  });

  final String periodLabel;
  final AiRevenueModule revenue;
  final AiPortfolioModule portfolio;
  final AiTargetSegmentModule targetSegment;
  final AiGoldenTimeModule goldenTime;
  final AiCareMessageModule careMessage;

  static AiShopReportMock demo() => const AiShopReportMock(
        periodLabel: '2026.08 · 이번 달 추정',
        revenue: AiRevenueModule(
          estimatedSalesWon: 18420000,
          salesDeltaPercent: 12.4,
          membershipBurnValueWon: 6720000,
          membershipBurnRatePercent: 61,
          visitCount: 148,
          ticketSessionsUsed: 96,
          highlight:
              '회원권 소진 가치가 추정 매출의 36% — 재결제 파이프라인이 건강한 구간입니다.',
        ),
        portfolio: AiPortfolioModule(
          investMenus: [
            AiMenuSignal(
              name: '테라노바 복부케어',
              tag: '화력 집중',
              metric: '전환율 68%',
              reason: '회원권 업셀 1위 · 재방문 평균 2.4회',
              tone: AiMenuTone.invest,
            ),
            AiMenuSignal(
              name: 'LDM 수분장벽 리페어',
              tag: '효자 메뉴',
              metric: '리뷰 ★4.9',
              reason: '긍정 키워드 ‘촉촉·진정’ 점유율 41%',
              tone: AiMenuTone.invest,
            ),
          ],
          cutMenus: [
            AiMenuSignal(
              name: '기본 수분 케어',
              tag: '삭제 추천',
              metric: '마진↓',
              reason: '시간 대비 마진 저하 · 단독 예약 전환 12%',
              tone: AiMenuTone.cut,
            ),
            AiMenuSignal(
              name: '구형 LED 토닝 (장비A)',
              tag: '축소/퇴출',
              metric: '가동률 18%',
              reason: '장비 가동률 저조 · 신메뉴와 수요 중복',
              tone: AiMenuTone.cut,
            ),
          ],
          aiProposal:
              "최근 차트에서 ‘모공·피지’ 고민이 급증했습니다. [쿨링 모공 디톡스] 30분 패키지 신설을 추천합니다.",
        ),
        targetSegment: AiTargetSegmentModule(
          primaryLabel: '30대 후반 · 직장인 여성',
          sharePercent: 54,
          traits: [
            '주말 오후 예약 집중',
            '복부·붓기 케어 선호',
            '10회권 결제 비중 62%',
            '리뷰 작성률 높음 (케어 후 3일 이내)',
          ],
          summary:
              '핵심 구매층은 ‘짧고 확실한 결과’를 원합니다. 테라노바·장벽 리페어 묶음 제안이 전환에 유리합니다.',
        ),
        goldenTime: AiGoldenTimeModule(
          items: [
            AiGoldenTarget(
              customerName: '김서연',
              reason: '회원권 잔여 2회 · 골든타임 D-5',
              action: '재결제 제안 + 테라노바 업셀',
              urgency: 'imminent',
            ),
            AiGoldenTarget(
              customerName: '박지현',
              reason: '마지막 방문 21일 전 · 재방문 골든타임',
              action: '홈케어 안부 + 예약 슬롯 제안',
              urgency: 'revisit',
            ),
            AiGoldenTarget(
              customerName: '이하늘',
              reason: '10회권 소진 임박 (잔여 1회)',
              action: '연장 패키지 카톡 발송',
              urgency: 'imminent',
            ),
            AiGoldenTarget(
              customerName: '최유진',
              reason: '첫 방문 후 미재방문 14일',
              action: '2회차 체험 할인 메시지',
              urgency: 'revisit',
            ),
          ],
        ),
        careMessage: AiCareMessageModule(
          chartTags: ['테라노바', '복부', '붓기', '홈케어-순환'],
          preview:
              '서연 고객님, 오늘 테라노바 복부케어 잘 받으셨죠? 🌙\n'
              '저녁엔 미지근한 물로 가볍게 클렌징하시고, '
              '순환 오일 2펌프를 시계방향으로 3분만 롤링해 주세요.\n'
              '붓기가 덜한 아침이 보이면 다음 방문이 더 가벼워져요. '
              '잔여 2회, 원하시면 연장 패키지도 안내드릴게요 💛',
          suggestedChannel: '카카오톡 1:1',
        ),
      );
}

class AiRevenueModule {
  const AiRevenueModule({
    required this.estimatedSalesWon,
    required this.salesDeltaPercent,
    required this.membershipBurnValueWon,
    required this.membershipBurnRatePercent,
    required this.visitCount,
    required this.ticketSessionsUsed,
    required this.highlight,
  });

  final int estimatedSalesWon;
  final double salesDeltaPercent;
  final int membershipBurnValueWon;
  final int membershipBurnRatePercent;
  final int visitCount;
  final int ticketSessionsUsed;
  final String highlight;
}

enum AiMenuTone { invest, cut }

class AiMenuSignal {
  const AiMenuSignal({
    required this.name,
    required this.tag,
    required this.metric,
    required this.reason,
    required this.tone,
  });

  final String name;
  final String tag;
  final String metric;
  final String reason;
  final AiMenuTone tone;
}

class AiPortfolioModule {
  const AiPortfolioModule({
    required this.investMenus,
    required this.cutMenus,
    required this.aiProposal,
  });

  final List<AiMenuSignal> investMenus;
  final List<AiMenuSignal> cutMenus;
  final String aiProposal;
}

class AiTargetSegmentModule {
  const AiTargetSegmentModule({
    required this.primaryLabel,
    required this.sharePercent,
    required this.traits,
    required this.summary,
  });

  final String primaryLabel;
  final int sharePercent;
  final List<String> traits;
  final String summary;
}

class AiGoldenTarget {
  const AiGoldenTarget({
    required this.customerName,
    required this.reason,
    required this.action,
    required this.urgency,
  });

  final String customerName;
  final String reason;
  final String action;
  final String urgency; // imminent | revisit
}

class AiGoldenTimeModule {
  const AiGoldenTimeModule({required this.items});

  final List<AiGoldenTarget> items;
}

class AiCareMessageModule {
  const AiCareMessageModule({
    required this.chartTags,
    required this.preview,
    required this.suggestedChannel,
  });

  final List<String> chartTags;
  final String preview;
  final String suggestedChannel;
}
