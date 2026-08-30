import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../crm_kernel/crm_store.dart';
import '../../crm_kernel/models/care_schedule_entry.dart';
import '../../crm_kernel/theme/crm_calm_glass_tokens.dart';
import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../routing/sori_router.dart';
import '../../views/admin_chart_writer_page.dart';
import '../../widgets/crm/crm_calm_glass_widgets.dart';
import 'add_manual_schedule_sheet.dart';

/// Today Care Board — CDG Apple Health / Notion Calendar 감성.
class TodayCareBoardPage extends StatefulWidget {
  const TodayCareBoardPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<TodayCareBoardPage> createState() => _TodayCareBoardPageState();
}

class _TodayCareBoardPageState extends State<TodayCareBoardPage> {
  late DateTime _selectedDay;
  bool _loading = true;

  CrmStore get crm => widget.store.crm;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    crm.addListener(_onCrm);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    crm.removeListener(_onCrm);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    await crm.ensureScheduleLoaded(force: force);
    if (mounted) setState(() => _loading = false);
  }

  void _onCrm() {
    if (mounted) setState(() {});
  }

  String get _greetingName {
    final owner = widget.store.shop.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final session = widget.store.session?.name.trim();
    if (session != null && session.isNotEmpty) return session;
    return '원장';
  }

  List<DateTime> get _weekDays {
    final monday =
        _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Future<void> _openAddSchedule() async {
    final ok = await showAddManualScheduleSheet(
      context,
      store: widget.store,
      initialDay: _selectedDay,
    );
    if (ok == true) await _load(force: true);
  }

  void _openChart(Customer? customer) {
    if (customer == null) return;
    openChartWriterForCustomer(context, store: widget.store, customer: customer);
  }

  Future<void> _shareLeadLink() async {
    final shopId = widget.store.shop.id.trim();
    if (shopId.isEmpty) return;
    final path = AppPaths.careScheduleLead(shopId);
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('희망 일정 링크가 복사되었습니다: $path'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = crm.snapshotForDay(_selectedDay);
    final hints = crm.customersNeedingChartHint(_selectedDay);
    final isToday = _isSameDay(_selectedDay, DateTime.now());

    return ColoredBox(
      color: SoriTokens.background,
      child: RefreshIndicator(
        color: CrmCalmGlassTokens.care,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  isToday ? 'Good morning, $_greetingName 원장님' : '케어 보드',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildDayHeader(snapshot)),
            SliverToBoxAdapter(child: _buildTimeRail()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: CrmCalmGlassTokens.care),
                ),
              )
            else if (snapshot.orbitItems.isEmpty && hints.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = snapshot.orbitItems[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrbitCard(
                          item: item,
                          onTap: () {
                            final cid = item.customerId;
                            if (cid != null) {
                              _openChart(crm.findCustomer(cid));
                            }
                          },
                          onComplete: item.hasChartToday
                              ? null
                              : () => crm.markScheduleCompleted(item.entry.id),
                        ),
                      );
                    },
                    childCount: snapshot.orbitItems.length,
                  ),
                ),
              ),
              if (hints.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      '미작성 차트',
                      style: CrmCalmGlassTokens.captionCalm.copyWith(
                        color: CrmCalmGlassTokens.alert,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = hints[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CrmCalmGlassCard(
                          tint: CrmCalmGlassTokens.alert,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: () => _openChart(c),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                color: CrmCalmGlassTokens.alert,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${c.name.trim()} · 오늘 차트 미작성',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: SoriTokens.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: SoriTokens.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: hints.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(TodayBoardSnapshot snapshot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: DecoratedBox(
        decoration: CrmCalmGlassTokens.heroDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(18),
            child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘 케어 ${snapshot.scheduledCount}명',
                      style: CrmCalmGlassTokens.bodyCalm.copyWith(
                        color: SoriTokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.unwrittenCount > 0
                          ? '미작성 ${snapshot.unwrittenCount} · 리드 ${snapshot.leadCount}'
                          : '모든 케어 기록 완료',
                      style: CrmCalmGlassTokens.captionCalm.copyWith(
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '희망 일정 링크',
                onPressed: _shareLeadLink,
                icon: const Icon(Icons.link_rounded),
                color: CrmCalmGlassTokens.lead,
              ),
              CrmProgressRing(ratio: snapshot.progressRatio),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _openAddSchedule,
                style: IconButton.styleFrom(
                  backgroundColor:
                      CrmCalmGlassTokens.care.withValues(alpha: 0.2),
                  foregroundColor: CrmCalmGlassTokens.care,
                ),
                icon: const Icon(Icons.add_rounded),
                tooltip: '일정 추가',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRail() {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _weekDays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _weekDays[i];
          final selected = _isSameDay(day, _selectedDay);
          final count = crm.snapshotForDay(day).scheduledCount;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: AnimatedContainer(
              duration: CrmCalmGlassTokens.calmMotion,
              curve: CrmCalmGlassTokens.calmCurve,
              width: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? CrmCalmGlassTokens.care.withValues(alpha: 0.35)
                    : CrmCalmGlassTokens.care.withValues(alpha: 0.06),
                border: Border.all(
                  color: selected
                      ? CrmCalmGlassTokens.care.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? SoriTokens.textPrimary
                          : SoriTokens.textTertiary,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: selected
                          ? SoriTokens.textPrimary
                          : SoriTokens.textSecondary,
                    ),
                  ),
                  if (count > 0)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: CrmCalmGlassTokens.care,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 48,
            color: CrmCalmGlassTokens.care.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedDay.month}/${_selectedDay.day} 예정된 케어가 없어요',
            textAlign: TextAlign.center,
            style: CrmCalmGlassTokens.bodyCalm.copyWith(
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _openAddSchedule,
            child: const Text('수동 일정 추가'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _OrbitCard extends StatelessWidget {
  const _OrbitCard({
    required this.item,
    this.onTap,
    this.onComplete,
  });

  final TodayOrbitItem item;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final tint = item.isLead ? CrmCalmGlassTokens.lead : CrmCalmGlassTokens.care;
    return CrmCalmGlassCard(
      tint: tint,
      onTap: onTap,
      child: Row(
        children: [
          _OrbitAvatar(
            name: item.displayName,
            done: item.hasChartToday,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: SoriTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (item.isLead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CrmCalmGlassTokens.lead.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '리드',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.timeLabel} · ${item.careLabel}',
                  style: CrmCalmGlassTokens.captionCalm.copyWith(
                    color: SoriTokens.textSecondary,
                  ),
                ),
                if (item.membershipRemain > 0)
                  Text(
                    '잔여 ${item.membershipRemain}회',
                    style: CrmCalmGlassTokens.captionCalm.copyWith(
                      color: CrmCalmGlassTokens.revenue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (item.hasChartToday)
            const Icon(Icons.check_circle_rounded, color: CrmCalmGlassTokens.revenue)
          else if (onComplete != null)
            IconButton(
              icon: const Icon(Icons.check_rounded),
              color: CrmCalmGlassTokens.care,
              onPressed: onComplete,
              tooltip: '완료',
            ),
        ],
      ),
    );
  }
}

class _OrbitAvatar extends StatelessWidget {
  const _OrbitAvatar({required this.name, required this.done});

  final String name;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.characters.first : '?';
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: done
                  ? CrmCalmGlassTokens.revenue
                  : CrmCalmGlassTokens.care.withValues(alpha: 0.6),
              width: 2.5,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: CrmCalmGlassTokens.careSoft,
            child: Text(
              initial,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
