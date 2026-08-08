import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import 'admin_chart_page.dart';
import 'app_shell_page.dart';

/// 원장 홈 — 주간 캘린더 + 고객 Quick Selector.
class DirectorHomePage extends StatefulWidget {
  const DirectorHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorHomePage> createState() => _DirectorHomePageState();
}

class _DirectorHomePageState extends State<DirectorHomePage> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
  }

  List<DateTime> get _weekDays {
    final weekday = _selected.weekday; // Mon=1
    final monday = _selected.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<Customer> _customersForDay(DateTime day) {
    return widget.store.customers.where((c) {
      final d = c.lastTreatmentDate;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  List<Customer> get _todayQuick {
    final list = _customersForDay(_selected);
    if (list.isNotEmpty) return list;
    return widget.store.customers.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final dayCustomers = _customersForDay(_selected);
    final showList = dayCustomers.isNotEmpty ? dayCustomers : store.customers;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SoriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '주간 일정',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selected.month}월 ${_selected.day}일',
                          style: const TextStyle(
                            color: SoriTokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: _weekDays.map((day) {
                        final selected = day.year == _selected.year &&
                            day.month == _selected.month &&
                            day.day == _selected.day;
                        final count = _customersForDay(day).length;
                        const labels = ['월', '화', '수', '목', '금', '토', '일'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = day),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? SoriTokens.primary
                                    : SoriTokens.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    labels[day.weekday - 1],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? Colors.white70
                                          : SoriTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? Colors.white
                                          : SoriTokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: count > 0
                                          ? (selected
                                              ? Colors.white
                                              : SoriTokens.primary)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘 방문 고객',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _todayQuick.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final c = _todayQuick[index];
                        return GestureDetector(
                          onTap: () => openChartWriterForCustomer(
                            context,
                            store: store,
                            customer: c,
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: SoriTokens.primarySoft,
                                child: Text(
                                  c.name.characters.first,
                                  style: const TextStyle(
                                    color: SoriTokens.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                dayCustomers.isEmpty
                    ? '전체 고객 ${showList.length}명'
                    : '이 날 방문 ${dayCustomers.length}명',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            sliver: SliverList.separated(
              itemCount: showList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = showList[index];
                final chart = store.latestChart(c.id);
                return SoriCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminChartPage(
                          store: store,
                          customerId: c.id,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
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
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
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
                          const SizedBox(height: 4),
                          Text(
                            chart?.careName ?? c.treatmentType,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ],
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
                  onTap: () => openChartWriterForCustomer(
                    context,
                    store: widget.store,
                    customer: c,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${c.name}  ·  ${c.phone}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: SoriTokens.textSecondary),
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
