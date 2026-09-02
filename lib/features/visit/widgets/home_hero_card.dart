import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../operation/widgets/care_timer_fullscreen_page.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../home_visual_tokens.dart';
import '../home_dashboard_controller.dart';
import 'calendar_expand_panel.dart';
import 'countdown_flip_zone.dart';
import 'memo_stack_display.dart';
import 'memo_time_slot_editor.dart';

/// PRD v7.0 — home hero card (date, calendar, flip clock, scheduler strip).
class HomeHeroCard extends StatefulWidget {
  const HomeHeroCard({
    super.key,
    required this.store,
    required this.controller,
    this.careRunning = false,
    this.schedulerStrip,
  });

  final SoriStore store;
  final HomeDashboardController controller;
  final bool careRunning;

  /// v7.0 My Feed에서는 스케줄러 스트립이 메모 스택 자리를 대체한다.
  /// 미지정 시 v5.4 메모 스택으로 폴백한다.
  final Widget? schedulerStrip;

  @override
  State<HomeHeroCard> createState() => _HomeHeroCardState();
}

class _HomeHeroCardState extends State<HomeHeroCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    widget.store.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    widget.store.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  String _koreanDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일';

  Set<DateTime> get _daysWithMemos {
    return {
      for (final e in widget.store.careScheduleEntries)
        if (e.status.name != 'cancelled')
          DateTime(
            e.scheduledAt.year,
            e.scheduledAt.month,
            e.scheduledAt.day,
          ),
    };
  }

  int _wallClockSeconds() {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  Future<void> _openMemoEditor([DateTime? day]) async {
    final target = day ?? widget.controller.selectedDay;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemoTimeSlotEditor(
        store: widget.store,
        day: target,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isCount = ctrl.heroMode == HomeHeroMode.countSetup ||
        ctrl.heroMode == HomeHeroMode.countRunning ||
        ctrl.heroMode == HomeHeroMode.countComplete;
    final calendarOpen = ctrl.heroMode == HomeHeroMode.calendarExpanded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeVisualTokens.heroCardPaddingH,
        8,
        HomeVisualTokens.heroCardPaddingH,
        12,
      ),
      child: Material(
        color: HomeVisualTokens.heroCardFill,
        elevation: 0,
        borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
            boxShadow: const [HomeVisualTokens.heroCardShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HomeVisualTokens.heroCardPaddingH,
              HomeVisualTokens.heroCardPaddingTop,
              HomeVisualTokens.heroCardPaddingH,
              HomeVisualTokens.heroCardPaddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: ctrl.toggleCalendar,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: HomeVisualTokens.dateRowMinHeight,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!calendarOpen) ...[
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: HomeVisualTokens.dateIconSize,
                            color: HomeVisualTokens.dateIconColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _koreanDate(ctrl.selectedDay),
                          style: GoogleFonts.nunito(
                            fontSize: HomeVisualTokens.dateTextSize,
                            fontWeight: FontWeight.w700,
                            color: HomeVisualTokens.dateTextColor,
                          ),
                        ),
                        if (calendarOpen) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: HomeVisualTokens.dateIconColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                CalendarExpandPanel(
                  visible: calendarOpen,
                  selectedDay: ctrl.selectedDay,
                  daysWithMemos: _daysWithMemos,
                  onDaySelected: (d) {
                    ctrl.selectDay(d);
                    ctrl.collapseCalendar();
                    _openMemoEditor(d);
                  },
                  onAddMemo: () {
                    ctrl.collapseCalendar();
                    _openMemoEditor();
                  },
                ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final clock = isCount
                        ? CountdownFlipZone(controller: ctrl)
                        : FlipClockDisplay(
                            totalSeconds: _wallClockSeconds(),
                            hero: true,
                            homeHero: true,
                            showSeconds: false,
                            showCornerSeconds: true,
                            heroTag: CareTimerFullscreenPage.flipHeroTag,
                            style: FlipClockStyle.darkGlass,
                          );
                    return ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: HomeVisualTokens.flipHeroZoneMinHeight,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: clock,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                widget.schedulerStrip ??
                    MemoStackDisplay(
                      entries: widget.store.careScheduleEntries,
                      expanded: ctrl.memoStackExpanded,
                      onToggleExpand: ctrl.toggleMemoStack,
                    ),
                if (widget.careRunning) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 16,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '케어 타이머 진행 중',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
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
