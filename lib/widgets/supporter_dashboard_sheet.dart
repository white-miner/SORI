import 'package:flutter/material.dart';

import '../models/fan_supporter.dart';
import '../theme/sori_tokens.dart';
import 'fan_sponsor_credits.dart';

enum SupporterSort { echoDesc, recent, countDesc }

Future<void> showSupporterDashboardSheet(
  BuildContext context, {
  required List<FanSupporterEntry> supporters,
  int followerCount = 0,
  int supporterCount = 0,
  SupporterSort initialSort = SupporterSort.echoDesc,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SupporterDashboardSheet(
      supporters: supporters,
      followerCount: followerCount,
      supporterCount: supporterCount,
      initialSort: initialSort,
    ),
  );
}

class _SupporterDashboardSheet extends StatefulWidget {
  const _SupporterDashboardSheet({
    required this.supporters,
    required this.followerCount,
    required this.supporterCount,
    required this.initialSort,
  });

  final List<FanSupporterEntry> supporters;
  final int followerCount;
  final int supporterCount;
  final SupporterSort initialSort;

  @override
  State<_SupporterDashboardSheet> createState() =>
      _SupporterDashboardSheetState();
}

class _SupporterDashboardSheetState extends State<_SupporterDashboardSheet> {
  late SupporterSort _sort = widget.initialSort;

  List<FanSupporterEntry> get _sorted {
    final list = List<FanSupporterEntry>.from(
      FanSupporterEntry.ranked(widget.supporters),
    );
    switch (_sort) {
      case SupporterSort.echoDesc:
        return list;
      case SupporterSort.countDesc:
        list.sort((a, b) => b.boostCount.compareTo(a.boostCount));
        return list;
      case SupporterSort.recent:
        return list;
    }
  }

  String _tierLabel(int rank, FanSupporterEntry row) {
    if (rank == 1 && row.echoSpent >= 50) return '탑 후원자';
    if (rank <= 3 && row.echoSpent >= 200) return '프리미엄 후원자';
    return '후원자';
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _sorted;
    final h = MediaQuery.sizeOf(context).height * 0.62;

    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '후원자 관리',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '팔로워 ${widget.followerCount}명 · 후원자 ${widget.supporterCount}명',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<SupporterSort>(
                segments: const [
                  ButtonSegment(
                    value: SupporterSort.recent,
                    label: Text('최신순', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: SupporterSort.countDesc,
                    label: Text('횟수순', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: SupporterSort.echoDesc,
                    label: Text('누적 Echo', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => setState(() => _sort = s.first),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ranked.isEmpty
                  ? const Center(
                      child: Text(
                        '아직 후원자가 없어요.',
                        style: TextStyle(color: SoriTokens.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: ranked.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final row = ranked[i];
                        final rank = i + 1;
                        return Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            SupporterFacepile(
                              supporters: [row],
                              size: 36,
                              maxVisible: 1,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  Text(
                                    _tierLabel(rank, row),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: SoriTokens.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${row.echoSpent}E',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
