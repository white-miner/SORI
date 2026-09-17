import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/market_strategy/market_data_provider.dart';
import 'package:sori/features/market_strategy/market_strategy_models.dart';
import 'package:sori/features/market_strategy/market_strategy_page.dart';
import 'package:sori/features/market_strategy/market_strategy_store.dart';
import 'package:sori/features/market_strategy/target_revenue_calc.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoriStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SoriStore(repository: MemorySoriRepository());
    store.session = const SessionUser(
      role: UserRole.director,
      name: '테스트원장',
      phone: '010-0000-0000',
      provider: SocialProvider.kakao,
      authUserId: '00000000-0000-4000-8000-000000000001',
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketStrategyPage(
          store: store,
          provider: const DemoMarketProvider(),
          forceDemo: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  test('saved planner and actions survive a new store instance', () async {
    final vault = MarketStrategyStore(shopId: 'shop-a', userId: 'user-a');
    await vault.hydrate();
    await vault.savePlan(
      TargetRevenueCalc.compute(
        const TargetRevenueInput(
          fixedCostKrw: 6000000,
          targetProfitKrw: 3000000,
          averageTicketKrw: 90000,
          variableCostPerVisitKrw: 27000,
          openDaysPerMonth: 25,
          trade: MarketTrade.skin,
        ),
      ),
    );
    await vault.addCandidate(
      const MarketCandidate(
        id: 'c1',
        label: '성건동',
        lat: 35.8534,
        lng: 129.2087,
        radiusKm: 1,
        trade: MarketTrade.skin,
        competitorCount: 4,
        densityPerKm2: 1.3,
      ),
    );
    await vault.addAction(
      StrategyActionPlan(
        id: '',
        title: '현장 조사',
        description: '가격 메모',
        priority: ActionPriority.high,
        dueOn: DateTime(2026, 9, 14),
        successMetric: '메모 3건',
        linkedInsight: '후보지',
        status: ActionPlanStatus.todo,
        horizon: ActionHorizon.today,
        createdAt: DateTime(2026, 9, 13),
      ),
    );
    final reloaded = MarketStrategyStore(shopId: 'shop-a', userId: 'user-a');
    await reloaded.hydrate();
    expect(reloaded.plan?.monthlyVisits, 143);
    expect(reloaded.plan?.dailyVisits, 6);
    expect(reloaded.candidates, hasLength(1));
    expect(reloaded.actions, hasLength(1));
    await reloaded.updateAction(
      reloaded.actions.first.copyWith(
        status: ActionPlanStatus.done,
        outcomeMemo: '대기 12분',
        outcomeValue: 12,
      ),
    );
    final again = MarketStrategyStore(shopId: 'shop-a', userId: 'user-a');
    await again.hydrate();
    expect(again.actions.first.status, ActionPlanStatus.done);
    expect(again.actions.first.outcomeMemo, '대기 12분');
  });

  testWidgets('목표매출 플래너 golden 결과가 화면에 나온다', (tester) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('market-calc')));
    await tester.tap(find.byKey(const Key('market-calc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('월 필요 방문 143회'), findsOneWidget);
    expect(find.textContaining('하루 필요 방문 6회'), findsOneWidget);
    expect(find.textContaining('공헌이익률 70%'), findsOneWidget);
    expect(find.textContaining('공헌이익 63,000원'), findsOneWidget);
    expect(find.textContaining('하루 6명'), findsOneWidget);
  });

  testWidgets('상권 지도 데모 배너와 후보지 비교·액션 생성', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('지도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('데모 데이터'), findsWidgets);
    expect(find.textContaining('DEMO'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('save-candidate')));
    await tester.tap(find.byKey(const Key('save-candidate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('동종 업소 수'), findsOneWidget);
    await tester.ensureVisible(find.text('현장 조사 계획 만들기'));
    await tester.tap(find.text('현장 조사 계획 만들기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('현장 조사'), findsWidgets);
  });

  testWidgets('매출 감소 진단 후 행동 계획을 완료하고 성과를 기록한다', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('전략'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('market-sample-diagnosis')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('신규 발견성 약화 또는 경쟁 증가 가능성'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('diagnosis-to-actions-rule-a')));
    await tester.tap(find.byKey(const Key('diagnosis-to-actions-rule-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('상태: todo'), findsWidgets);
    await tester.tap(find.byTooltip('완료 처리').first);
    await tester.pump();
    expect(find.textContaining('상태: done'), findsWidgets);
    await tester.tap(find.byTooltip('성과 기록').first);
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '성과 메모'), '재방문 2건');
    await tester.enterText(find.widgetWithText(TextField, '성과 수치'), '2');
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.textContaining('재방문 2건'), findsWidgets);
  });

  testWidgets('UNAVAILABLE 배너와 다시 조회 CTA', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketStrategyPage(
          store: store,
          provider: const _UnavailableProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('UNAVAILABLE'), findsWidgets);
    expect(find.textContaining('지금 공공 상가 데이터를 불러오지 못했습니다'), findsWidgets);
    expect(find.textContaining('경쟁 밀도: 데이터 없음'), findsWidgets);
    expect(find.text('다시 시도'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LIVE_EMPTY는 0곳 밀도를 성공처럼 그리지 않고 업종 변경 CTA를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketStrategyPage(
          store: store,
          provider: const _EmptyLiveProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('LIVE_EMPTY'), findsWidgets);
    expect(find.textContaining('조건에 맞는 업소를 찾지 못했어요'), findsWidgets);
    expect(find.text('반경 바꾸기'), findsWidgets);
    expect(find.textContaining('면적당 0.0곳'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px에서도 요약 탭이 overflow 없이 그려진다', (tester) async {
    await _pumpSummaryAtWidth(tester, store, 360);
    expect(find.byKey(const Key('our-area-headline')), findsOneWidget);
    expect(find.byKey(const Key('pill-trade')), findsOneWidget);
    expect(find.byKey(const Key('our-area-primary-cta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390px와 412px에서도 요약 탭이 overflow 없이 그려진다', (tester) async {
    await _pumpSummaryAtWidth(tester, store, 390);
    expect(find.byKey(const Key('our-area-headline')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _pumpSummaryAtWidth(tester, store, 412);
    expect(find.byKey(const Key('our-area-primary-cta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('위치 미설정 화면의 주소/나중에 CTA가 요약으로 이어진다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketStrategyPage(store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('our-area-setup')), findsOneWidget);
    expect(find.byKey(const Key('setup-gps')), findsOneWidget);
    expect(find.byKey(const Key('setup-address')), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-later')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('our-area-headline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('핵심 CTA가 무반응 없이 다음 화면을 연다', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('경쟁 지도 보기').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('analyze-here')), findsOneWidget);
    expect(find.byKey(const Key('shop-list-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-list-toggle')));
    await tester.pump();
    expect(find.text('목록 접기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('analyze-here')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('이 위치로 분석'), findsOneWidget);
  });

  testWidgets('360px 지도 탭에서 목록을 열어도 overflow가 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketStrategyPage(
          store: store,
          provider: const DemoMarketProvider(),
          forceDemo: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('경쟁 지도 보기').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('shop-list-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-list-toggle')));
    await tester.pump();
    expect(find.text('목록 접기'), findsOneWidget);
    expect(find.byKey(const Key('analyze-here')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSummaryAtWidth(
  WidgetTester tester,
  SoriStore store,
  double width,
) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MarketStrategyPage(
        store: store,
        provider: const DemoMarketProvider(),
        forceDemo: true,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

class _UnavailableProvider implements MarketDataProvider {
  const _UnavailableProvider();

  static const _missing = IndicatorMeta(
    source: '',
    periodLabel: '',
    updatedOn: '',
    geoUnit: '',
    available: false,
  );

  @override
  Future<MarketSnapshot> load({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    String addressLabel = '',
  }) async {
    return MarketSnapshot(
      status: MarketDataStatus.unavailable,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: const [],
      errorCode: 'upstream',
      userMessage: '지금 공공 상가 데이터를 불러오지 못했습니다. 다시 시도하세요.',
      competitionMeta: const IndicatorMeta(
        source: '소상공인시장진흥공단 상가(상권)정보',
        periodLabel: '',
        updatedOn: '',
        geoUnit: '반경 3km',
        available: false,
      ),
      populationMeta: _missing,
      footMeta: _missing,
      trendMeta: _missing,
    );
  }
}

class _EmptyLiveProvider implements MarketDataProvider {
  const _EmptyLiveProvider();

  static const _missing = IndicatorMeta(
    source: '',
    periodLabel: '',
    updatedOn: '',
    geoUnit: '',
    available: false,
  );

  @override
  Future<MarketSnapshot> load({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
    String addressLabel = '',
  }) async {
    return MarketSnapshot(
      status: MarketDataStatus.liveEmpty,
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      trade: trade,
      competitors: const [],
      httpStatus: 200,
      fetchedAt: DateTime.utc(2026, 9, 13),
      competitionMeta: const IndicatorMeta(
        source: '소상공인시장진흥공단 상가(상권)정보',
        periodLabel: '원문 기준일 미확인',
        updatedOn: '2026-09-13',
        geoUnit: '반경 1km',
        available: false,
        nextAction: '업종이나 반경을 바꿔 다시 조회하세요.',
      ),
      populationMeta: _missing,
      footMeta: _missing,
      trendMeta: _missing,
    );
  }
}
