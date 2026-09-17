import 'package:flutter/material.dart';

import '../models/care_diary_note.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_date_picker.dart';
import '../theme/sori_tokens.dart';

/// 케어 히스토리 뷰어 캘린더 — 방문(파란점) / 턴오버 권장일(빨간점) + 다이어리.
class CareViewerCalendarPage extends StatefulWidget {
  const CareViewerCalendarPage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<CareViewerCalendarPage> createState() => _CareViewerCalendarPageState();
}

class _CareViewerCalendarPageState extends State<CareViewerCalendarPage> {
  late DateTime _month;
  DateTime? _selected;

  static const int _turnoverDays = 28;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<CustomerChart> get _charts =>
      widget.store.chartsForCustomer(widget.customerId);

  Set<DateTime> get _visitDays {
    final out = <DateTime>{};
    for (final c in _charts) {
      final d = c.visitCheckedAt ?? c.createdAt;
      if (d == null) continue;
      out.add(DateTime(d.year, d.month, d.day));
    }
    return out;
  }

  Set<DateTime> get _recommendDays {
    final out = <DateTime>{};
    for (final v in _visitDays) {
      final r = v.add(const Duration(days: _turnoverDays));
      out.add(DateTime(r.year, r.month, r.day));
    }
    return out;
  }

  CustomerChart? _chartOn(DateTime day) {
    for (final c in _charts) {
      final d = c.visitCheckedAt ?? c.createdAt;
      if (d == null) continue;
      if (CareDiaryNote.sameDay(d, day)) return c;
    }
    return null;
  }

  Future<void> _editMemo(DateTime day) async {
    final existing = widget.store.diaryNoteFor(
      customerId: widget.customerId,
      day: day,
    );
    final controller = TextEditingController(text: existing?.body ?? '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                MediaQuery.paddingOf(ctx).bottom +
                16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${day.year}.${day.month.toString().padLeft(2, '0')}.${day.day.toString().padLeft(2, '0')} 메모',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '예: 각질이 일어남, 당김이 심함',
                style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '오늘의 피부 상태를 적어 두세요',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (saved == null) return;
    await widget.store.saveCareDiaryNote(
      customerId: widget.customerId,
      day: day,
      body: saved,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('다이어리 메모가 저장되었어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final selected = _selected;
    final chart = selected == null ? null : _chartOn(selected);
    final memo = selected == null
        ? null
        : widget.store.diaryNoteFor(
            customerId: widget.customerId,
            day: selected,
          );

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('케어 히스토리 캘린더'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SoriGlassPanel(
            borderRadius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _month = DateTime(_month.year, _month.month - 1);
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${_month.year}년 ${_month.month}월',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _month = DateTime(_month.year, _month.month + 1);
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Expanded(child: _Dow('일')),
                    Expanded(child: _Dow('월')),
                    Expanded(child: _Dow('화')),
                    Expanded(child: _Dow('수')),
                    Expanded(child: _Dow('목')),
                    Expanded(child: _Dow('금')),
                    Expanded(child: _Dow('토')),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: firstWeekday + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) {
                      return const SizedBox.shrink();
                    }
                    final day = index - firstWeekday + 1;
                    final date = DateTime(_month.year, _month.month, day);
                    final isSelected =
                        selected != null && CareDiaryNote.sameDay(selected, date);
                    final hasVisit = _visitDays.any(
                      (d) => CareDiaryNote.sameDay(d, date),
                    );
                    final hasRec = _recommendDays.any(
                      (d) => CareDiaryNote.sameDay(d, date),
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selected = date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SoriTokens.primary.withValues(alpha: 0.12)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? SoriTokens.primary
                                    : SoriTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasVisit)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0984E3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasVisit && hasRec)
                                  const SizedBox(width: 3),
                                if (hasRec)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE17055),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _LegendDot(color: const Color(0xFF0984E3), label: '시술일'),
                    const SizedBox(width: 14),
                    _LegendDot(
                      color: const Color(0xFFE17055),
                      label: '권장 방문(+$_turnoverDays일)',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (selected != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected.year}.${selected.month.toString().padLeft(2, '0')}.${selected.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (chart != null) ...[
                    Text(
                      chart.careName.isNotEmpty
                          ? chart.careName
                          : '시술 기록',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (chart.directorInsight.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '원장 코멘트: ${chart.directorInsight.trim()}',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      '이 날의 시술 기록은 없어요',
                      style: const TextStyle(color: SoriTokens.textSecondary, fontSize: 13),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '내 다이어리',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (memo?.body.trim().isNotEmpty == true)
                        ? memo!.body.trim()
                        : '아직 메모가 없어요',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: (memo?.body.trim().isNotEmpty == true)
                          ? SoriTokens.textPrimary
                          : SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _editMemo(selected),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text(
                      '메모 작성 / 수정',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      side: const BorderSide(color: SoriTokens.primary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: SoriTokens.textSecondary,
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: SoriTokens.textSecondary)),
      ],
    );
  }
}
