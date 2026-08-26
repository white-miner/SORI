import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer_chart.dart';
import '../models/seminar_class_detail.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/shop_funding_proof_chip.dart';
import '../widgets/shop_tier_badge_chip.dart';
import 'seminar_apply_page.dart';

/// B2B 세미나 클래스 모집 랜딩 — SliverAppBar + 에스크로 CTA.
class SeminarClassDetailPage extends StatefulWidget {
  const SeminarClassDetailPage({
    super.key,
    required this.store,
    required this.classId,
  });

  final SoriStore store;
  final String classId;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required String classId,
  }) {
    return pushRootPage<void>(
      context,
      SeminarClassDetailPage(store: store, classId: classId),
    );
  }

  @override
  State<SeminarClassDetailPage> createState() => _SeminarClassDetailPageState();
}

class _SeminarClassDetailPageState extends State<SeminarClassDetailPage> {
  SeminarClassDetail? _detail;
  bool _loading = true;
  String? _error;
  late final PageController _heroController;
  int _heroIndex = 0;

  static final _priceFmt = NumberFormat('#,###', 'ko_KR');
  static final _dateFmt = DateFormat('M월 d일 (E) HH:mm', 'ko_KR');

  @override
  void initState() {
    super.initState();
    _heroController = PageController();
    _load();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final detail = await widget.store.loadSeminarClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
      _error = detail == null ? '클래스를 찾을 수 없습니다.' : null;
    });
  }

  Future<void> _onEscrowPaymentTap() async {
    final detail = _detail;
    if (detail == null || !detail.seminarClass.isEnrollable) return;
    if (detail.remainingSeats <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모집이 마감되었습니다.'),
          backgroundColor: SoriTokens.primaryDark,
        ),
      );
      return;
    }

    await SeminarApplyPage.open(
      context,
      store: widget.store,
      classId: widget.classId,
      detail: detail,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: SoriTokens.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        backgroundColor: SoriTokens.background,
        appBar: AppBar(
          backgroundColor: SoriTokens.surface,
          foregroundColor: SoriTokens.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? '클래스를 찾을 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final cls = detail.seminarClass;
    final shop = detail.directorShop;
    final heroUrls = detail.heroImageUrls;
    final hasHeroSlider = heroUrls.length >= 2;
    final chart = detail.targetChart;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      bottomNavigationBar: _StickyEscrowBar(
        price: cls.price,
        enabled: cls.isEnrollable && detail.remainingSeats > 0,
        onPay: _onEscrowPaymentTap,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasHeroSlider ? 320 : 280,
            pinned: true,
            stretch: true,
            backgroundColor: SoriTokens.primary,
            foregroundColor: SoriTokens.onPrimary,
            title: Text(
              cls.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: _HeroHeader(
                heroUrls: heroUrls,
                chart: chart,
                pageController: _heroController,
                pageIndex: _heroIndex,
                onPageChanged: (i) => setState(() => _heroIndex = i),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DirectorProfileSection(
                    shop: shop,
                    ownerLabel: shop.ownerName?.trim().isNotEmpty == true
                        ? shop.ownerName!.trim()
                        : '원장',
                  ),
                  const SizedBox(height: 14),
                  _EventInfoBox(
                    eventDate: cls.eventDate,
                    currentEnrollment: cls.currentEnrollment,
                    maxCapacity: cls.maxCapacity,
                    location: cls.location,
                    dateFmt: _dateFmt,
                  ),
                  const SizedBox(height: 20),
                  _AutoSyllabusSection(tags: detail.syllabusTags),
                  const SizedBox(height: 20),
                  _FomoProgressSection(
                    current: cls.currentEnrollment,
                    max: cls.maxCapacity,
                    remaining: detail.remainingSeats,
                    isAlmostFull: detail.isAlmostFull,
                    ratio: detail.enrollmentRatio,
                  ),
                  const SizedBox(height: 20),
                  _DescriptionSection(text: detail.displayDescription),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.heroUrls,
    required this.chart,
    required this.pageController,
    required this.pageIndex,
    required this.onPageChanged,
  });

  final List<String> heroUrls;
  final CustomerChart? chart;
  final PageController pageController;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (heroUrls.length >= 2) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: heroUrls.length,
            itemBuilder: (context, index) {
              final label = index == 0 ? 'Before' : 'After';
              return ChartImagePane(
                url: heroUrls[index],
                fallbackLabel: label,
                tone: index == 0 ? SoriTokens.primary : SoriTokens.textSecondary,
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(heroUrls.length, (i) {
                final active = i == pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
          const Positioned(
            left: 12,
            top: 56,
            child: _HeroCornerTag(label: 'B/A 케이스'),
          ),
        ],
      );
    }

    if (chart != null) {
      final c = chart!;
      return Stack(
        fit: StackFit.expand,
        children: [
          BeforeAfterSlider(
            height: 320,
            before: ChartImagePane(
              url: c.beforeImageUrl,
              fallbackLabel: 'Before',
              tone: SoriTokens.primary,
            ),
            after: ChartImagePane(
              url: c.afterImageUrl,
              fallbackLabel: 'After',
              tone: SoriTokens.textSecondary,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ColoredBox(
      color: SoriTokens.primarySoft,
      child: Center(
        child: Icon(
          Icons.school_outlined,
          size: 72,
          color: SoriTokens.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _HeroCornerTag extends StatelessWidget {
  const _HeroCornerTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DirectorProfileSection extends StatelessWidget {
  const _DirectorProfileSection({
    required this.shop,
    required this.ownerLabel,
  });

  final Shop shop;
  final String ownerLabel;

  @override
  Widget build(BuildContext context) {
    final avatar = shop.profileImageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: SoriTokens.primarySoft,
            backgroundImage: avatar.startsWith('http')
                ? NetworkImage(avatar)
                : null,
            child: avatar.startsWith('http')
                ? null
                : Text(
                    ownerLabel.characters.first,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shop.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SoriTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (shop.tierBadge.isVisible)
                      ShopTierBadgeChip(badge: shop.tierBadge, compact: true),
                    ShopFundingProofChip(
                      totalSeminarCount: shop.totalSeminarCount,
                      totalFundingAmount: shop.totalFundingAmount,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfoBox extends StatelessWidget {
  const _EventInfoBox({
    required this.eventDate,
    required this.currentEnrollment,
    required this.maxCapacity,
    required this.location,
    required this.dateFmt,
  });

  final DateTime? eventDate;
  final int currentEnrollment;
  final int maxCapacity;
  final String location;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final dateLabel = eventDate == null
        ? '일정 미정'
        : dateFmt.format(eventDate!.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SoriTokens.card(radius: SoriTokens.radiusMd),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoChip(
            icon: Icons.event_rounded,
            label: dateLabel,
            tint: SoriTokens.primary,
          ),
          _InfoChip(
            icon: Icons.people_alt_outlined,
            label: '$currentEnrollment / $maxCapacity명',
            tint: const Color(0xFF0EA5E9),
          ),
          _InfoChip(
            icon: Icons.place_outlined,
            label: location.trim().isEmpty ? '장소 미정' : location.trim(),
            tint: SoriTokens.primary,
            trailing: location.trim().isNotEmpty
                ? const Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: SoriTokens.textSecondary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.tint,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AutoSyllabusSection extends StatelessWidget {
  const _AutoSyllabusSection({required this.tags});

  final List<String> tags;

  static const _icons = [
    Icons.auto_awesome,
    Icons.spa_outlined,
    Icons.biotech_outlined,
    Icons.healing_outlined,
    Icons.water_drop_outlined,
    Icons.face_retouching_natural,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: SoriTokens.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                '이 클래스의 핵심 마스터 기술',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tags.isEmpty)
            Text(
              '연동된 차트에서 care_tags·care_name을 불러오면 자동으로 표시됩니다.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < tags.length; i++)
                  _SyllabusTagChip(
                    label: tags[i],
                    icon: _icons[i % _icons.length],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SyllabusTagChip extends StatelessWidget {
  const _SyllabusTagChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hash = label.trim().startsWith('#') ? label.trim() : '#${label.trim()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SoriTokens.primarySoft,
            SoriTokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: SoriTokens.primary),
          const SizedBox(width: 8),
          Text(
            hash,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FomoProgressSection extends StatelessWidget {
  const _FomoProgressSection({
    required this.current,
    required this.max,
    required this.remaining,
    required this.isAlmostFull,
    required this.ratio,
  });

  final int current;
  final int max;
  final int remaining;
  final bool isAlmostFull;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final fomoColor = isAlmostFull
        ? const Color(0xFFDC2626)
        : SoriTokens.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '모집 현황',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $max명 신청',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.05, 1.0),
              minHeight: 12,
              backgroundColor: SoriTokens.border,
              color: isAlmostFull
                  ? const Color(0xFFEF4444)
                  : SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remaining <= 0
                ? '마감 — 대기자 등록만 가능합니다'
                : isAlmostFull
                    ? '마감 임박: 잔여 ${remaining}자리'
                    : '잔여 ${remaining}자리 · 지금 신청하세요',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: fomoColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '세미나 상세 설명',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: SoriTokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyEscrowBar extends StatelessWidget {
  const _StickyEscrowBar({
    required this.price,
    required this.enabled,
    required this.onPay,
  });

  final int price;
  final bool enabled;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '수강료',
                  style: const TextStyle(
                    fontSize: 11,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_SeminarClassDetailPageState._priceFmt.format(price)}원',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled ? onPay : null,
                icon: const Icon(Icons.verified_user_outlined, size: 20),
                label: const Text(
                  '수강 신청하기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  disabledBackgroundColor: SoriTokens.border,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
