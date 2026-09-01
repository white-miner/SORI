import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../operation/widgets/volume_glass_theme.dart';

class CalendarExpandPanel extends StatelessWidget {
  const CalendarExpandPanel({
    super.key,
    required this.visible,
    required this.selectedDay,
    required this.daysWithMemos,
    required this.onDaySelected,
    required this.onAddMemo,
  });

  final bool visible;
  final DateTime selectedDay;
  final Set<DateTime> daysWithMemos;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onAddMemo;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MonthGrid(
                month: DateTime(selectedDay.year, selectedDay.month),
                selectedDay: selectedDay,
                daysWithMemos: daysWithMemos,
                onDaySelected: onDaySelected,
                onAddMemo: onAddMemo,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.daysWithMemos,
    required this.onDaySelected,
    required this.onAddMemo,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> daysWithMemos;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onAddMemo;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final w in ['일', '월', '화', '수', '목', '금', '토'])
        Center(
          child: Text(
            w,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ),
      for (var i = 0; i < startWeekday; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: DateTime(month.year, month.month, d),
          selected: selectedDay.year == month.year &&
              selectedDay.month == month.month &&
              selectedDay.day == d,
          hasMemo: daysWithMemos.contains(
            DateTime(month.year, month.month, d),
          ),
          onTap: () => onDaySelected(DateTime(month.year, month.month, d)),
        ),
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${month.year}년 ${month.month}월',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              onPressed: onAddMemo,
              tooltip: '메모 추가',
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.hasMemo,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasMemo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? VisitGlassTokensCompat.care
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF111111),
              ),
            ),
            if (hasMemo)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Avoid circular import with visit_glass_tokens.
abstract final class VisitGlassTokensCompat {
  static const care = Color(0xFF34C759);
}
