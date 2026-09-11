import 'package:flutter/material.dart';

import '../../visit_kernel/models/care_schedule_entry.dart';
import '../care_schedule_read_density.dart';
import '../home_visual_tokens.dart';

/// PRD v7.9 Phase 1 — 마이 오늘 일정 읽기 전용 (CRUD/큐/Timer/KPI 없음).
class MyTodayScheduleReadPanel extends StatelessWidget {
  const MyTodayScheduleReadPanel({
    super.key,
    required this.entries,
    DateTime? now,
  }) : _now = now;

  final List<CareScheduleEntry> entries;
  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final list = CareScheduleReadDensity.myTodayReadList(entries, now: now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 일정',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '읽기 전용 · 수정은 이후 단계에서',
            style: TextStyle(
              fontSize: 11,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Text(
              '오늘 예정된 일정이 없어요.',
              style: TextStyle(
                fontSize: 13,
                color: HomeVisualTokens.dateIconColor,
              ),
            )
          else
            ...list.map(_row),
        ],
      ),
    );
  }

  Widget _row(CareScheduleEntry e) {
    final note = CareScheduleReadDensity.notePreview(e);
    final completed = e.status == CareScheduleStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CareScheduleReadDensity.timeLabel(e.scheduledAt),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeVisualTokens.dateIconColor,
              decoration: completed ? TextDecoration.none : null,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    e.customerName.trim().isEmpty
                        ? '고객'
                        : e.customerName.trim(),
                    if (e.careLabel.trim().isNotEmpty) e.careLabel.trim(),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? HomeVisualTokens.dateIconColor
                        : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
              if (completed)
                Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 11,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
