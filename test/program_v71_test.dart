import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/program_sales.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProgramPricing', () {
    test('회당 단가는 SQL ::int 처럼 0 쪽으로 자른다', () {
      expect(ProgramPricing.unitPrice(3000000, 10), 300000);
      expect(ProgramPricing.unitPrice(1500000, 6), 250000);
      expect(ProgramPricing.unitPrice(1000000, 3), 333333);
      expect(ProgramPricing.unitPrice(100, 0), 0);
    });

    test('혜택 합과 payable 은 정가를 덮어쓰지 않는다', () {
      const gift = ProgramPromotion(
        id: 'g',
        shopId: 's',
        kind: ProgramPromoKind.gift,
        title: '크림',
        valueKrw: 100000,
      );
      const extra = ProgramPromotion(
        id: 'e',
        shopId: 's',
        kind: ProgramPromoKind.extraSession,
        title: '+1',
        valueKrw: 300000,
        extraVisits: 1,
      );
      const cut = ProgramPromotion(
        id: 'c',
        shopId: 's',
        kind: ProgramPromoKind.instantDiscount,
        title: '즉시',
        valueKrw: 100000,
        discountKrw: 100000,
      );

      expect(ProgramPricing.benefitValue([gift, extra]), 400000);
      expect(ProgramPricing.payable(3000000, [gift, extra]), 3000000);
      expect(ProgramPricing.payable(3000000, [gift, extra, cut]), 2900000);
      expect(ProgramPricing.membershipVisits(6, [extra]), 7);
    });

    test('formatKrw 는 3자리 콤마', () {
      expect(ProgramPricing.formatKrw(3000000), '3,000,000');
      expect(ProgramPricing.formatKrw(0), '0');
    });
  });

  group('파생 앵커', () {
    test('최고가가 보드 앵커이며 플래그를 보지 않는다', () {
      final demo = ProgramDemoSeed.forShop('shop-demo');
      final contour = demo.packages
          .where((p) => p.categoryId == ProgramDemoSeed.contourId)
          .toList();
      final anchor = ProgramPackage.boardAnchor(contour);
      expect(anchor?.id, ProgramDemoSeed.pkgA);
      expect(anchor?.listPriceKrw, 3000000);

      final flipped = contour
          .map(
            (p) => p.id == ProgramDemoSeed.pkgC
                ? p.copyWith(listPriceKrw: 4000000)
                : p,
          )
          .toList();
      expect(ProgramPackage.boardAnchor(flipped)?.id, ProgramDemoSeed.pkgC);
    });

    test('동점 앵커는 sort_order 가 앞선 쪽', () {
      final now = DateTime(2026, 9, 2);
      final a = ProgramPackage(
        id: 'a',
        shopId: 's',
        categoryId: 'c',
        name: 'A',
        visitCount: 1,
        listPriceKrw: 100,
        sortOrder: 1,
        createdAt: now,
      );
      final b = ProgramPackage(
        id: 'b',
        shopId: 's',
        categoryId: 'c',
        name: 'B',
        visitCount: 1,
        listPriceKrw: 100,
        sortOrder: 0,
        createdAt: now.add(const Duration(days: 1)),
      );
      expect(ProgramPackage.boardAnchor([a, b])?.id, 'b');
    });
  });

  group('SoriStore Program', () {
    test('시드 보드가 윤곽 3패키지 + 웨딩 1패키지', () {
      final store = SoriStore();
      expect(store.programBoards, hasLength(2));
      final contour = store.programBoards.first;
      expect(contour.anchor?.id, ProgramDemoSeed.pkgA);
      expect(contour.packages, hasLength(3));
    });

    test('비교 견적은 스냅샷을 얼린다', () async {
      final store = SoriStore();
      final a = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
      final b = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
      final quote = await store.presentProgramQuote(left: a, right: b);

      await store.upsertProgramPackage(a.copyWith(listPriceKrw: 1));
      final frozen = store.findProgramQuote(quote.id)!;
      expect(frozen.left.listPriceKrw, 3000000);
      expect(store.findProgramPackage(a.id)!.listPriceKrw, 1);
    });

    test('고객 없이 수락하면 거부한다', () async {
      final store = SoriStore();
      final a = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
      final b = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
      final quote = await store.presentProgramQuote(left: a, right: b);
      expect(
        () => store.acceptProgramQuote(quote: quote, customerId: ''),
        throwsStateError,
      );
    });
  });
}
