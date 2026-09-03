import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/program/program_edit_page.dart';
import 'package:sori/features/program/widgets/program_deduct_sheet.dart';
import 'package:sori/features/program/widgets/program_editor_sheets.dart';
import 'package:sori/features/program/widgets/program_quote_page.dart';
import 'package:sori/features/program/widgets/program_slot_replace_sheet.dart';
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

class _FlakyRemoteRepo extends MemorySoriRepository {
  var failAccept = true;
  var acceptCalls = 0;

  @override
  bool get isRemote => true;

  @override
  Future<ProgramAcceptResult> acceptProgramQuote({
    required String quoteId,
    required String customerId,
    ProgramPaymentStatus paymentStatus = ProgramPaymentStatus.unpaid,
    int paidKrw = 0,
    ProgramPaymentMethod method = ProgramPaymentMethod.cash,
  }) async {
    acceptCalls += 1;
    if (failAccept) {
      throw Exception('SocketException: Failed host lookup');
    }
    return super.acceptProgramQuote(
      quoteId: quoteId,
      customerId: customerId,
      paymentStatus: paymentStatus,
      paidKrw: paidKrw,
      method: method,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('구성 4종 라벨은 dbValue 를 노출하지 않는다', () {
    expect(ProgramLineKind.step.labelKo, '관리 내용');
    expect(ProgramLineKind.device.labelKo, '사용 기기');
    expect(ProgramLineKind.ampoule.labelKo, '제품·앰플');
    expect(ProgramLineKind.perk.labelKo, '추가 혜택');
    expect(ProgramLineKind.step.labelKo, isNot(ProgramLineKind.step.dbValue));
  });

  test('R4 조립기는 범위+종류+값 문장을 만든다', () {
    expect(
      ProgramPromoComposer.preview(
        scope: ProgramPromoScope.package,
        kind: ProgramPromoKind.extraSession,
        targetName: 'A패키지',
        extraVisits: 3,
      ),
      'A패키지 / +3회',
    );
    expect(
      ProgramPromoComposer.preview(
        scope: ProgramPromoScope.global,
        kind: ProgramPromoKind.percentDiscount,
        percentOff: 10,
      ),
      '모든 관리 서비스 / 10% 할인',
    );
  });

  test('패키지 전용 혜택은 다른 견적에 붙지 않는다', () async {
    final store = SoriStore();
    final wedding = store.findProgramPackage(ProgramDemoSeed.pkgWedding)!;
    await store.upsertProgramPromotion(
      ProgramPromotion(
        id: '',
        shopId: store.shop.id,
        kind: ProgramPromoKind.extraSession,
        title: '윤곽 A패키지 / +3회',
        extraVisits: 3,
        valueKrw: 360000,
        scope: ProgramPromoScope.package,
        targetId: ProgramDemoSeed.pkgA,
      ),
    );
    final forWedding = store.promotionsForPackage(
      wedding.toSnapshot(categoryName: '웨딩신부 관리'),
    );
    expect(
      forWedding.any((p) => p.title.contains('윤곽 A패키지')),
      isFalse,
    );
  });

  test('접힌 보드 캡션은 global 혜택만 한 줄로 모은다', () async {
    final store = SoriStore();
    expect(store.globalPromoCaption, isNotEmpty);
    expect(store.globalPromoCaption.contains(' · '), isTrue);
    await store.upsertProgramPromotion(
      ProgramPromotion(
        id: '',
        shopId: store.shop.id,
        kind: ProgramPromoKind.gift,
        title: '웨딩 전용 사은품',
        scope: ProgramPromoScope.package,
        targetId: ProgramDemoSeed.pkgWedding,
      ),
    );
    expect(store.globalPromoCaption.contains('웨딩 전용 사은품'), isFalse);
  });

  test('비교 대상을 붙여도 왼쪽 스냅샷 정가는 그대로다', () async {
    final store = SoriStore();
    final a = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
    final b = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final single = await store.presentProgramQuote(left: a);
    expect(single.listPriceKrw, 3000000);
    final compared = await store.attachQuotePeer(quote: single, right: b);
    expect(compared.isSingle, isFalse);
    expect(compared.left.listPriceKrw, 3000000);
    expect(compared.right?.id, b.id);
    expect(compared.listPriceKrw, 3000000);
  });

  test('닫으면 이탈 견적으로 남고 90일이 지난 리드만 로드에서 빠진다', () async {
    final store = SoriStore();
    final a = store.findProgramPackage(ProgramDemoSeed.pkgA)!;
    final quote = await store.presentProgramQuote(left: a);
    final abandoned = await store.abandonProgramQuote(quote.id);
    expect(abandoned?.status, ProgramQuoteStatus.abandoned);
    expect(store.findProgramQuote(quote.id), isNotNull);

    final old = ProgramQuote(
      id: quote.id,
      shopId: quote.shopId,
      left: quote.left,
      status: ProgramQuoteStatus.abandoned,
      createdAt: DateTime.now().subtract(const Duration(days: 91)),
    );
    expect(old.isVisibleLeadAt(), isFalse);
    expect(quote.copyWith(status: ProgramQuoteStatus.accepted).isVisibleLeadAt(), isTrue);
  });

  test('오프라인 수락은 로컬 회원권을 즉시 발급하고 재시도는 1건만 남긴다', () async {
    final repo = _FlakyRemoteRepo();
    final store = SoriStore(repository: repo);
    await store.refreshProgramBoard();
    final customer = await _customer(store);
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB);
    expect(left, isNotNull);
    final quote = await store.presentProgramQuote(left: left!);
    final before = customer.memberships.length;

    final saved = await store.acceptProgramQuote(
      quote: quote,
      customerId: customer.id,
    );
    expect(store.lastAcceptOffline, isTrue);
    expect(saved.memberships.length, before + 1);
    expect(store.programAcceptOutbox, hasLength(1));
    expect(
      store.programMemberships.where((m) => m.sourceQuoteId == quote.id),
      hasLength(1),
    );

    repo.failAccept = false;
    await store.flushProgramAcceptOutbox();
    expect(store.programAcceptOutbox, isEmpty);
    expect(
      store.programMemberships.where((m) => m.sourceQuoteId == quote.id),
      hasLength(1),
    );
    expect(
      (await repo.loadProgramMemberships(store.shop.id))
          .where((m) => m.sourceQuoteId == quote.id),
      hasLength(1),
    );
  });

  test('환불은 원장을 닫고 jsonb 미러에서 뺀다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final left = store.findProgramPackage(ProgramDemoSeed.pkgC)!;
    final quote = await store.presentProgramQuote(left: left);
    await store.acceptProgramQuote(quote: quote, customerId: customer.id);
    final ticket = store.programMemberships
        .firstWhere((m) => m.sourceQuoteId == quote.id);
    expect(ticket.refundAmount(), ticket.paidKrw);

    final used = ticket.copyWith(usedVisits: 1);
    store.programMemberships[store.programMemberships.indexWhere((m) => m.id == ticket.id)] =
        used;
    final refunded = await store.refundProgramMembership(
      membershipId: ticket.id,
      basis: ProgramRefundBasis.packageUnit,
    );
    expect(refunded.status, ProgramMembershipStatus.refunded);
    expect(refunded.refundedKrw, used.refundAmount());
    final mirrored = store.findCustomer(customer.id)!;
    expect(mirrored.memberships.any((m) => m.id == ticket.id), isFalse);
  });

