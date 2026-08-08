import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/shop_gallery_slide.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_progress.dart';
import '../widgets/sori_card.dart';
import 'admin_chart_page.dart';
import 'app_shell_page.dart';

/// 원장 홈 — 메인 사진 슬라이더 + 바텀시트 일정 + 월간 캘린더.
class DirectorHomePage extends StatefulWidget {
  const DirectorHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorHomePage> createState() => _DirectorHomePageState();
}

class _DirectorHomePageState extends State<DirectorHomePage> {
  final _pageController = PageController(viewportFraction: 0.92);
  final _sheetController = DraggableScrollableController();
  int _slideIndex = 0;
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
    _pageController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<DateTime> get _weekDays {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<Customer> get _dayCustomers {
    final list = widget.store.customersForDate(_selectedDay);
    if (list.isNotEmpty) return list;
    // 선택일이 비어 있으면 오늘 기준 폴백 없이 빈 리스트 — 전체는 시트에서 안내
    return list;
  }

  List<Customer> get _sheetCustomers {
    final list = _dayCustomers;
    if (list.isNotEmpty) return list;
    return widget.store.customers;
  }

  Future<void> _editSlide(int index) async {
    final slides = widget.store.gallerySlides;
    if (index < 0 || index >= slides.length) return;
    final current = slides[index];
    final title = TextEditingController(text: current.title);
    final subtitle = TextEditingController(text: current.subtitle);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📷 사진 등록 / 변경',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: '사진 제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subtitle,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      widget.store.replaceGallerySlideAt(
        index,
        current.copyWith(
          title: title.text.trim().isEmpty ? current.title : title.text.trim(),
          subtitle: subtitle.text.trim(),
          assetLabel: 'updated_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    }
    title.dispose();
    subtitle.dispose();
  }

  void _openMonthlyCalendar() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MonthlyCalendarDialog(
        initialMonth: _selectedDay,
        visitDaysBuilder: (y, m) => widget.store.visitDaysInMonth(y, m),
        onDaySelected: (day) {
          setState(() => _selectedDay = day);
          Navigator.pop(ctx);
          _sheetController.animateTo(
            0.62,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final slides = store.gallerySlides;
    final charts = store.charts;

    return Stack(
      children: [
        // —— 상단 비주얼 영역 ——
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  '소통하는 리뷰, SORI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.25,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  store.shop.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.34,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _slideIndex = i),
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _HeroSlideCard(
                        slide: slide,
                        onEdit: () => _editSlide(index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final active = i == _slideIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? SoriTokens.primary
                          : SoriTokens.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: SoriCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SoriTokens.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: SoriTokens.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '원장님의 오늘의 맞춤 홈케어 팁',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              store.todayHomecareTip,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (charts.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: charts.length.clamp(0, 6),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final chart = charts[index];
                      final label = switch (chart.visitNumber) {
                        1 => '첫 방문 상담',
                        <= 3 => '수분 집중 관리',
                        <= 6 => '장벽 회복 케어',
                        _ => '유지 케어',
                      };
                      return Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: SoriTokens.cardShadow,
                          ),
                          child: Text(
                            '${chart.visitNumber}회차 · $label',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // —— 바텀시트 일정 ——
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.18,
          minChildSize: 0.14,
          maxChildSize: 0.78,
          snap: true,
          snapSizes: const [0.18, 0.48, 0.78],
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '오늘 케어 일정 ˄',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openMonthlyCalendar,
                        icon: const Icon(Icons.calendar_month_outlined, size: 18),
                        label: const Text('전체 캘린더'),
                        style: TextButton.styleFrom(
                          foregroundColor: SoriTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _weekDays.map((day) {
                      final selected = day.year == _selectedDay.year &&
                          day.month == _selectedDay.month &&
                          day.day == _selectedDay.day;
                      final count = store.customersForDate(day).length;
                      const labels = ['월', '화', '수', '목', '금', '토', '일'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? SoriTokens.primary
                                  : SoriTokens.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  labels[day.weekday - 1],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white70
                                        : SoriTokens.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? Colors.white
                                        : SoriTokens.textPrimary,
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
                                          : SoriTokens.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _dayCustomers.isEmpty
                        ? '선택한 날 일정이 없어 전체 고객을 보여드려요'
                        : '${_selectedDay.month}/${_selectedDay.day} 방문 ${_dayCustomers.length}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._sheetCustomers.map((c) {
                    final chart = store.latestChart(c.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoriCard(
                        onTap: () => openChartWriterForCustomer(
                          context,
                          store: store,
                          customer: c,
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
                                c.name.characters.first,
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
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    c.phone,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SoriTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              chart == null
                                  ? '신규'
                                  : '${chart.visitNumber}회차',
                              style: const TextStyle(
                                color: SoriTokens.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({required this.slide, required this.onEdit});

  final ShopGallerySlide slide;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (slide.kind) {
      GalleryKind.shop => const [Color(0xFF5B4CDB), Color(0xFF8B7CF7)],
      GalleryKind.before => const [Color(0xFF64748B), Color(0xFF94A3B8)],
      GalleryKind.after => const [Color(0xFF0D9488), Color(0xFF5EEAD4)],
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons.spa_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    slide.kind == GalleryKind.shop
                        ? 'SHOP'
                        : slide.kind.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  slide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slide.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SoriTokens.primary,
                    ),
                    child: const Text('📷 사진 등록/변경'),
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
    final leading = first.weekday - 1; // Mon start
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
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
                            fontWeight: FontWeight.w600,
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
                        borderRadius: BorderRadius.circular(12),
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
                                ? SoriTokens.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
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
                                  color: SoriTokens.textPrimary,
                                ),
                              ),
                              if (hasVisit)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: SoriTokens.primary,
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
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 고객 탭 — 검색 가능한 전체 리스트.
class DirectorCustomersTab extends StatefulWidget {
  const DirectorCustomersTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomersTab> createState() => _DirectorCustomersTabState();
}

class _DirectorCustomersTabState extends State<DirectorCustomersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.store.searchCustomers(_query);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '이름 · 전화번호 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = list[index];
                return SoriCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminChartPage(
                          store: widget.store,
                          customerId: c.id,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: SoriTokens.primarySoft,
                        child: Text(
                          c.name.characters.first,
                          style: const TextStyle(
                            color: SoriTokens.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.name}  ·  ${c.phone}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            MembershipProgressView(
                              customer: c,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: SoriTokens.textSecondary,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
