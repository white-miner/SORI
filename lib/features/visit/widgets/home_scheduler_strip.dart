import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/care_schedule_entry.dart';
import '../home_visual_tokens.dart';

/// PRD v7.0 ① — 플립 시계 하단 스케줄러 스트립.
///
/// 오늘 남은 일정 중 가장 가까운 1건을 `12:30 김민정님 상담예약` 형태로 보여주고,
/// 탭하면 시간대별 일정 시트로 진입한다.
class HomeSchedulerStrip extends StatelessWidget {
  const HomeSchedulerStrip({
    super.key,
    required this.store,
    required this.onTap,
  });

  final SoriStore store;
  final VoidCallback onTap;

  /// 오늘 일정 중 `scheduled` 상태만, 시간순.
  static List<CareScheduleEntry> todayEntries(SoriStore store) {
    final now = DateTime.now();
    final list = store.careScheduleEntries
        .where((e) =>
            e.status == CareScheduleStatus.scheduled && e.isSameDay(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// 아직 지나지 않은 가장 가까운 일정. 없으면 오늘 마지막 일정으로 폴백.
  static CareScheduleEntry? nextEntry(SoriStore store) {
    final list = todayEntries(store);
    if (list.isEmpty) return null;
    final now = DateTime.now();
    for (final e in list) {
      if (!e.scheduledAt.isBefore(now)) return e;
    }
    return list.last;
  }

  static String labelFor(CareScheduleEntry entry) {
    final hh = entry.scheduledAt.hour.toString().padLeft(2, '0');
    final mm = entry.scheduledAt.minute.toString().padLeft(2, '0');
    final name = entry.customerName.trim();
    final care = entry.careLabel.trim();
    return [
      '$hh:$mm',
      if (name.isNotEmpty) '$name님',
      if (care.isNotEmpty) care,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = todayEntries(store);
    final next = nextEntry(store);
    final upcoming = next != null;
    final extra = entries.length - 1;

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
                        : '오늘 예약된 일정이 없습니다',
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
                if (extra > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+$extra',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: HomeVisualTokens.dateIconColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
