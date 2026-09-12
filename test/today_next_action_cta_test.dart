import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/widgets/home_scheduler_strip.dart';
import 'package:sori/features/visit/widgets/my_today_task_queue_panel.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

CareScheduleEntry _entry({
  required String id,
  required DateTime at,
  required String name,
  String care = '관리',
  String? customerId,
}) {
  return CareScheduleEntry(
    id: id,
    shopId: 'shop',
    scheduledAt: at,
    customerName: name,
    customerId: customerId,
    careLabel: care,
  );
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('today glance row tap starts care; card body does not open sheet', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = SoriStore();
    store.careScheduleEntries = [
      _entry(
        id: 'e1',
        at: DateTime(now.year, now.month, now.day, 14),
        name: '김민정',
        customerId: 'c1',
      ),
      _entry(
        id: 'e2',
        at: DateTime(now.year, now.month, now.day, 16),
        name: '최진실',
        customerId: 'c2',
      ),
    ];

    CareScheduleEntry? started;
    var sheetOpens = 0;

    await tester.pumpWidget(
      _host(
        HomeScheduleGlance(
          store: store,
          onTap: () => sheetOpens++,
          onCareStart: (e) => started = e,
        ),
      ),
    );

    await tester.tap(find.text('이번 주 일정'));
    await tester.pump();
    expect(sheetOpens, 0);
    expect(started, isNull);

    await tester.tap(find.byKey(const Key('home-today-glance-row-e2')));
    await tester.pump();
    expect(started?.id, 'e2');
    expect(sheetOpens, 0);
  });

  testWidgets('overflow chip opens the full today list, not care start', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = SoriStore();
    store.careScheduleEntries = [
      for (var i = 0; i < 4; i++)
        _entry(
          id: 'e$i',
          at: DateTime(now.year, now.month, now.day, 10 + i),
          name: '고객$i',
          customerId: 'c$i',
        ),
    ];

    var sheetOpens = 0;
    CareScheduleEntry? started;

    await tester.pumpWidget(
      _host(
        HomeScheduleGlance(
          store: store,
          onTap: () => sheetOpens++,
          onCareStart: (e) => started = e,
        ),
      ),
    );

    expect(find.text('+1건'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-today-schedule-overflow')));
    await tester.pump();
    expect(sheetOpens, 1);
    expect(started, isNull);
  });

  testWidgets('hero next-strip tap is wired for the next customer', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = SoriStore();
    store.careScheduleEntries = [
      _entry(
        id: 'e1',
        at: DateTime(now.year, now.month, now.day, 14),
        name: '김민정',
        customerId: 'c1',
      ),
    ];
    var taps = 0;
    await tester.pumpWidget(
      _host(HomeSchedulerStrip(store: store, onTap: () => taps++)),
    );
    await tester.tap(find.byKey(const Key('home-today-next-strip')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('empty glance offers returning-customer start, not a sheet', (
    tester,
  ) async {
    final store = SoriStore();
    store.careScheduleEntries = [];
    var emptyStarts = 0;
    var sheetOpens = 0;

    await tester.pumpWidget(
      _host(
        HomeScheduleGlance(
          store: store,
          onTap: () => sheetOpens++,
          onEmptyStart: () => emptyStarts++,
        ),
      ),
    );

    expect(find.text('오늘 예정된 일정이 없어요.'), findsOneWidget);
    expect(find.byKey(const Key('home-today-empty-start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-today-empty-start')));
    await tester.pump();
    expect(emptyStarts, 1);
    expect(sheetOpens, 0);
  });

  test('launcher empty today starts returning flow instead of a dead sheet', () {
    final src = File('lib/features/visit/visit_launcher_page.dart').readAsStringSync();
    expect(src.contains('_onNextScheduleTap'), isTrue);
    expect(src.contains('_startCareFromSchedule'), isTrue);
    expect(src.contains('onSelect: (entry)'), isTrue);
    expect(src.contains('Navigator.of(ctx).pop()'), isTrue);
    expect(src.contains('_startCareFromSchedule(entry)'), isTrue);
    expect(src.contains('HomeScheduleGlance'), isTrue);
    expect(src.contains('onCareStart: _startCareFromSchedule'), isTrue);
    expect(src.contains('onEmptyStart: () => unawaited(_startReturningCustomerFlow())'), isTrue);
    expect(src.contains('unawaited(_startReturningCustomerFlow())'), isTrue);
  });

  testWidgets('incomplete record queue shows existing chart resume CTA', (
    tester,
  ) async {
    final store = SoriStore();
    store.charts.add(
      CustomerChart(
        id: 'ch1',
        shopId: 'shop',
        customerId: 'c1',
        visitNumber: 1,
        visitChecked: true,
        visitCheckedAt: DateTime.now(),
      ),
    );
    store.customers.add(
      Customer(
        id: 'c1',
        shopId: 'shop',
        name: '김민정',
        phone: '010',
        lastTreatmentDate: DateTime(2026, 1, 1),
        treatmentType: '관리',
      ),
    );

    await tester.pumpWidget(
      _host(MyTodayTaskQueuePanel(store: store)),
    );

    expect(find.text('지금 처리할 일'), findsOneWidget);
    expect(find.textContaining('김민정'), findsOneWidget);
    expect(find.text('시술 요약이 아직 없어요'), findsOneWidget);
    expect(find.text('기록하기'), findsOneWidget);
  });

  test('launcher surfaces incomplete-record queue before today glance', () {
    final src = File('lib/features/visit/visit_launcher_page.dart').readAsStringSync();
    expect(src.contains('MyTodayTaskQueue.buildIncompleteRecordTasks'), isTrue);
    expect(src.contains("Key('home-today-followup-queue')"), isTrue);
    expect(src.contains('MyTodayTaskQueuePanel(store: widget.store)'), isTrue);
    final queueAt = src.indexOf("Key('home-today-followup-queue')");
    final glanceAt = src.indexOf('HomeScheduleGlance(');
    expect(queueAt, greaterThan(0));
    expect(glanceAt, greaterThan(queueAt));
  });
}
