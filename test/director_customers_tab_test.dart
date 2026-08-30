import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/customer_membership.dart';
import 'package:sori/models/membership_ticket.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/director_customers_tab.dart';

final _jan2026 = DateTime(2026, 1, 1);

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
    store.customers.clear();
    store.charts.clear();
    store.membershipTickets.clear();
  });

  test('chartLabelForCustomer shows latest chart number', () {
    final c = Customer(
      id: 'c1',
      name: '김민지',
      phone: '01011112222',
      lastTreatmentDate: _jan2026,
      treatmentType: '페이스',
    );
    store.customers.add(c);
    store.charts.addAll([
      CustomerChart(
        id: 'ch-old',
        shopId: store.shop.id,
        customerId: c.id,
        visitNumber: 3,
        careName: '페이스',
      ),
      CustomerChart(
        id: 'ch-new',
        shopId: store.shop.id,
        customerId: c.id,
        visitNumber: 7,
        customChartNo: '1024',
        careName: '페이스',
        createdAt: DateTime(2026, 2, 1),
      ),
    ]);

    expect(chartLabelForCustomer(c, store), 'Chart #1024');
  });

  test('remainBadgeLabelForCustomer prefers membership then tickets', () {
    final withMembership = Customer(
      id: 'c2',
      name: '이서연',
      phone: '01033334444',
      lastTreatmentDate: _jan2026,
      treatmentType: '페이스',
      memberships: const [
        CustomerMembership(
          id: 'm1',
          serviceName: '관리 10회',
          totalVisits: 10,
          usedVisits: 7,
        ),
      ],
    );
    expect(remainBadgeLabelForCustomer(withMembership, store), '잔여 3회');

    final noRemain = Customer(
      id: 'c3',
      name: '박지우',
      phone: '01055556666',
      lastTreatmentDate: _jan2026,
      treatmentType: '페이스',
    );
    store.membershipTickets.add(
      const MembershipTicket(
        id: 't1',
        shopId: 'shop-demo',
        customerId: 'c3',
        shopName: 'SORI',
        ticketName: '체험권',
        totalVisits: 5,
        usedVisits: 2,
      ),
    );
    expect(remainBadgeLabelForCustomer(noRemain, store), '잔여 3회');

    final empty = Customer(
      id: 'c4',
      name: '최유나',
      phone: '01077778888',
      lastTreatmentDate: _jan2026,
      treatmentType: '페이스',
    );
    expect(remainBadgeLabelForCustomer(empty, store), '잔여 없음');
  });

  testWidgets('선택 모드 진입 시 화면 이동 없이 체크박스와 메타데이터 표시',
      (tester) async {
    store.customers.addAll([
      Customer(
        id: 'sel-1',
        name: '하얀광부',
        phone: '01085878542',
        lastTreatmentDate: _jan2026,
        treatmentType: '페이스',
        memberships: const [
          CustomerMembership(
            id: 'm-sel',
            serviceName: '관리',
            totalVisits: 5,
            usedVisits: 1,
          ),
        ],
      ),
      Customer(
        id: 'sel-2',
        name: '하얀광부',
        phone: '01085878542',
        lastTreatmentDate: DateTime(2026, 1, 2),
        treatmentType: '페이스',
      ),
    ]);
    store.charts.addAll([
      CustomerChart(
        id: 'ch-s1',
        shopId: store.shop.id,
        customerId: 'sel-1',
        visitNumber: 12,
        customChartNo: '1024',
        careName: '페이스',
      ),
      CustomerChart(
        id: 'ch-s2',
        shopId: store.shop.id,
        customerId: 'sel-2',
        visitNumber: 8,
        customChartNo: '2048',
        careName: '페이스',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectorCustomersTab(store: store),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Chart #1024'), findsOneWidget);
    expect(find.text('Chart #2048'), findsOneWidget);
    expect(find.text('잔여 4회'), findsOneWidget);
    expect(find.text('잔여 없음'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('선택'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('Chart #1024'), findsOneWidget);
    expect(find.text('잔여 4회'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });
}
