import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/care_schedule_entry.dart';
import '../care_schedule_read_density.dart';
import '../home_visual_tokens.dart';

/// PRD v7.0 ① — 히어로 하단 컴팩트 다음 일정 바 (읽기 · Timer 무관).
///
/// Phase 1: [CareScheduleReadDensity] 사용. 상세 glance는 [HomeScheduleGlance].
class HomeSchedulerStrip extends StatelessWidget {
  const HomeSchedulerStrip({
    super.key,
    required this.store,
    required this.onTap,
  });

  final SoriStore store;
  final VoidCallback onTap;

  /// 오늘 `scheduled` · 가까운 미래 우선 (§5.1-A).
  static List<CareScheduleEntry> todayEntries(SoriStore store) {
    return CareScheduleReadDensity.todayScheduledSorted(
      store.careScheduleEntries,
    );
  }

  static CareScheduleEntry? nextEntry(SoriStore store) {
    final list = todayEntries(store);
    if (list.isEmpty) return null;
    return list.first;
  }

  static String labelFor(CareScheduleEntry entry) {
    final name = entry.customerName.trim();
    final care = entry.careLabel.trim();
    return [
      CareScheduleReadDensity.timeLabel(entry.scheduledAt),
      if (name.isNotEmpty) '$name님',
      if (care.isNotEmpty) care,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final next = nextEntry(store);
    final upcoming = next != null;
    final top = CareScheduleReadDensity.todayHomeTop(store.careScheduleEntries);
    final extra = top.overflow;

    return Material(
      color: HomeVisualTokens.presetLabelFill,
      borderRadius: BorderRadius.circular(HomeVisualTokens.memoBarRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeVisualTokens.memoBarRadius),
        child: SizedBox(
          height: HomeVisualTokens.memoBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeVisualTokens.memoDotInset,
            ),
            child: Row(
              children: [
                Container(
                  width: HomeVisualTokens.memoDotSize,
                  height: HomeVisualTokens.memoDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: upcoming
                        ? HomeVisualTokens.memoActiveFill
                        : HomeVisualTokens.memoIdleFill,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    upcoming
                        ? labelFor(next)
                        : '오늘 예정된 일정이 없어요.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: HomeVisualTokens.memoTextSize,
                      fontWeight: FontWeight.w600,
                      color: upcoming
                          ? HomeVisualTokens.dateTextColor
                          : HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
                if (extra > 0)
                  Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 11,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PRD v7.9 Phase 1 — 홈 주간 스트립 + 오늘 ≤3 · note 1줄 · 읽기 전용.
class HomeScheduleGlance extends StatelessWidget {
  const HomeScheduleGlance({
    super.key,
    required this.store,
    this.onTap,
    this.onCareStart,
    DateTime? now,
  }) : _now = now;

  final SoriStore store;
  final VoidCallback? onTap;
  final ValueChanged<CareScheduleEntry>? onCareStart;
  final DateTime? _now;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final anchor = CareScheduleReadDensity.homeWeekAnchor(now);
    final counts = CareScheduleReadDensity.weekDayCounts(
      store.careScheduleEntries,
      now: now,
    );
    final todayIndex = (now.weekday - DateTime.monday) % 7;
    final top = CareScheduleReadDensity.todayHomeTop(
      store.careScheduleEntries,
      now: now,
    );

    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateHeading(now),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '이번 주 일정',
            style: TextStyle(
              fontSize: 11,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) {
              final isToday = i == todayIndex;
              final day = anchor.add(Duration(days: i));
              return Expanded(
                child: _WeekDayCell(
                  label: _weekdayLabels[i],
                  dayNum: day.day,
                  count: counts[i],
                  isToday: isToday,
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          const Text(
            '오늘',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          if (top.items.isEmpty)
            Text(
              '오늘 예정된 일정이 없어요.',
              style: TextStyle(
                fontSize: 13,
                color: HomeVisualTokens.dateIconColor,
              ),
            )
          else ...[
            ...top.items.asMap().entries.map((e) {
              final isPrimary = e.key == 0;
              return _todayRow(
                e.value,
                showCareStart: isPrimary && onCareStart != null,
                onCareStart: isPrimary
                    ? () => onCareStart?.call(e.value)
                    : null,
              );
            }),
            if (top.overflow > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${top.overflow}건',
                  style: TextStyle(
                    fontSize: 11,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: body,
      ),
    );
  }

  Widget _todayRow(
    CareScheduleEntry e, {
    bool showCareStart = false,
    VoidCallback? onCareStart,
  }) {
    final note = CareScheduleReadDensity.notePreview(e);
    final name = e.customerName.trim().isEmpty ? '고객' : e.customerName.trim();
    final care = e.careLabel.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              CareScheduleReadDensity.timeLabel(e.scheduledAt),
              name,
              if (care.isNotEmpty) care,
            ].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 12,
                  color: HomeVisualTokens.dateIconColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (showCareStart &&
              onCareStart != null &&
              (e.customerId?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onCareStart,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeVisualTokens.careGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '케어 시작',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateHeading(DateTime now) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.label,
    required this.dayNum,
    required this.count,
    required this.isToday,
  });

  final String label;
  final int dayNum;
  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final bg = isToday ? const Color(0xFF1C1C1E) : Colors.transparent;
    final fg = isToday ? Colors.white : const Color(0xFF1C1C1E);
    final sub = isToday ? Colors.white70 : HomeVisualTokens.dateIconColor;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? null
                : Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count.clamp(0, 3),
              (_) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? const Color(0xFF1C1C1E)
                      : HomeVisualTokens.memoActiveFill,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
