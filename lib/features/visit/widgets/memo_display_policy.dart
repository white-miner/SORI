import '../../../visit_kernel/models/care_schedule_entry.dart';

class MemoDisplayItem {
  const MemoDisplayItem({
    required this.entry,
    required this.showDatePrefix,
  });

  final CareScheduleEntry entry;
  final bool showDatePrefix;
}

/// PRD v5.3 — memo stack data resolution for home hero.
abstract final class MemoDisplayPolicy {
  static List<CareScheduleEntry> activeEntries(
    List<CareScheduleEntry> all,
  ) {
    return all
        .where((e) => e.status != CareScheduleStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  static MemoDisplayItem? collapsedChip({
    required List<CareScheduleEntry> entries,
    required DateTime now,
  }) {
    final active = activeEntries(entries);
    if (active.isEmpty) return null;

    final today = DateTime(now.year, now.month, now.day);
    final todayList =
        active.where((e) => e.isSameDay(today)).toList();

    if (todayList.isNotEmpty) {
      final upcoming = todayList
          .where((e) => !e.scheduledAt.isBefore(now))
          .toList();
      final pick = upcoming.isNotEmpty ? upcoming.first : todayList.last;
      return MemoDisplayItem(entry: pick, showDatePrefix: false);
    }

    final future = active.where((e) => e.scheduledAt.isAfter(now)).toList();
    if (future.isEmpty) return null;
    return MemoDisplayItem(entry: future.first, showDatePrefix: true);
  }

  static List<MemoDisplayItem> expandedList({
    required List<CareScheduleEntry> entries,
    required DateTime now,
  }) {
    final active = activeEntries(entries);
    final todayStart = DateTime(now.year, now.month, now.day);
    final list = active
        .where((e) => !e.scheduledAt.isBefore(todayStart))
        .toList();
    return [
      for (final e in list)
        MemoDisplayItem(
          entry: e,
          showDatePrefix: !e.isSameDay(now),
        ),
    ];
  }

  static String formatChipLabel(MemoDisplayItem item) {
    final e = item.entry;
    final time =
        '${e.scheduledAt.hour.toString().padLeft(2, '0')}:'
        '${e.scheduledAt.minute.toString().padLeft(2, '0')}';
    final name = e.customerName.trim().isEmpty ? '메모' : e.customerName.trim();
    final note = e.note.trim();
    final care = e.careLabel.trim();
    final body = note.isNotEmpty
        ? note
        : (care.isNotEmpty ? care : '상담예약');
    final prefix = item.showDatePrefix
        ? '(${e.scheduledAt.month}/${e.scheduledAt.day}) '
        : '';
    return '$prefix$time $name $body'.trim();
  }
}
