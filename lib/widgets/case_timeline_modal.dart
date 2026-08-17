import 'package:flutter/material.dart';

import '../models/case_timeline_entry.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';

/// 피드 B/A 클릭 → 동일 고객·태그 회차 타임라인 모달.
class CaseTimelineModal extends StatefulWidget {
  const CaseTimelineModal({
    super.key,
    required this.store,
    required this.chartId,
    required this.careLabel,
    this.onOpenFullScreen,
  });

  final SoriStore store;
  final String chartId;
  final String careLabel;
  final VoidCallback? onOpenFullScreen;

  static Future<void> show(
    BuildContext context, {
    required SoriStore store,
    required String chartId,
    required String careLabel,
    VoidCallback? onOpenFullScreen,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CaseTimelineModal(
        store: store,
        chartId: chartId,
        careLabel: careLabel,
        onOpenFullScreen: onOpenFullScreen,
      ),
    );
  }

  @override
  State<CaseTimelineModal> createState() => _CaseTimelineModalState();
}

class _CaseTimelineModalState extends State<CaseTimelineModal> {
  late Future<List<CaseTimelineEntry>> _future;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.store.loadCaseTimelineGroup(widget.chartId);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return FutureBuilder<List<CaseTimelineEntry>>(
            future: _future,
            builder: (context, snap) {
              final entries = snap.data ?? const <CaseTimelineEntry>[];
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: SoriTokens.primary),
                );
              }
              if (entries.isEmpty) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      '다회차 타임라인',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '연결된 이전 회차가 없습니다.\n${widget.careLabel}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }

              final idx = _selectedIndex.clamp(0, entries.length - 1);
              final selected = entries[idx];

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '다회차 타임라인 · ${entries.length}회',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.careLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final on = i == idx;
                        return ChoiceChip(
                          selected: on,
                          label: Text(
                            '${e.visitNumber}회',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : SoriTokens.textPrimary,
                            ),
                          ),
                          selectedColor: SoriTokens.primary,
                          onSelected: (_) => setState(() => _selectedIndex = i),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BeforeAfterSlider(
                      height: 260,
                      before: ChartImagePane(
                        url: selected.beforeImageUrl,
                        fallbackLabel: 'Before',
                        tone: SoriTokens.primary,
                      ),
                      after: ChartImagePane(
                        url: selected.afterImageUrl,
                        fallbackLabel: 'After',
                        tone: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected.careName.trim().isEmpty
                        ? '${selected.visitNumber}회차'
                        : '${selected.visitNumber}회차 · ${selected.careName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (selected.careTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selected.careTags.map((t) {
                        final label =
                            t.trim().startsWith('#') ? t.trim() : '#$t';
                        return Chip(
                          label: Text(label, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: SoriTokens.primarySoft,
                        );
                      }).toList(),
                    ),
                  ],
                  if (widget.onOpenFullScreen != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenFullScreen!();
                      },
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      label: const Text('전체화면 B/A 보기'),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
