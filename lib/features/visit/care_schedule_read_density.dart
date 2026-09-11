import '../../visit_kernel/models/care_schedule_entry.dart';

/// PRD v7.9 Phase 1 — care_schedule 읽기 밀도 헬퍼 (SSOT 필터만 · Timer/visitChecked 미사용).
abstract final class CareScheduleReadDensity {
  CareScheduleReadDensity._();

  /// 로컬 캘린더 기준 이번 주 월요일 00:00.
  static DateTime homeWeekAnchor([DateTime? now]) {
    final n = now ?? DateTime.now();
    final day = DateTime(n.year, n.month, n.day);
    final mondayOffset = (day.weekday - DateTime.monday) % 7;
    return day.subtract(Duration(days: mondayOffset));
  }

  static DateTime homeWeekEnd(DateTime anchor) =>
      anchor.add(const Duration(days: 7));

  static bool _isCancelled(CareScheduleEntry e) =>
      e.status == CareScheduleStatus.cancelled;

  /// 주간 점/숫자 · 오늘 목록 후보: cancelled 제외.
  static List<CareScheduleEntry> visibleForGlance(
    Iterable<CareScheduleEntry> all,
  ) {
    return all.where((e) => !_isCancelled(e)).toList();
  }

  /// 주간 스트립 집계용 (cancelled 제외 · scheduled + completed).
  static int countOnDay(
    Iterable<CareScheduleEntry> all,
    DateTime day,
  ) {
    final d = DateTime(day.year, day.month, day.day);
    return visibleForGlance(all).where((e) => e.isSameDay(d)).length;
  }

  /// 월~일 7칸 카운트 (homeWeekAnchor 기준).
  static List<int> weekDayCounts(
    Iterable<CareScheduleEntry> all, {
    DateTime? now,
  }) {
    final anchor = homeWeekAnchor(now);
    return List.generate(7, (i) {
      final day = anchor.add(Duration(days: i));
      return countOnDay(all, day);
    });
  }

  /// 오늘 scheduled만 · 가까운 미래 우선 정렬 (§5.1-A: 종료시각 없음).
  static List<CareScheduleEntry> todayScheduledSorted(
    Iterable<CareScheduleEntry> all, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final list = all
        .where(
          (e) =>
              e.status == CareScheduleStatus.scheduled && e.isSameDay(n),
        )
        .toList();
    list.sort((a, b) => _compareNearFutureFirst(a, b, n));
    return list;
  }

  /// 홈 오늘 상위 최대 [limit]건 + 초과 개수.
  static ({List<CareScheduleEntry> items, int overflow}) todayHomeTop(
    Iterable<CareScheduleEntry> all, {
    DateTime? now,
    int limit = 3,
  }) {
    final sorted = todayScheduledSorted(all, now: now);
    if (sorted.length <= limit) {
      return (items: sorted, overflow: 0);
    }
    return (
      items: sorted.sublist(0, limit),
      overflow: sorted.length - limit,
    );
  }

  /// 마이 오늘: cancelled 숨김 · scheduledAt 오름차순 (completed 포함 가능).
  static List<CareScheduleEntry> myTodayReadList(
    Iterable<CareScheduleEntry> all, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final list = visibleForGlance(all).where((e) => e.isSameDay(n)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// note 미리보기 · 비어 있으면 null (아이콘/행 숨김).
  static String? notePreview(CareScheduleEntry e, {int maxChars = 40}) {
    final raw = e.note.trim();
    if (raw.isEmpty) return null;
    final firstLine = raw.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.isEmpty) return null;
    if (firstLine.length <= maxChars) return firstLine;
    return '${firstLine.substring(0, maxChars).trimRight()}…';
  }

  static String timeLabel(DateTime at) {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// 종료 시각 없음 → 아직 시작 전인 일정 우선, 없으면 지난 일정 중 늦은 것.
  static int _compareNearFutureFirst(
    CareScheduleEntry a,
    CareScheduleEntry b,
    DateTime now,
  ) {
    final aFuture = !a.scheduledAt.isBefore(now);
    final bFuture = !b.scheduledAt.isBefore(now);
    if (aFuture && !bFuture) return -1;
    if (!aFuture && bFuture) return 1;
    if (aFuture && bFuture) {
      return a.scheduledAt.compareTo(b.scheduledAt);
    }
    return b.scheduledAt.compareTo(a.scheduledAt);
  }
}
