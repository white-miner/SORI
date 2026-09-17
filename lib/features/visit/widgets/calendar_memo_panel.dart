import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_schedule_entry.dart';
import '../../operation/widgets/volume_glass_theme.dart';

/// PRD v5.2 Phase D — lightweight calendar memo pad (reuses care_schedule_entries).
enum CalendarMemoViewMode { month, week, day }

class CalendarMemoPanel extends StatefulWidget {
  const CalendarMemoPanel({super.key, required this.store});

  final SoriStore store;

  @override
  State<CalendarMemoPanel> createState() => _CalendarMemoPanelState();
}

class _CalendarMemoPanelState extends State<CalendarMemoPanel> {
  bool _expanded = false;
  CalendarMemoViewMode _mode = CalendarMemoViewMode.day;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
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

  List<CareScheduleEntry> get _entries =>
      widget.store.careScheduleEntries
          .where((e) => e.status != CareScheduleStatus.cancelled)
          .toList();

  List<CareScheduleEntry> _entriesOn(DateTime day) {
    return _entries.where((e) => e.isSameDay(day)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Set<DateTime> get _daysWithMemos {
    return {
      for (final e in _entries)
        DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day),
    };
  }

  Future<void> _openAddMemoSheet() async {
    final result = await showModalBottomSheet<_MemoDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemoBottomSheet(initialDay: _selectedDay),
    );
    if (result == null || !mounted) return;
    try {
      await widget.store.addManualCareSchedule(
        scheduledAt: result.at,
        customerName: result.customerName.trim().isEmpty
            ? '메모'
            : result.customerName.trim(),
        note: result.note.trim(),
        careLabel: result.careLabel.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메모 저장됨'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: VolumeGlassTheme.cardFillColor(),
        elevation: 0,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
            boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 20,
                        color: SoriTokens.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '캘린더 메모',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_entriesOn(_selectedDay).length}건',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF8E8E93),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SegmentedMode(
                              mode: _mode,
                              onChanged: (m) => setState(() => _mode = m),
                            ),
                            const SizedBox(height: 12),
                            switch (_mode) {
                              CalendarMemoViewMode.month => _MonthView(
                                  selected: _selectedDay,
                                  daysWithMemos: _daysWithMemos,
                                  onSelect: (d) => setState(() {
                                    _selectedDay = d;
                                    _mode = CalendarMemoViewMode.day;
                                  }),
                                ),
                              CalendarMemoViewMode.week => _WeekView(
                                  selected: _selectedDay,
                                  entries: _entries,
                                  onSelect: (d) =>
                                      setState(() => _selectedDay = d),
                                ),
                              CalendarMemoViewMode.day => _DayView(
                                  selected: _selectedDay,
                                  entries: _entriesOn(_selectedDay),
                                  onPrev: () => setState(() {
                                    _selectedDay = _selectedDay
                                        .subtract(const Duration(days: 1));
                                  }),
                                  onNext: () => setState(() {
                                    _selectedDay = _selectedDay
                                        .add(const Duration(days: 1));
                                  }),
                                ),
                            },
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _openAddMemoSheet,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(
                                '메모 추가',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    VolumeGlassTheme.cardRadius * 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedMode extends StatelessWidget {
  const _SegmentedMode({required this.mode, required this.onChanged});

  final CalendarMemoViewMode mode;
  final ValueChanged<CalendarMemoViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CalendarMemoViewMode>(
      segments: const [
        ButtonSegment(
          value: CalendarMemoViewMode.month,
          label: Text('월'),
        ),
        ButtonSegment(
          value: CalendarMemoViewMode.week,
          label: Text('주'),
        ),
        ButtonSegment(
          value: CalendarMemoViewMode.day,
          label: Text('일'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.selected,
    required this.daysWithMemos,
    required this.onSelect,
  });

  final DateTime selected;
  final Set<DateTime> daysWithMemos;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month, 1);
    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final startWeekday = first.weekday; // Mon=1
    final cells = <Widget>[];
    for (var i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(selected.year, selected.month, d);
      final hasMemo = daysWithMemos.contains(day);
      final isSelected = day.year == selected.year &&
          day.month == selected.month &&
          day.day == selected.day;
      cells.add(
        InkWell(
          onTap: () => onSelect(day),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: isSelected
                ? BoxDecoration(
                    color: SoriTokens.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? SoriTokens.primary
                        : const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasMemo
                        ? VolumeGlassTheme.vibrantCareGreen
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(
          '${selected.year}년 ${selected.month}월',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['월', '화', '수', '목', '금', '토', '일']
              .map(
                (w) => Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: cells,
        ),
      ],
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.selected,
    required this.entries,
    required this.onSelect,
  });

  final DateTime selected;
  final List<CareScheduleEntry> entries;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Column(
      children: [
        Row(
          children: days.map((day) {
            final count = entries.where((e) => e.isSameDay(day)).length;
            final isSelected = day.year == selected.year &&
                day.month == selected.month &&
                day.day == selected.day;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onSelect(day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SoriTokens.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF4F6F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1],
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? SoriTokens.primary
                                : const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          count > 0 ? '$count' : '·',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: count > 0
                                ? VolumeGlassTheme.vibrantCareGreen
                                : const Color(0xFFC7C7CC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        ..._dayCards(entries.where((e) => e.isSameDay(selected)).toList()),
      ],
    );
  }

  List<Widget> _dayCards(List<CareScheduleEntry> dayEntries) {
    if (dayEntries.isEmpty) {
      return [
        Text(
          '이 날의 메모가 없습니다',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ];
    }
    return [
      for (final e in dayEntries) ...[
        _MemoCard(entry: e),
        const SizedBox(height: 6),
      ],
    ];
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.selected,
    required this.entries,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime selected;
  final List<CareScheduleEntry> entries;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                '${selected.year}.${selected.month.toString().padLeft(2, '0')}.'
                '${selected.day.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '메모가 없습니다 · + 로 빠르게 남겨 보세요',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF8E8E93),
              ),
            ),
          )
        else
          for (final e in entries) ...[
            _MemoCard(entry: e),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.entry});

  final CareScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = entry.scheduledAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final title = entry.customerName.trim().isEmpty
        ? (entry.careLabel.trim().isEmpty ? '메모' : entry.careLabel.trim())
        : entry.customerName.trim();
    final body = entry.note.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SoriTokens.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.35,
                      color: const Color(0xFF3A3A3C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoDraft {
  const _MemoDraft({
    required this.at,
    required this.note,
    this.customerName = '',
    this.careLabel = '',
  });

  final DateTime at;
  final String note;
  final String customerName;
  final String careLabel;
}

class _MemoBottomSheet extends StatefulWidget {
  const _MemoBottomSheet({required this.initialDay});

  final DateTime initialDay;

  @override
  State<_MemoBottomSheet> createState() => _MemoBottomSheetState();
}

class _MemoBottomSheetState extends State<_MemoBottomSheet> {
  late TimeOfDay _time;
  final _noteCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _time = TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모 내용을 입력해 주세요')),
      );
      return;
    }
    final at = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
      _time.hour,
      _time.minute,
    );
    Navigator.of(context).pop(
      _MemoDraft(
        at: at,
        note: note,
        customerName: _nameCtrl.text,
        careLabel: '메모',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '빠른 메모',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: '고객명 (선택)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '한두 줄 메모',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _submit,
              style: VolumeGlassTheme.carePrimaryButtonStyle(),
              child: Text(
                '저장',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
