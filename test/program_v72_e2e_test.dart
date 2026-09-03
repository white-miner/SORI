import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/program/program_accept.dart';
import 'package:sori/features/program/widgets/program_quote_page.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/models/program_sales.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_profile_page.dart';
import 'package:sori/views/director_customers_tab.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('1택이면 단건 요약으로 들어가 프로모션 버튼이 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VisitLauncherPage(store: SoriStore()))),
    );
    await _settle(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);
    await tester.tap(find.text('윤곽 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);

    await tester.tap(
      find.byKey(const Key('program-check-${ProgramDemoSeed.pkgA}')),
    );
    await tester.pump();
    expect(find.text('이 구성으로 진행'), findsOneWidget);

    await tester.tap(find.byKey(const Key('program-dock-proceed')));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(ProgramQuotePage), findsOneWidget);
    expect(find.byKey(const Key('program-quote-page')), findsOneWidget);
    expect(find.byKey(const Key('program-closer-chip')), findsOneWidget);
    expect(find.byKey(const Key('program-payable-line')), findsOneWidget);
    expect(find.text('오늘 결제  3,000,000'), findsOneWidget);
    expect(find.text('프로모션 적용'), findsOneWidget);
    expect(find.byKey(const Key('program-available-promos')), findsOneWidget);
  });

  testWidgets('확정 시트는 기본 미결제이고 결제 완료를 찍을 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final quote = await store.presentProgramQuote(left: left);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => acceptProgramQuoteWithCustomer(
                context: context,
                store: store,
                quote: quote,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('program-confirm-sheet')), findsOneWidget);
    expect(find.byKey(const Key('program-confirm-unpaid')), findsOneWidget);
    expect(find.byKey(const Key('program-confirm-submit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('program-confirm-paid')));
    await tester.pump();
    expect(find.text('카드'), findsOneWidget);
    expect(find.text('현금'), findsOneWidget);
  });

  testWidgets('검색어로 신규 고객을 같은 시트에서 만들 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final left = store.findProgramPackage(ProgramDemoSeed.pkgC)!;
    final quote = await store.presentProgramQuote(left: left);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => acceptProgramQuoteWithCustomer(
                context: context,
                store: store,
                quote: quote,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('program-confirm-customer')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '홍길동');
    await tester.pump();
    expect(find.byKey(const Key('program-quick-create')), findsOneWidget);

    await tester.tap(find.byKey(const Key('program-quick-create')));
    await tester.pump();
    expect(find.byKey(const Key('program-quick-create-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('program-quick-create-phone')),
      '010-7777-8888',
    );
    await tester.tap(find.byKey(const Key('program-quick-create-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('홍길동'), findsWidgets);
  });

  testWidgets('미사용 쿠폰이 고객 차트에 배지로 뜬다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    if (store.customers.isEmpty) return;
    final customer = store.customers.first;
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    var quote = await store.presentProgramQuote(left: left);
    quote = await store.setQuotePromotions(
      quote: quote,
      promotionIds: const [ProgramDemoSeed.promoCredit],
    );
    await store.acceptProgramQuote(quote: quote, customerId: customer.id);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfilePage(store: store, customerId: customer.id),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('program-coupon-badge')), findsOneWidget);
    expect(find.textContaining('다음 패키지 20% 할인'), findsOneWidget);
  });

  testWidgets('고객 목록에도 미사용 쿠폰 배지가 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    if (store.customers.isEmpty) return;
    final customer = store.customers.first;
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    var quote = await store.presentProgramQuote(left: left);
    quote = await store.setQuotePromotions(
      quote: quote,
      promotionIds: const [ProgramDemoSeed.promoCredit],
    );
    await store.acceptProgramQuote(quote: quote, customerId: customer.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DirectorCustomersTab(store: store)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('program-coupon-badge')), findsWidgets);
  });

  testWidgets('접힌 앵커 아래에 전체 혜택 캡션이 한 줄 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VisitLauncherPage(store: SoriStore()))),
    );
    await _settle(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);

    expect(find.byKey(const Key('program-global-promo-caption')), findsWidgets);
    final caption = tester.widget<Text>(
      find.byKey(const Key('program-global-promo-caption')).first,
    );
    expect(caption.maxLines, 1);
    expect(caption.style?.color, HomeVisualTokens.dateIconColor);
    expect(caption.style?.fontSize, 11);
  });

  testWidgets('단건에서 비교 대상을 추가하면 첫 스냅샷이 유지된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
    );
    await _settle(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);
    await tester.tap(find.text('윤곽 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);

    await tester.tap(
      find.byKey(const Key('program-check-${ProgramDemoSeed.pkgA}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('program-dock-proceed')));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(ProgramQuotePage), findsOneWidget);
    await tester.tap(find.byKey(const Key('program-quote-add-compare')));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.textContaining('비교할 패키지를'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('program-check-${ProgramDemoSeed.pkgB}')),
    );
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('3,000,000'), findsWidgets);
    final frozen = store.programQuotes.where((q) => !q.isSingle);
    expect(frozen, isNotEmpty);
    expect(frozen.first.left.listPriceKrw, 3000000);
  });
}
