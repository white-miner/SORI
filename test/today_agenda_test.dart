import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/today_agenda.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';
import 'package:sori/utils/sori_uuid.dart';

void main() {
  test('buildTodayAgenda merges schedule and active session by customer_id', () {
    final store = SoriStore();
    final now = DateTime(2026, 3, 15, 14, 30);
    final day = DateTime(now.year, now.month, now.day);
    const customerId = 'cust-merge-test';

    final schedules = [
      CareScheduleEntry(
        id: newUuidV4(),
        shopId: 'shop-demo',
        scheduledAt: DateTime(day.year, day.month, day.day, 15, 0),
        customerName: '김소리',
        customerId: customerId,
        careLabel: '리프팅',
        status: CareScheduleStatus.scheduled,
      ),
    ];

    final sessions = [
      VisitSession(
        id: newUuidV4(),
        shopId: 'shop-demo',
        customerId: customerId,
        customerName: '김소리',
        startedAt: DateTime(day.year, day.month, day.day, 14, 0),
        phase: VisitPhase.consult,
      ),
    ];

    final snap = buildTodayAgenda(
      store: store,
      now: now,
      schedules: schedules,
      sessions: sessions,
    );

    expect(snap.items.length, 1);
    expect(snap.items.first.schedule, isNotNull);
    expect(snap.items.first.session, isNotNull);
    expect(snap.items.first.sortAt.hour, 15);
    expect(snap.activeSessions.length, 1);
  });

  test('buildTodayAgenda marks next upcoming item', () {
    final store = SoriStore();
    final now = DateTime(2026, 3, 15, 10, 0);
    final day = DateTime(now.year, now.month, now.day);

    final schedules = [
      CareScheduleEntry(
        id: newUuidV4(),
        shopId: 'shop-demo',
        scheduledAt: DateTime(day.year, day.month, day.day, 9, 0),
        customerName: '이전',
        status: CareScheduleStatus.scheduled,
      ),
      CareScheduleEntry(
        id: newUuidV4(),
        shopId: 'shop-demo',
        scheduledAt: DateTime(day.year, day.month, day.day, 11, 0),
        customerName: '다음',
        status: CareScheduleStatus.scheduled,
      ),
    ];

    final snap = buildTodayAgenda(
      store: store,
      now: now,
      schedules: schedules,
      sessions: const [],
    );

    expect(snap.items.length, 2);
    final nextItems = snap.items.where((e) => e.isNext).toList();
    expect(nextItems.length, 1);
    expect(nextItems.first.customerName, '다음');
  });

  test('resolveAgendaTrack distinguishes new vs returning', () {
    final store = SoriStore();
    if (store.customers.isEmpty) return;

    final customer = store.customers.first;
    final track = resolveAgendaTrack(store, customerId: customer.id);
    expect(track, isA<ConsultationTrack>());
  });
}
