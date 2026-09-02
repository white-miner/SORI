import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/program/widgets/program_compare_page.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/models/program_sales.dart';
import 'package:sori/services/sori_store.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<SoriStore> _mountHome(WidgetTester tester) async {
  final store = SoriStore();
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
  );
  await _settle(tester);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('아코디언 전개 시 앵커 아래로 타깃/디코이가 이어진다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);

    expect(find.text('3,000,000'), findsOneWidget);
    expect(find.text('1,500,000'), findsNothing);

    await tester.tap(find.text('윤곽 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('3,000,000'), findsWidgets);
    expect(find.text('1,500,000'), findsOneWidget);
    expect(find.text('1,000,000'), findsOneWidget);
    expect(find.text('B패키지  6회'), findsOneWidget);

    final anchorY = tester.getTopLeft(find.text('A패키지  10회')).dy;
    final targetY = tester.getTopLeft(find.text('B패키지  6회')).dy;
    final decoyY = tester.getTopLeft(find.text('C패키지  3회')).dy;
    expect(anchorY, lessThan(targetY));
    expect(targetY, lessThan(decoyY));
  });

  testWidgets('exclusive accordion — 한 카테고리만 펼친다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);

    await tester.tap(find.text('윤곽 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    expect(find.text('1,500,000'), findsOneWidget);

    await tester.ensureVisible(find.text('웨딩신부 관리'));
    await tester.tap(find.text('웨딩신부 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('1,500,000'), findsNothing, reason: '윤곽이 접히면 디코이 가격이 트리에서 사라진다');
    expect(find.text('2,500,000'), findsWidgets);
  });

  testWidgets('2택 후 비교 뷰어가 280ms 페이드로 열린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _mountHome(tester);
    await tester.tap(find.text('Program'));
    await _settle(tester);

    await tester.tap(find.text('윤곽 관리'));
    await tester.pump(HomeVisualTokens.programExpandDuration);

    await tester.tap(find.byKey(const Key('program-check-${ProgramDemoSeed.pkgA}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('program-check-${ProgramDemoSeed.pkgB}')));
    await tester.pump();

    expect(find.byKey(const Key('program-compare-dock')), findsOneWidget);
    expect(find.text('비교하기'), findsOneWidget);

    await tester.tap(find.text('비교하기'));
    await tester.pump(HomeVisualTokens.programExpandDuration);
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(ProgramComparePage), findsOneWidget);
    expect(find.byKey(const Key('program-compare-stage')), findsOneWidget);
    expect(find.byKey(const Key('program-compare-left')), findsOneWidget);
    expect(find.byKey(const Key('program-compare-right')), findsOneWidget);
    expect(find.textContaining('회당 50,000원 이득'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 비교는 좌우 50/50로 나란히 놓인다', (tester) async {
    tester.view.physicalSize = const Size(932, 430);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = SoriStore();
    final left = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
    final right = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final quote = await store.presentProgramQuote(left: left, right: right);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgramComparePage(store: store, quoteId: quote.id),
      ),
    );
    await tester.pump(HomeVisualTokens.programExpandDuration);

    final stage = tester.getRect(find.byKey(const Key('program-compare-stage')));
    final l = tester.getRect(find.byKey(const Key('program-compare-left')));
    final r = tester.getRect(find.byKey(const Key('program-compare-right')));

    expect(l.left, closeTo(stage.left, 2));
    expect(r.left, greaterThan(l.right - 2));
    expect(l.width / stage.width, inInclusiveRange(0.45, 0.55));
    expect(r.width / stage.width, inInclusiveRange(0.45, 0.55));
    expect(l.height, closeTo(r.height, 2));
  });

  testWidgets('프로모션 스택은 정가를 남기고 혜택 합을 보여 준다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    final left = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
    final right = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    var quote = await store.presentProgramQuote(left: left, right: right);
    quote = await store.setQuotePromotions(
      quote: quote,
      promotionIds: const [
        ProgramDemoSeed.promoExtra,
        ProgramDemoSeed.promoGift,
      ],
    );

    expect(quote.benefitValueKrw, 400000);
    expect(quote.payableKrw, 3000000);
    expect(quote.listPriceKrw, 3000000);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgramComparePage(store: store, quoteId: quote.id),
      ),
    );
    await tester.pump();

    expect(find.text('3,000,000'), findsWidgets);
    expect(find.byKey(const Key('program-benefit-line')), findsOneWidget);
    expect(find.text('총 400,000원 추가 혜택 적용됨'), findsOneWidget);
  });

  testWidgets('견적 수락은 회원권을 발급한다', (tester) async {
    final store = SoriStore();
    if (store.customers.isEmpty) return;
    final customer = store.customers.first;
    final before = customer.memberships.length;

    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final right = store.findProgramPackage(ProgramDemoSeed.pkgC)!;
    var quote = await store.presentProgramQuote(left: left, right: right);
    quote = await store.setQuoteChosen(quote: quote, packageId: left.id);
    quote = await store.setQuotePromotions(
      quote: quote,
      promotionIds: const [ProgramDemoSeed.promoExtra],
    );

    final saved = await store.acceptProgramQuote(
      quote: quote,
      customerId: customer.id,
    );
    expect(saved.memberships.length, before + 1);
    final ticket = saved.memberships.last;
    expect(ticket.serviceName, 'B패키지');
    expect(ticket.totalVisits, 7);
    expect(ticket.paidAmount, 1500000);
  });
}