  test('승계는 원본을 닫고 잔여 가치를 넘긴다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final left = store.findProgramPackage(ProgramDemoSeed.pkgB)!;
    final quote = await store.presentProgramQuote(left: left);
    await store.acceptProgramQuote(quote: quote, customerId: customer.id);
    final from = store.programMemberships
        .firstWhere((m) => m.sourceQuoteId == quote.id)
        .copyWith(usedVisits: 2);
    store.programMemberships[store.programMemberships.indexWhere((m) => m.id == from.id)] =
        from;

    final next = ProgramMembership(
      id: '00000000-0000-4000-8000-00000000m009',
      shopId: store.shop.id,
      customerId: customer.id,
      serviceName: 'A패키지',
      totalVisits: 10,
      paidKrw: 3000000,
      perSessionKrw: 300000,
      createdAt: DateTime.now(),
    );
    final saved = await store.supersedeProgramMembership(
      fromId: from.id,
      replacement: next,
    );
    expect(saved.id, next.id);
    expect(
      store.findProgramMembership(from.id)?.status,
      ProgramMembershipStatus.superseded,
    );
    expect(store.findProgramMembership(from.id)?.creditAppliedKrw, from.remainingValueKrw);
    final mirrored = store.findCustomer(customer.id)!;
    expect(mirrored.memberships.any((m) => m.id == from.id), isFalse);
    expect(mirrored.memberships.any((m) => m.id == next.id), isTrue);
  });

  test('차감은 만료 임박을 먼저 깎고 고른 장만 줄인다', () async {
    final store = SoriStore();
    final customer = await _customer(store);
    final soon = ProgramMembership(
      id: '00000000-0000-4000-8000-00000000m001',
      shopId: store.shop.id,
      customerId: customer.id,
      serviceName: '윤곽',
      totalVisits: 10,
      usedVisits: 0,
      expiresAt: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 1, 1),
    );
    final later = ProgramMembership(
      id: '00000000-0000-4000-8000-00000000m002',
      shopId: store.shop.id,
      customerId: customer.id,
      serviceName: '윤곽 관리',
      totalVisits: 6,
      usedVisits: 0,
      createdAt: DateTime(2026, 8, 1),
    );
    store.programMemberships.addAll([later, soon]);
    store.customers[store.customers.indexWhere((c) => c.id == customer.id)] =
        customer.copyWith(
          memberships: [soon.toCustomerTicket(), later.toCustomerTicket()],
        ).withSyncedMembershipMirrors();

    expect(ProgramMembership.deductOrder(soon, later), lessThan(0));

    final auto = store.deductProgramMembership(
      customerId: customer.id,
      careName: '윤곽 관리',
    );
    expect(auto, isTrue);
    expect(store.findProgramMembership(soon.id)!.usedVisits, 1);
    expect(store.findProgramMembership(later.id)!.usedVisits, 0);
    expect(store.lastMembershipDeductChoices, hasLength(2));

    store.deductProgramMembership(
      customerId: customer.id,
      careName: '윤곽 관리',
      membershipId: later.id,
    );
    expect(store.findProgramMembership(later.id)!.usedVisits, 1);
    final mirrored = store.findCustomer(customer.id)!;
    expect(
      mirrored.memberships.firstWhere((m) => m.id == later.id).usedVisits,
      1,
    );
  });

  testWidgets('구성 행은 종류+내용+분으로 저장된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(home: ProgramEditPage(store: store)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(Key('program-edit-add-package-${ProgramDemoSeed.contourId}')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('program-edit-package-name')),
      'D코스',
    );
    await tester.enterText(
      find.byKey(const Key('program-edit-line-0')),
      '고주파 온열',
    );
    await tester.enterText(
      find.byKey(const Key('program-edit-line-minutes-0')),
      '20',
    );
    expect(find.text('관리 내용'), findsWidgets);

    await tester.tap(find.byKey(const Key('program-edit-sheet-save')));
    await tester.pumpAndSettle();

    final saved = store.programPackages.firstWhere((p) => p.name == 'D코스');
    expect(saved.lines, hasLength(1));
    expect(saved.lines.first.kind, ProgramLineKind.step);
    expect(saved.lines.first.label, '고주파 온열');
    expect(saved.lines.first.minutes, 20);
    expect(saved.lines.first.kind.labelKo, '관리 내용');

    final quote = await store.presentProgramQuote(left: saved);
    await tester.pumpWidget(
      MaterialApp(home: ProgramQuotePage(store: store, quoteId: quote.id)),
    );
    await tester.pump();
    expect(find.text('1. 고주파 온열 20분'), findsOneWidget);
    expect(find.text('시간 합'), findsOneWidget);
    expect(find.text('20분'), findsWidgets);
  });

  testWidgets('프로모션 조립기는 미리보기를 실시간으로 바꾼다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProgramPromotionSheet(
                context,
                store: store,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program-promo-kind-extra_session')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('program-edit-promo-extra')),
      '3',
    );
    await tester.pump();
    expect(find.byKey(const Key('program-promo-preview')), findsOneWidget);
    expect(find.textContaining('+3회'), findsWidgets);

    await tester.tap(find.byKey(const Key('program-edit-sheet-save')));
    await tester.pumpAndSettle();
    expect(
      store.programPromotions.any((p) => p.extraVisits == 3),
      isTrue,
    );
  });

  testWidgets('3번째 체크는 어느 슬롯을 뺄지 묻는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProgramSlotReplaceSheet(
                context: context,
                leftName: 'A패키지',
                rightName: 'B패키지',
                incomingName: 'C패키지',
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('program-slot-replace-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('program-slot-replace-0')));
    await tester.pumpAndSettle();
  });

  testWidgets('다중 회원권은 차감 대상을 고르게 한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final a = ProgramMembership(
      id: '00000000-0000-4000-8000-00000000m011',
      shopId: 's',
      customerId: 'c',
      serviceName: '윤곽 A',
      totalVisits: 10,
      expiresAt: DateTime(2026, 9, 5),
    );
    final b = ProgramMembership(
      id: '00000000-0000-4000-8000-00000000m012',
      shopId: 's',
      customerId: 'c',
      serviceName: '윤곽 B',
      totalVisits: 6,
    );
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showProgramDeductPickSheet(
                  context: context,
                  candidates: [a, b],
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('program-deduct-pick-title')), findsOneWidget);
    await tester.tap(find.byKey(Key('program-deduct-pick-${b.id}')));
    await tester.pumpAndSettle();
    expect(picked, b.id);
  });
}
