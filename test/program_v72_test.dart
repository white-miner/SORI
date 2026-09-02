import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/program_sales.dart';
import 'package:sori/services/sori_store.dart';

Future<Customer> _customer(SoriStore store) async {
  if (store.customers.isNotEmpty) return store.customers.first;
  return store.addCustomerAsync(
    Customer(
      id: '',
      shopId: store.shop.id,
      name: '테스트고객',
      phone: '010-0000-0000',
      lastTreatmentDate: DateTime(2026, 9, 3),
      treatmentType: '',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Q4(a) 정액 할인 후 퍼센트를 적용한다', () {
    const flat = ProgramPromotion(
      id: 'flat',
      shopId: 's',
      kind: ProgramPromoKind.instantDiscount,
      title: '10만 원 할인',
      discountKrw: 100000,
      valueKrw: 100000,
    );
    const pct = ProgramPromotion(
      id: 'pct',
      shopId: 's',
      kind: ProgramPromoKind.percentDiscount,
      title: '10%',
      percentOff: 10,
      valueKrw: 290000,
    );
    // (3,000,000 - 100,000) * 0.9 = 2,610,000
    expect(ProgramPricing.payable(3000000, [flat, pct]), 2610000);
    // 순서를 바꿔도 같다
    expect(ProgramPricing.payable(3000000, [pct, flat]), 2610000);
  });

  test('다음 방문 크레딧은 회원권 횟수에 더하지 않는다', () {
    const extra = ProgramPromotion(
      id: 'e',
      shopId: 's',
      kind: ProgramPromoKind.extraSession,
      title: '+1',
      extraVisits: 1,
      valueKrw: 300000,
    );
    const credit = ProgramPromotion(
      id: 'c',
      shopId: 's',
      kind: ProgramPromoKind.nextVisitCredit,
      title: '다음 20%',
      percentOff: 20,
      extraVisits: 3,
      valueKrw: 200000,
    );
    expect(ProgramPricing.membershipVisits(6, [extra, credit]), 7);
    expect(ProgramPricing.futureCredits([extra, credit]), hasLength(1));
  });

  test('단건 견적은 right 가 비고 isSingle 이다', () async {
    final store = SoriStore();
    final a = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
    final quote = await store.presentProgramQuote(left: a);
    expect(quote.isSingle, isTrue);
    expect(quote.right, isNull);
    expect(quote.chosen.id, a.id);
    expect(quote.listPriceKrw, 3000000);
  });

  test('수락 시 next_visit_credit 은 쿠폰으로 떨어지고 횟수는 그대로다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final before = customer.memberships.length;
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    var quote = await store.presentProgramQuote(left: left);
    quote = await store.setQuotePromotions(
      quote: quote,
      promotionIds: const [
        ProgramDemoSeed.promoExtra,
        ProgramDemoSeed.promoCredit,
      ],
    );

    final saved = await store.acceptProgramQuote(
      quote: quote,
      customerId: customer.id,
    );
    expect(saved.memberships.length, before + 1);
    expect(saved.memberships.last.totalVisits, 7);
    final unused = store.unusedCouponsFor(saved.id);
    expect(unused, hasLength(1));
    expect(unused.first.title, '다음 패키지 20% 할인');
    expect(unused.first.percentOff, 20);
    expect(store.unusedCouponCount(saved.id), 1);
  });

  test('미결제로 수락하면 outstanding 이 남고 차감은 막지 않는다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final quote = await store.presentProgramQuote(left: left);
    await store.acceptProgramQuote(
      quote: quote,
      customerId: customer.id,
      paymentStatus: ProgramPaymentStatus.unpaid,
      paidKrw: 0,
    );
    expect(store.outstandingKrwFor(customer.id), 1500000);
    expect(store.unpaidProgramQuotes, isNotEmpty);
    expect(store.unpaidProgramQuotes.first.isUnpaid, isTrue);
  });

  test('결제 완료로 수락하면 미수가 없다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final left = store.findProgramPackage(ProgramDemoSeed.pkgC)!;
    final quote = await store.presentProgramQuote(left: left);
    await store.acceptProgramQuote(
      quote: quote,
      customerId: customer.id,
      paymentStatus: ProgramPaymentStatus.paid,
      paidKrw: quote.payableKrw,
      method: ProgramPaymentMethod.card,
    );
    expect(store.outstandingKrwFor(customer.id), 0);
    expect(store.findProgramQuote(quote.id)!.paymentStatus, ProgramPaymentStatus.paid);
  });
}
