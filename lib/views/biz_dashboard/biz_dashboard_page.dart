import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routing/sori_router.dart';
import '../../services/biz_manual_revenue_store.dart';
import '../../services/biz_profile_store.dart';
import '../../services/shop_market_service.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'biz_math.dart';

const _kCategories = <String>[
  '에스테틱',
  '네일',
  '바버',
  '미용실',
  '타투',
  '기타 1인샵',
];

/// 마이 「경영」탭 — 대시보드 입구 + 매출 요약 (PRD v7.6).
class DirectorBizTabBody extends StatefulWidget {
  const DirectorBizTabBody({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  @override
  State<DirectorBizTabBody> createState() => _DirectorBizTabBodyState();
}

class _DirectorBizTabBodyState extends State<DirectorBizTabBody> {
  int? _month;
  int? _year;
  ShopBizProfile _profile = const ShopBizProfile();
  bool _loading = true;

  String get _shopId => widget.store.shop.id;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final now = DateTime.now();
    final shopId = _shopId;
    if (shopId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final m = await BizManualRevenueStore.loadMonth(
      shopId: shopId,
      year: now.year,
      month: now.month,
    );
    final y = await BizManualRevenueStore.loadYear(
      shopId: shopId,
      year: now.year,
    );
    final p = await BizProfileStore.load(shopId);
    if (!mounted) return;
    setState(() {
      _month = m;
      _year = y;
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _openDashboard() async {
    await context.push(AppPaths.appBizDashboard);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '경영 대시보드는 샵 주인만 볼 수 있어요',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final snap = BizMath.compute(
      profile: _profile,
      monthRevenueKrw: _month,
      now: now,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text(
          '경영',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _profile.isComplete
              ? '내 숫자가 준비됐어요. 월·년 매출만 넣으면 수익이 계산됩니다.'
              : '주소와 평소 쓰는 숫자만 적으면, 시간당 수익·진짜 이익을 쉽게 보여 드려요.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          if (snap != null) ...[
            _SummaryCard(
              label: '시간당 수익',
              value: BizManualRevenueStore.formatWon(snap.hourlyYieldKrw),
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              label: '사업 이익 (인건비 계상 후)',
              value: BizManualRevenueStore.formatWon(snap.businessProfitKrw),
            ),
            const SizedBox(height: 10),
          ],
          _SummaryCard(
            label: '${now.year}년 ${now.month}월 매출',
            value: _month == null
                ? '미입력'
                : BizManualRevenueStore.formatWon(_month!),
          ),
          const SizedBox(height: 10),
          _SummaryCard(
            label: '${now.year}년 매출',
            value: _year == null
                ? '미입력'
                : BizManualRevenueStore.formatWon(_year!),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _openDashboard,
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.insights_rounded, size: 20),
          label: Text(
            _profile.isComplete ? '내 경영 숫자 보기' : '3분만에 시작하기',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `/app/biz-dashboard` — Phase 1: 온보딩 + ZONE 1·2.
class BizDashboardPage extends StatefulWidget {
  const BizDashboardPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<BizDashboardPage> createState() => _BizDashboardPageState();
}

class _BizDashboardPageState extends State<BizDashboardPage> {
  late final TextEditingController _monthCtrl;
  late final TextEditingController _yearCtrl;
  ShopBizProfile _profile = const ShopBizProfile();
  ShopMarketInsight? _market;
  bool _marketLoading = false;
  bool _loading = true;
  bool _saving = false;

  String get _shopId => widget.store.shop.id;

  @override
  void initState() {
    super.initState();
    _monthCtrl = TextEditingController();
    _yearCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _load();
    if (!mounted) return;
    if (!_profile.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openOnboarding();
      });
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final shopId = _shopId;
    if (shopId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final m = await BizManualRevenueStore.loadMonth(
      shopId: shopId,
      year: now.year,
      month: now.month,
    );
    final y = await BizManualRevenueStore.loadYear(
      shopId: shopId,
      year: now.year,
    );
    final p = await BizProfileStore.load(shopId);
    if (!mounted) return;
    _monthCtrl.text = m == null ? '' : m.toString();
    _yearCtrl.text = y == null ? '' : y.toString();
    setState(() {
      _profile = p;
      _loading = false;
    });
    if (p.isComplete) {
      unawaited(_loadMarket());
    }
  }

  Future<void> _loadMarket() async {
    if (!mounted) return;
    setState(() => _marketLoading = true);
    final insight = await ShopMarketService.instance.fetch(
      shop: widget.store.shop,
      category: _profile.category,
      admCd: _profile.admCd.trim().isEmpty ? null : _profile.admCd.trim(),
    );
    if (!mounted) return;
    setState(() {
      _market = insight;
      _marketLoading = false;
    });
  }

  int? _parseWon(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  Future<void> _saveRevenue() async {
    final shopId = _shopId;
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('샵 정보가 없습니다')),
      );
      return;
    }
    final now = DateTime.now();
    final month = _parseWon(_monthCtrl.text);
    final year = _parseWon(_yearCtrl.text);
    if (month == null && year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('월 또는 년 매출을 입력해 주세요')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (month != null) {
        await BizManualRevenueStore.saveMonth(
          shopId: shopId,
          year: now.year,
          month: now.month,
          amountKrw: month,
        );
      }
      if (year != null) {
        await BizManualRevenueStore.saveYear(
          shopId: shopId,
          year: now.year,
          amountKrw: year,
        );
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('매출을 저장했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openOnboarding() async {
    final result = await showModalBottomSheet<ShopBizProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _BizOnboardingSheet(initial: _profile),
    );
    if (result == null || !mounted) return;
    await BizProfileStore.save(_shopId, result);
    if (!mounted) return;
    setState(() => _profile = result);
    unawaited(_loadMarket());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthRev = _parseWon(_monthCtrl.text);
    final snap = BizMath.compute(
      profile: _profile,
      monthRevenueKrw: monthRev,
      now: now,
    );

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('경영 대시보드'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _openOnboarding,
            child: Text(
              _profile.isComplete ? '내 샵 정보 바꾸기' : '내 샵 정보 입력',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                if (!_profile.isComplete)
                  _HintBanner(
                    text:
                        '주소와 고정비·목표 월급만 적으면 바로 계산됩니다. 상권 용어는 몰라도 괜찮아요.',
                    actionLabel: '시작',
                    onAction: _openOnboarding,
                  ),
                if (_profile.isComplete && monthRev == null)
                  _HintBanner(
                    text: '이번 달 매출을 넣으면 시간당 수익·진짜 이익이 채워집니다.',
                  ),
                const Text(
                  '내 매출 (손으로 적기)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '이번 달·올해 매출만 적어 주세요. (나중에 차트에서 자동으로 합칠 수 있어요)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _monthCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${now.year}년 ${now.month}월 매출 (원)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '${now.year}년 매출 (원)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _saveRevenue,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _saving ? '저장 중…' : '매출 저장',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 28),
                if (snap != null) ...[
                  _Zone1Section(snap: snap),
                  const SizedBox(height: 20),
                  _Zone2Section(snap: snap),
                  const SizedBox(height: 20),
                ],
                _Zone3Section(
                  market: _market,
                  loading: _marketLoading,
                  hasAdmCd: _profile.admCd.trim().isNotEmpty,
                  onRefresh: _loadMarket,
                  onEditProfile: _openOnboarding,
                ),
                const SizedBox(height: 20),
                const Text(
                  '이후 존 (준비 중)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const _ZonePlaceholder(
                  title: 'ZONE 4 · 고객 자산',
                  subtitle: '재방문 · LTV — Phase 4',
                ),
                const _ZonePlaceholder(
                  title: 'ZONE 5 · 캐파 · 시간',
                  subtitle: '예약 히트맵 — Phase 2',
                ),
              ],
            ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _Zone1Section extends StatelessWidget {
  const _Zone1Section({required this.snap});

  final BizZone12Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final mult = snap.minWageMultiple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ZONE 1 · 경영자 헤드라인',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _KpiCard(
          label: '시간당 수익 ★',
          value: BizManualRevenueStore.formatWon(snap.hourlyYieldKrw),
          sub: mult == null
              ? '월 ${snap.monthlyHours.toStringAsFixed(0)}시간 투입 기준'
              : '최저임금(참고) 대비 ${mult.toStringAsFixed(1)}배 · '
                  '월 ${snap.monthlyHours.toStringAsFixed(0)}시간',
        ),
        const SizedBox(height: 10),
        _KpiCard(
          label: '진짜 영업이익',
          value: BizManualRevenueStore.formatWon(snap.businessProfitKrw),
          sub: '경영 단계 · ${BizMath.stageLabel(snap.stage)}',
          valueColor: snap.businessProfitKrw < 0
              ? SoriTokens.systemRed
              : SoriTokens.textPrimary,
        ),
        const SizedBox(height: 10),
        _OwnerPayBar(snap: snap),
        const SizedBox(height: 10),
        const _ZonePlaceholder(
          title: '상권 백분위 · Alpha',
          subtitle: '공공데이터 연동 후 (Phase 3) · 지금은 숨기지 않고 안내만',
        ),
        const SizedBox(height: 8),
        const Text(
          '숫자를 올리는 방법은 더 오래 일하는 게 아니라, 단가·가동률·비용 중 하나를 바꾸는 것입니다.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _OwnerPayBar extends StatelessWidget {
  const _OwnerPayBar({required this.snap});

  final BizZone12Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final owner = snap.ownerPayKrw.toDouble().abs();
    final profit = snap.businessProfitKrw.toDouble();
    final loss = profit < 0 ? -profit : 0.0;
    final pos = profit > 0 ? profit : 0.0;
    final total = owner + pos + loss;
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '인건비 vs 사업 이익',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (owner > 0)
                    Expanded(
                      flex: (owner / total * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFF7C3AED)),
                    ),
                  if (pos > 0)
                    Expanded(
                      flex: (pos / total * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFF059669)),
                    ),
                  if (loss > 0)
                    Expanded(
                      flex: (loss / total * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFFDC2626)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '보라 = 대표 인건비(비용) · 초록 = 사업 이익 · 빨강 = 부족분',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _Zone2Section extends StatelessWidget {
  const _Zone2Section({required this.snap});

  final BizZone12Snapshot snap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ZONE 2 · 수익 구조',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final step in snap.waterfallSteps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: step.isOwnerPay
                                ? const Color(0xFF7C3AED)
                                : SoriTokens.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        BizManualRevenueStore.formatWon(step.amountKrw.abs()) +
                            (step.amountKrw < 0 ? ' −' : ''),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: step.isOwnerPay
                              ? const Color(0xFF7C3AED)
                              : (step.amountKrw < 0 && step.label != '사업 이익'
                                  ? const Color(0xFF6B7280)
                                  : SoriTokens.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _KpiCard(
          label: 'BEP 매출 (인건비 포함)',
          value: BizManualRevenueStore.formatWon(snap.bepRevenueKrw),
          sub: snap.bepDayOfMonth == null
              ? '이번 달 매출로는 손익분기에 도달하지 못함 · 안전마진 ${snap.safetyMarginPct.toStringAsFixed(1)}%'
              : '${snap.bepDayOfMonth}일부터 버는 돈 · 안전마진 ${snap.safetyMarginPct.toStringAsFixed(1)}%',
        ),
        if (snap.bepDayOfMonth != null) ...[
          const SizedBox(height: 10),
          _BepCalendarStrip(
            daysInMonth: snap.daysInMonth,
            bepDay: snap.bepDayOfMonth!,
          ),
        ],
      ],
    );
  }
}

class _BepCalendarStrip extends StatelessWidget {
  const _BepCalendarStrip({
    required this.daysInMonth,
    required this.bepDay,
  });

  final int daysInMonth;
  final int bepDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BEP 도달 달력',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var d = 1; d <= daysInMonth; d++)
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: d < bepDay
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: d < bepDay
                          ? const Color(0xFF991B1B)
                          : const Color(0xFF065F46),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '붉은 구간 = 아직 비용 회수 중 · 초록 = 이 날짜부터 이익',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor ?? SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _Zone3Section extends StatelessWidget {
  const _Zone3Section({
    required this.market,
    required this.loading,
    required this.hasAdmCd,
    required this.onRefresh,
    required this.onEditProfile,
  });

  final ShopMarketInsight? market;
  final bool loading;
  final bool hasAdmCd;
  final VoidCallback onRefresh;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ZONE 3 · 우리 동네 살펴보기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: loading ? null : onRefresh,
              child: const Text('다시 보기'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '근처 비슷한 샵이 몇 곳인지, 동네에 사람이 얼마나 사는지 참고용으로 보여 줍니다.\n'
          '(공식 통계 · 추정치 · 내 샵 실매출이 아닙니다)',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (market == null)
          _HintBanner(
            text: '샵 주소를 연결하면 근처 샵·동네 인구를 불러옵니다.',
            actionLabel: '불러오기',
            onAction: onRefresh,
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '내 근처 비슷한 샵',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '추정',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!market!.storesOk)
                  Text(
                    '근처 샵 정보를 잠시 못 가져왔어요'
                    '${market!.storesError == null ? '' : ' · ${market!.storesError}'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  )
                else ...[
                  Text(
                    '걸어서 ${market!.radiusM}m 안 · 등록 점포 ${market!.totalInRadius}곳',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '나와 비슷한 업종 약 ${market!.sameCategoryCount}곳',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (market!.sampleNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '예: ${market!.sampleNames.join(' · ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                const Text(
                  '출처: 소상공인시장진흥공단 상가(상권)정보',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '우리 동네에 사는 사람',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (!hasAdmCd)
                  _HintBanner(
                    text:
                        '주소만 적고 「우리 동네 연결하기」를 누르면 인구를 볼 수 있어요. 코드는 몰라도 됩니다.',
                    actionLabel: '주소로 연결',
                    onAction: onEditProfile,
                  )
                else if (!market!.populationOk)
                  Text(
                    '인구를 불러오지 못했어요'
                    '${market!.populationError == null ? '' : ' · ${market!.populationError}'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  )
                else ...[
                  Text(
                    [
                      if ((market!.dongName ?? '').isNotEmpty)
                        '${market!.dongName} 기준',
                      if (market!.statsYm.isNotEmpty)
                        '통계 ${market!.statsYm}',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '총 ${market!.popTotal}명',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '남 ${market!.popMale} · 여 ${market!.popFemale}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (market!.ages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final a in market!.ages)
                      if (a.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 48,
                                child: Text(
                                  a.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${a.total}명 (남 ${a.male} / 여 ${a.female})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                  if (market!.storesPer1kPop != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '주민 1,000명당 비슷한 샵 ≈ ${market!.storesPer1kPop}곳',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                const Text(
                  '출처: 행정안전부 주민등록 인구 통계',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _ZonePlaceholder(
            title: '우리 동네 매출 비교',
            subtitle: '곧 연결 예정 · 지금은 근처 샵·동네 인구만 볼 수 있어요',
          ),
        ],
      ],
    );
  }
}

class _ZonePlaceholder extends StatelessWidget {
  const _ZonePlaceholder({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

/// 온보딩 — 초보 원장용 쉬운 말 + 주소로 동네 자동 연결.
class _BizOnboardingSheet extends StatefulWidget {
  const _BizOnboardingSheet({required this.initial});

  final ShopBizProfile initial;

  @override
  State<_BizOnboardingSheet> createState() => _BizOnboardingSheetState();
}

class _BizOnboardingSheetState extends State<_BizOnboardingSheet> {
  late String _category;
  late final TextEditingController _address;
  late final TextEditingController _admCd;
  late final TextEditingController _fixed;
  late final TextEditingController _material;
  late final TextEditingController _ownerPay;
  late final TextEditingController _days;
  late final TextEditingController _hours;

  String _dongLabel = '';
  bool _linking = false;
  bool _showAdvancedCode = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _category = i.category.trim().isEmpty ? _kCategories.first : i.category;
    if (!_kCategories.contains(_category)) {
      _category = _kCategories.last;
    }
    _address = TextEditingController(text: i.address);
    _admCd = TextEditingController(text: i.admCd);
    _dongLabel = i.admCd.trim().isEmpty ? '' : '동네 코드가 저장되어 있어요';
    _fixed = TextEditingController(
      text: i.monthlyFixedCostKrw > 0 ? '${i.monthlyFixedCostKrw}' : '',
    );
    _material = TextEditingController(text: '${i.materialRatePct}');
    _ownerPay = TextEditingController(
      text: i.targetOwnerPayKrw > 0 ? '${i.targetOwnerPayKrw}' : '',
    );
    _days = TextEditingController(text: '${i.openDaysPerWeek}');
    _hours = TextEditingController(text: '${i.hoursPerDay}');
  }

  @override
  void dispose() {
    _address.dispose();
    _admCd.dispose();
    _fixed.dispose();
    _material.dispose();
    _ownerPay.dispose();
    _days.dispose();
    _hours.dispose();
    super.dispose();
  }

  int? _int(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));

  double? _double(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim());

  Future<void> _linkNeighborhood() async {
    final addr = _address.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 샵 주소를 적어 주세요')),
      );
      return;
    }
    setState(() => _linking = true);
    try {
      final n =
          await ShopMarketService.instance.resolveNeighborhoodFromAddress(addr);
      if (!mounted) return;
      if (n == null || !n.isLinked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주소를 찾지 못했어요. 도로명이나 지번을 조금 더 자세히 적어 주세요'),
          ),
        );
        return;
      }
      setState(() {
        _admCd.text = n.admCd;
        _dongLabel = n.dongName.isEmpty ? '동네 연결 완료' : '${n.dongName}으로 연결했어요';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n.dongName.isEmpty
                ? '우리 동네를 연결했어요'
                : '「${n.dongName}」동네로 연결했어요',
          ),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _submit() async {
    var adm = _admCd.text.replaceAll(RegExp(r'[^0-9]'), '');
    final addr = _address.text.trim();
    if (adm.isEmpty && addr.isNotEmpty) {
      setState(() => _linking = true);
      try {
        final n = await ShopMarketService.instance
            .resolveNeighborhoodFromAddress(addr);
        if (n != null && n.isLinked) {
          adm = n.admCd;
          _admCd.text = adm;
          _dongLabel =
              n.dongName.isEmpty ? '동네 연결 완료' : '${n.dongName}으로 연결했어요';
        }
      } finally {
        if (mounted) setState(() => _linking = false);
      }
    }

    final fixed = _int(_fixed.text) ?? 0;
    final owner = _int(_ownerPay.text) ?? 0;
    final days = _int(_days.text) ?? 0;
    final hours = _double(_hours.text) ?? 0;
    final material = _double(_material.text) ?? 15;
    if (_category.trim().isEmpty ||
        fixed <= 0 ||
        owner <= 0 ||
        days <= 0 ||
        hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('업종 · 고정비 · 목표 월급 · 영업일을 모두 채워 주세요'),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      ShopBizProfile(
        category: _category,
        address: addr,
        admCd: adm,
        monthlyFixedCostKrw: fixed,
        materialRatePct: material.clamp(0, 90),
        targetOwnerPayKrw: owner,
        openDaysPerWeek: days.clamp(1, 7),
        hoursPerDay: hours.clamp(1, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final linked = _admCd.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '내 샵 경영 시작하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '어려운 용어는 몰라도 됩니다. 평소 장사할 때 감으로 아는 숫자만 적어 주세요.\n'
              '주소만 있으면 「우리 동네」인구·근처 샵 정보를 알아서 붙입니다.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '① 무슨 샵인가요?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _category,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final c in _kCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 18),
            const Text(
              '② 샵 주소는 어디인가요?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '예: 경북 경주시 ○○로 12 / 경주시 성건동 123',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _linkNeighborhood(),
              decoration: const InputDecoration(
                hintText: '도로명 또는 지번 주소',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _linking ? null : _linkNeighborhood,
              icon: _linking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on_outlined, size: 18),
              label: Text(
                _linking ? '동네 찾는 중…' : '주소로 우리 동네 연결하기',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (linked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dongLabel.isEmpty ? '우리 동네 연결 완료' : _dongLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  setState(() => _showAdvancedCode = !_showAdvancedCode),
              child: Text(
                _showAdvancedCode ? '코드 입력 숨기기' : '연결이 안 될 때만 · 코드 직접 입력',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (_showAdvancedCode) ...[
              TextField(
                controller: _admCd,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '동네 코드 (자동으로 채워집니다)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              '③ 한 달에 나가는 고정비는?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '임대료 + 관리비 + 보험 등, 손님 없어도 나가는 돈',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fixed,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '예: 2000000',
                suffixText: '원',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '④ 재료비는 매출의 몇 %쯤?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '잘 모르겠으면 15 정도를 넣어도 됩니다. 나중에 바꿀 수 있어요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _material,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '예: 15',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '⑤ 내가 가져가고 싶은 월급은?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '사장 본인 인건비로 계산에 넣습니다. (이게 있어야 진짜 이익이 보입니다)',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ownerPay,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '예: 3000000',
                suffixText: '원',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '⑥ 일주일에 며칠, 하루에 몇 시간 일하나요?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '주 며칠',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hours,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '하루 몇 시간',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _linking ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _linking ? '잠시만요…' : '저장하고 내 숫자 보기',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
