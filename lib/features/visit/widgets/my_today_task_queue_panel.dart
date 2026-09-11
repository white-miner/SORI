import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../views/chart_management_page.dart';
import '../home_visual_tokens.dart';
import '../my_today_task_queue.dart';

/// PRD v7.9 Phase 2 — 업무 큐 ≤3 · peek 없음 · Timer/결제 UI 없음.
class MyTodayTaskQueuePanel extends StatelessWidget {
  const MyTodayTaskQueuePanel({
    super.key,
    required this.store,
    DateTime? now,
  }) : _now = now;

  final SoriStore store;
  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final tasks = MyTodayTaskQueue.buildIncompleteRecordTasks(
      charts: store.charts,
      customerNameOf: (id) => store.findCustomer(id)?.name ?? '',
      now: _now,
    );

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
            '지금 처리할 일',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Text(
              '지금 남겨둘 기록이 없어요. 아래 오늘 일정을 확인하세요.',
              style: TextStyle(
                fontSize: 13,
                color: HomeVisualTokens.dateIconColor,
              ),
            )
          else
            ...tasks.map((t) => _TaskCard(
                  item: t,
                  onRecord: () => _openRecord(context, t),
                )),
        ],
      ),
    );
  }

  Future<void> _openRecord(BuildContext context, MyTodayTaskItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChartManagementPage(
          store: store,
          customerId: item.customerId,
          initialChartId: item.chartId,
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.onRecord,
  });

  final MyTodayTaskItem item;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRecord,
              style: TextButton.styleFrom(
                foregroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '기록하기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
