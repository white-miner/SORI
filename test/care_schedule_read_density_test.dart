import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/care_schedule_read_density.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

CareScheduleEntry _e({
  required String id,
  required DateTime at,
  CareScheduleStatus status = CareScheduleStatus.scheduled,
  String note = '',
  String name = '고객',
  String? customerId,
}) {
  return CareScheduleEntry(
    id: id,
    shopId: 'shop',
    scheduledAt: at,
    customerName: name,
    customerId: customerId,
    note: note,
    status: status,
  );
}

void main() {
  final day = DateTime(2026, 9, 11, 12);
  final monday = DateTime(2026, 9, 7);

  test('homeWeekAnchor is Monday local', () {
    expect(
      CareScheduleReadDensity.homeWeekAnchor(day),
      DateTime(2026, 9, 7),
    );
  });

  test('cancelled excluded from week counts and today top', () {
    final all = [
      _e(id: 'a', at: DateTime(2026, 9, 11, 10), note: '메모'),
      _e(
        id: 'b',
        at: DateTime(2026, 9, 11, 11),
        status: CareScheduleStatus.cancelled,
      ),
      _e(id: 'c', at: DateTime(2026, 9, 11, 14)),
      _e(id: 'd', at: DateTime(2026, 9, 11, 16)),
      _e(id: 'e', at: DateTime(2026, 9, 11, 18)),
    ];
    final counts = CareScheduleReadDensity.weekDayCounts(all, now: day);
    expect(counts[4], 4); // Fri = index 4 from Mon
    final top = CareScheduleReadDensity.todayHomeTop(all, now: day);
    expect(top.items.length, 3);
    expect(top.overflow, 1);
    expect(top.items.every((e) => e.status != CareScheduleStatus.cancelled), true);
  });

  test('today sort prefers nearest future scheduledAt (no Timer)', () {
    final now = DateTime(2026, 9, 11, 12, 0);
    final all = [
      _e(id: 'past', at: DateTime(2026, 9, 11, 9)),
      _e(id: 'soon', at: DateTime(2026, 9, 11, 13)),
      _e(id: 'later', at: DateTime(2026, 9, 11, 17)),
    ];
    final sorted = CareScheduleReadDensity.todayScheduledSorted(all, now: now);
    expect(sorted.map((e) => e.id).toList(), ['soon', 'later', 'past']);
  });

  test('notePreview hides empty', () {
    final empty = _e(id: '1', at: day, note: '  ');
    final filled = _e(id: '2', at: day, note: '진정 반응 확인');
    expect(CareScheduleReadDensity.notePreview(empty), isNull);
    expect(CareScheduleReadDensity.notePreview(filled), '진정 반응 확인');
  });

  test('myToday hides cancelled and sorts ascending', () {
    final all = [
      _e(id: '2', at: DateTime(2026, 9, 11, 14)),
      _e(
        id: 'x',
        at: DateTime(2026, 9, 11, 10),
        status: CareScheduleStatus.cancelled,
      ),
      _e(
        id: '1',
        at: DateTime(2026, 9, 11, 9),
        status: CareScheduleStatus.completed,
      ),
    ];
    final list = CareScheduleReadDensity.myTodayReadList(all, now: day);
    expect(list.map((e) => e.id).toList(), ['1', '2']);
  });

  test('week counts ignore other weeks', () {
    final all = [
      _e(id: 't', at: DateTime(2026, 9, 11, 10)),
      _e(id: 'sameWeek', at: DateTime(2026, 9, 12, 10)),
      _e(id: 'next', at: DateTime(2026, 9, 14, 10)),
    ];
    final counts = CareScheduleReadDensity.weekDayCounts(all, now: day);
    expect(counts.reduce((a, b) => a + b), 2);
    expect(CareScheduleReadDensity.homeWeekAnchor(day), monday);
  });

  test('nextUpcomingForCustomer skips other customers and past days', () {
    final now = DateTime(2026, 9, 11, 12);
    final all = [
      _e(
        id: 'past',
        at: DateTime(2026, 9, 10, 18),
        customerId: 'c1',
      ),
      _e(
        id: 'other',
        at: DateTime(2026, 9, 11, 13),
        customerId: 'c2',
      ),
      _e(
        id: 'later',
        at: DateTime(2026, 9, 12, 10),
        customerId: 'c1',
      ),
      _e(
        id: 'soon',
        at: DateTime(2026, 9, 11, 15),
        customerId: 'c1',
      ),
      _e(
        id: 'done',
        at: DateTime(2026, 9, 11, 14),
        customerId: 'c1',
        status: CareScheduleStatus.completed,
      ),
    ];
    final next = CareScheduleReadDensity.nextUpcomingForCustomer(
      all,
      customerId: 'c1',
      now: now,
    );
    expect(next?.id, 'soon');
  });
}
