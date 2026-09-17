import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_date_picker.dart';
import '../theme/sori_tokens.dart';
import '../features/operation/widgets/volume_glass_theme.dart';
import '../widgets/sori_card.dart';
import '../views/admin_chart_writer_page.dart';

/// 날짜별 케어 기록 — 차트 created_at 기준 이력 조회 (예약 아님).
class TodayCareSchedulePanel extends StatefulWidget {
  const TodayCareSchedulePanel({
    super.key,
    required this.store,
    this.slim = false,
  });

  final SoriStore store;

  /// CRM Sliver 헤더용 — 차트 카드 수·여백을 줄여 고정 높이에 맞춤.
  final bool slim;

  @override
  State<TodayCareSchedulePanel> createState() => _TodayCareSchedulePanelState();
}

class _TodayCareSchedulePanelState extends State<TodayCareSchedulePanel> {
  late DateTime _selectedDay;
  bool _expanded = true;

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

  List<DateTime> get _weekDays {
    final monday =
        _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<CustomerChart> get _dayCharts =>
      widget.store.chartsCreatedOnDate(_selectedDay);

  void _openMonthlyCalendar() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: SoriTokens.primary,
            onPrimary: Colors.white,
            surface: SoriTokens.surface,
            onSurface: SoriTokens.textPrimary,
          ),
        ),
        child: _MonthlyCalendarDialog(
          initialMonth: _selectedDay,
          visitDaysBuilder: (y, m) =>
              widget.store.chartCreatedDaysInMonth(y, m),
          onDaySelected: (day) {
            setState(() {
              _selectedDay = day;
              _expanded = true;
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final dayCharts = _dayCharts;
    final chartLimit = widget.slim ? 3 : 12;
    final margin = widget.slim
        ? const EdgeInsets.fromLTRB(16, 4, 16, 4)
        : const EdgeInsets.fromLTRB(16, 8, 16, 8);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: VolumeGlassTheme.cardFillColor(),
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '날짜별 케어 기록',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openMonthlyCalendar,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('전체 캘린더'),
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: SoriTokens.primary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: _weekDays.map((day) {
                final selected = day.year == _selectedDay.year &&
                    day.month == _selectedDay.month &&
                    day.day == _selectedDay.day;
                final count = store.chartsCreatedOnDate(day).length;
                const labels = ['월', '화', '수', '목', '금', '토', '일'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedDay = day;
                      _expanded = true;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? SoriTokens.primary
                            : SoriTokens.chipIdleBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            labels[day.weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : SoriTokens.tabUnselected,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : SoriTokens.textCharcoal,
                            ),
                          ),
                          if (count > 0)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Colors.white
                                    : SoriTokens.systemRed,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                dayCharts.isEmpty
                    ? '${_selectedDay.month}/${_selectedDay.day}에 작성된 차트가 없어요'
                    : '${_selectedDay.month}/${_selectedDay.day} 작성 차트 ${dayCharts.length}건',
                style: const TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
            if (dayCharts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: Text(
                  '과거·오늘 작성된 케어 차트가 이 날짜에 모입니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ...dayCharts.take(chartLimit).map((chart) {
                final customer = store.findCustomer(chart.customerId);
                final care = chart.careName.trim().isNotEmpty
                    ? chart.careName.trim()
                    : (chart.treatmentSummary.trim().isNotEmpty
                        ? chart.treatmentSummary.trim()
                        : '케어 차트');
                final time = chart.createdAt;
                final timeLabel = time == null
                    ? ''
                    : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: SoriCard(
                    onTap: customer == null
                        ? null
                        : () => openChartWriterForCustomer(
                              context,
                              store: store,
                              customer: customer,
                            ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: SoriTokens.primarySoft,
                          child: Text(
                            (customer?.name.trim().isNotEmpty == true)
                                ? customer!.name.characters.first
                                : 'C',
                            style: const TextStyle(
                              color: SoriTokens.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer?.name ?? '고객',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                care,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SoriTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${chart.visitNumber}회차',
                              style: const TextStyle(
                                color: SoriTokens.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            if (timeLabel.isNotEmpty)
                              Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _MonthlyCalendarDialog extends StatefulWidget {
  const _MonthlyCalendarDialog({
    required this.initialMonth,
    required this.visitDaysBuilder,
    required this.onDaySelected,
  });

  final DateTime initialMonth;
  final Set<int> Function(int year, int month) visitDaysBuilder;
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<_MonthlyCalendarDialog> createState() => _MonthlyCalendarDialogState();
}

class _MonthlyCalendarDialogState extends State<_MonthlyCalendarDialog> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final visitDays = widget.visitDaysBuilder(_month.year, _month.month);
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SoriGlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
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
              children: const ['월', '화', '수', '목', '금', '토', '일']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(rows, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: List.generate(7, (col) {
                    final cell = row * 7 + col;
                    final dayNum = cell - leading + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }
                    final hasVisit = visitDays.contains(dayNum);
                    final isToday = DateTime.now().year == _month.year &&
                        DateTime.now().month == _month.month &&
                        DateTime.now().day == dayNum;
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          widget.onDaySelected(
                            DateTime(_month.year, _month.month, dayNum),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? SoriTokens.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isToday
                                      ? Colors.white
                                      : SoriTokens.textPrimary,
                                ),
                              ),
                              if (hasVisit)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? Colors.white
                                        : SoriTokens.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '닫기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
