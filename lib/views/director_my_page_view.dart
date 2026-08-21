import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/customer_chart.dart';
import '../models/seminar_enrollment.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../models/shop_service_item.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/storage_image_url.dart';
import '../widgets/debug_mode_chip.dart';
import '../widgets/media_permission_dialogs.dart';
import '../widgets/seminar_review_modal.dart';
import '../widgets/shop_funding_proof_chip.dart';
import '../widgets/shop_tier_badge_chip.dart';
import '../widgets/shop_tier_progress_card.dart';
import 'ai_shop_report_page.dart';
import 'director_profile_edit_page.dart';
import 'seminar_class_open_page.dart';
import 'seminar_feedback_inbox_page.dart';
import 'service_menu_page.dart';

/// 원장 모드 마이페이지 — Instagram/Weverse형 시각 프로필 대시보드.
class DirectorMyPageView extends StatefulWidget {
  const DirectorMyPageView({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<DirectorMyPageView> createState() => _DirectorMyPageViewState();
}

class _DirectorMyPageViewState extends State<DirectorMyPageView>
    with SingleTickerProviderStateMixin {
  SoriStore get store => widget.store;
  ValueChanged<int>? get onSelectTab => widget.onSelectTab;
  bool _avatarUploading = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _topRequestedCaseId() {
    final insight = store.seminarEducationInsight;
    if (insight == null || insight.requestsByCase.isEmpty) return null;
    var bestId = '';
    var bestCount = -1;
    for (final e in insight.requestsByCase.entries) {
      if (e.value > bestCount) {
        bestCount = e.value;
        bestId = e.key;
      }
    }
    return bestId.isEmpty ? null : bestId;
  }

  CustomerChart? _chartById(String id) => store.findChartById(id);

  List<CustomerChart> get _baCases {
    final out = <CustomerChart>[];
    for (final chart in store.charts) {
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      final shopId = store.shop.id;
      if (chart.shopId.isNotEmpty &&
          shopId.isNotEmpty &&
          chart.shopId != shopId) {
        continue;
      }
      out.add(chart);
    }
    out.sort((a, b) {
      final ad = a.visitCheckedAt ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.visitCheckedAt ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// DB 샵 Bio 우선 — 홈케어 팁 더미는 사용하지 않음.
  String get _bio {
    final shop = store.shop;
    final bio = shop.bio.trim();
    if (bio.isNotEmpty) return bio;
    final hours = shop.operatingHours.trim();
    final parts = <String>[];
    if (hours.isNotEmpty) parts.add('영업 $hours');
    if (shop.address != null && shop.address!.trim().isNotEmpty) {
      parts.add(shop.address!.trim());
    }
    if (parts.isEmpty) {
      return '샵 소개말을 프로필 편집에서 등록해 주세요.';
    }
    return parts.join('\n');
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_avatarUploading) return;
    final file = await pickImageWithPermissionGuards(
      context: context,
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ok = await store.uploadShopProfileImage(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '프로필 사진이 업데이트되었어요' : '업로드에 실패했어요. 스토리지 권한을 확인해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? SoriTokens.primary : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진 업로드 오류: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _openAiReport() async {
    final report = AiShopReportMock.demo();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: 'AI 샵 경영 리포트',
          child: _AiManagementSheetBody(
            report: report,
            onApply: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AiShopReportPage(data: report),
                ),
              );
            },
            onDownload: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('8월 경영 리포트 요약이 준비되었어요'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: SoriTokens.primary,
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openClass() {
    final topCase = _topRequestedCaseId();
    final chart = topCase == null ? null : _chartById(topCase);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeminarClassOpenPage(
          store: store,
          targetCaseId: topCase,
          initialTitle: chart?.careName ?? '',
        ),
      ),
    );
  }

  Future<void> _openTierSheet(Shop shop) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: '내 등급 · 티어 프로그레스',
          child: ShopTierProgressCard(shop: shop),
        );
      },
    );
  }

  Future<void> _openSeminarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: '세미나 센터',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeminarEducationInsightCard(
                loading: store.seminarEducationLoading,
                totalRequests:
                    store.seminarEducationInsight?.totalRequests ?? 0,
                soriCashBalance: store.shop.soriCashBalance,
                onOpenClass: () {
                  Navigator.pop(ctx);
                  _openClass();
                },
              ),
              const SizedBox(height: 8),
              Material(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: SoriTokens.outlinePurple),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '📊',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  title: const Text(
                    'AI 세미나 피드백 보관함',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    store.seminarFeedbackReports.isEmpty
                        ? '세미나 후기 AI 인사이트를 모아보세요'
                        : (store.seminarFeedbackReportsLoading
                            ? '리포트 불러오는 중…'
                            : '완료 리포트 ${store.seminarFeedbackReports.length}건'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    SeminarFeedbackInboxPage.open(
                      context,
                      store: store,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _MySeminarEnrollmentsSection(store: store),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final session = store.session;
    final shopName =
        shop.name.trim().isEmpty ? 'Sori 에스테틱' : shop.name.trim();
    final reviewCount =
        store.reviews.where(DirectorPeriodStats.isCompletedReview).length;
    final cases = _baCases;
    final report = AiShopReportMock.demo();
    final isOwner = session?.activeMode == UserRole.director;
    final coverUrl = (shop.profileImageUrl ?? '').trim();

    return ColoredBox(
      color: SoriTokens.background,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              elevation: 0,
              backgroundColor: SoriTokens.background,
              foregroundColor: SoriTokens.textPrimary,
              forceElevated: innerBoxIsScrolled,
              actions: [
                if (kDebugMode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Center(child: DebugModeChip()),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _ShopHeroCover(
                  shopName: shopName,
                  coverUrl: coverUrl,
                  isOwner: isOwner,
                  coverUploading: _avatarUploading,
                  onCoverPick: isOwner ? _pickAndUploadAvatar : null,
                  onCta: () {
                    if (isOwner) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DirectorProfileEditPage(),
                        ),
                      );
                    } else {
                      final url = shop.naverBookingUrl.trim().isNotEmpty
                          ? shop.naverBookingUrl.trim()
                          : shop.naverPlaceUrl.trim();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            url.isEmpty
                                ? '예약 링크가 아직 등록되지 않았어요'
                                : '예약 페이지로 이동합니다',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: SoriTokens.primary,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: SoriTokens.primary,
                  unselectedLabelColor: SoriTokens.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: SoriTokens.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2.4,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'Feed'),
                    Tab(text: 'Shop'),
                    Tab(text: 'Review'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _HomeTabBody(
              store: store,
              shop: shop,
              bio: _bio,
              reviewCount: reviewCount,
              chartCount: store.charts.length,
              onSelectCustomers: () => onSelectTab?.call(1),
              onOpenClass: _openClass,
              onOpenAi: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiShopReportPage(data: report),
                  ),
                );
              },
            ),
            _ServiceGroupedFeedTab(
              cases: cases,
              store: store,
              onOpenCasesTab: () => onSelectTab?.call(3),
            ),
            _ShopInfoTab(shop: shop, isOwner: isOwner),
            _ReviewTabBody(store: store),
          ],
        ),
      ),
    );
  }
}

/// 풀블리드 샵 간판 + 그라데이션 오버레이.
class _ShopHeroCover extends StatelessWidget {
  const _ShopHeroCover({
    required this.shopName,
    required this.coverUrl,
    required this.isOwner,
    required this.onCta,
    this.onCoverPick,
    this.coverUploading = false,
  });

  final String shopName;
  final String coverUrl;
  final bool isOwner;
  final VoidCallback onCta;
  final VoidCallback? onCoverPick;
  final bool coverUploading;

  static const _fallbackCover =
      'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=1400&q=80';

  @override
  Widget build(BuildContext context) {
    final src = coverUrl.isNotEmpty &&
            (coverUrl.startsWith('http://') || coverUrl.startsWith('https://'))
        ? coverUrl
        : _fallbackCover;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          src,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFF1A1028),
            child: Center(
              child: Icon(
                Icons.spa_rounded,
                size: 64,
                color: SoriTokens.primary,
              ),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x99000000),
                Color(0xFF0A0A0C),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: isOwner ? 72 : 20,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shopName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: isOwner
                    ? OutlinedButton(
                        onPressed: onCta,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.10),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          '프로필 편집',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: onCta,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        child: const Text(
                          '예약하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (isOwner && onCoverPick != null)
          Positioned(
            right: 16,
            bottom: 28,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0x66FFFFFF)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: coverUploading ? null : onCoverPick,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: coverUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.photo_camera,
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: SoriTokens.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _SquircleCard extends StatelessWidget {
  const _SquircleCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: child,
    );
  }
}

class _HomeTabBody extends StatelessWidget {
  const _HomeTabBody({
    required this.store,
    required this.shop,
    required this.bio,
    required this.reviewCount,
    required this.chartCount,
    required this.onSelectCustomers,
    required this.onOpenClass,
    required this.onOpenAi,
  });

  final SoriStore store;
  final Shop shop;
  final String bio;
  final int reviewCount;
  final int chartCount;
  final VoidCallback onSelectCustomers;
  final VoidCallback onOpenClass;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SquircleCard(
          child: Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  value: '$reviewCount',
                  label: '소통 리뷰',
                ),
              ),
              Expanded(
                child: _ProfileStat(
                  value: '${store.customers.length}',
                  label: '등록 고객',
                  onTap: onSelectCustomers,
                ),
              ),
              Expanded(
                child: _ProfileStat(
                  value: '$chartCount',
                  label: '차트 작성',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SquircleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '샵 소개',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: SoriTokens.textSecondary,
                ),
              ),
              if (shop.tierBadge.isVisible) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ShopTierBadgeChip(badge: shop.tierBadge),
                    ShopFundingProofChip(
                      totalSeminarCount: shop.totalSeminarCount,
                      totalFundingAmount: shop.totalFundingAmount,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SquircleCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined,
                    color: SoriTokens.primary),
                title: const Text(
                  '세미나 센터',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: SoriTokens.textSecondary),
                onTap: onOpenClass,
              ),
              const Divider(color: SoriTokens.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_graph_rounded,
                    color: SoriTokens.primary),
                title: const Text(
                  'AI 경영 리포트',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: SoriTokens.textSecondary),
                onTap: onOpenAi,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShopTierProgressCard(shop: shop),
      ],
    );
  }
}

class _ShopInfoTab extends StatelessWidget {
  const _ShopInfoTab({required this.shop, required this.isOwner});

  final Shop shop;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final menu = shop.serviceMenu;
    final devices = <String>{};
    for (final item in menu) {
      final d = item.deviceInfo?.trim() ?? '';
      if (d.isNotEmpty) devices.add(d);
    }
    final hours = shop.operatingHours.trim();
    final address = (shop.address ?? '').trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SquircleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '대표 시술 메뉴',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                  if (isOwner)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ServiceMenuPage(),
                          ),
                        );
                      },
                      child: const Text(
                        '메뉴 관리',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (menu.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '등록된 시술 메뉴가 없어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...List.generate(menu.length, (i) {
                  final item = menu[i];
                  final priceLabel = _priceLabel(item);
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(height: 20, color: SoriTokens.border),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name.trim().isEmpty
                                      ? '시술'
                                      : item.name.trim(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: SoriTokens.textPrimary,
                                  ),
                                ),
                                if (item.description.trim().isNotEmpty &&
                                    priceLabel == '문의') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description.trim(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: SoriTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            priceLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: priceLabel == '문의'
                                  ? SoriTokens.textSecondary
                                  : SoriTokens.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SquircleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '사용 기기 및 제품',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                const Text(
                  '등록된 기기 정보가 없어요',
                  style: TextStyle(
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: devices
                      .map(
                        (d) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: SoriTokens.outlinePurple),
                          ),
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC4B5FD),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SquircleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '운영 안내',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _InfoLine(
                icon: Icons.place_outlined,
                label: address.isEmpty ? '주소 미등록' : address,
              ),
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.schedule_rounded,
                label: hours.isEmpty ? '운영시간 미등록' : hours,
              ),
              if ((shop.phone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.phone_outlined,
                  label: shop.phone!.trim(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// description에 숫자/원이 있으면 가격처럼 노출, 없으면 문의.
  static String _priceLabel(ShopServiceItem item) {
    final d = item.description.trim();
    if (d.isEmpty) return '문의';
    if (RegExp(r'\d').hasMatch(d) &&
        (d.contains('원') || d.contains('만') || d.contains('₩'))) {
      return d;
    }
    if (RegExp(r'^[\d,]+원?$').hasMatch(d.replaceAll(' ', ''))) {
      return d.endsWith('원') ? d : '$d원';
    }
    return '문의';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: SoriTokens.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewTabBody extends StatelessWidget {
  const _ReviewTabBody({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final reviews = store.reviews
        .where(DirectorPeriodStats.isCompletedReview)
        .toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime(1970);
        final bd = b.createdAt ?? DateTime(1970);
        return bd.compareTo(ad);
      });

    if (reviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '아직 표시할 후기가 없어요',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: reviews.length.clamp(0, 30),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = reviews[i];
        return _SquircleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.displayText.trim().isEmpty ? '(내용 없음)' : r.displayText.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textPrimary,
                ),
              ),
              if ((r.directorReply ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '원장 답글 · ${r.directorReply!.trim()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Feed 탭 — careName별 동적 가로 섹션 (Weverse 스타일).
class _ServiceGroupedFeedTab extends StatefulWidget {
  const _ServiceGroupedFeedTab({
    required this.cases,
    required this.store,
    required this.onOpenCasesTab,
  });

  final List<CustomerChart> cases;
  final SoriStore store;
  final VoidCallback onOpenCasesTab;

  @override
  State<_ServiceGroupedFeedTab> createState() => _ServiceGroupedFeedTabState();
}

class _ServiceGroupedFeedTabState extends State<_ServiceGroupedFeedTab> {
  static const double _sectionCardHeight = 260;
  static const double _cardWidth = 188;

  /// careName → charts (빌드마다 재계산 최소화용 캐시)
  Map<String, List<CustomerChart>> _grouped = const {};
  List<String> _sectionOrder = const [];
  List<CustomerChart>? _cachedSource;

  @override
  void initState() {
    super.initState();
    _rebuildGroups(widget.cases);
  }

  @override
  void didUpdateWidget(covariant _ServiceGroupedFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cases, widget.cases) &&
        !_sameCaseIds(oldWidget.cases, widget.cases)) {
      _rebuildGroups(widget.cases);
    }
  }

  bool _sameCaseIds(List<CustomerChart> a, List<CustomerChart> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _rebuildGroups(List<CustomerChart> cases) {
    _cachedSource = cases;
    final map = <String, List<CustomerChart>>{};
    for (final chart in cases) {
      final key = chart.careName.trim().isEmpty ? '기타 케어' : chart.careName.trim();
      (map[key] ??= <CustomerChart>[]).add(chart);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final ad = a.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    }

    // serviceMenu 순서 우선, 그다음 게시물 수, 이름
    final menuOrder = widget.store.shop.serviceNames;
    final keys = map.keys.toList();
    keys.sort((a, b) {
      final ai = menuOrder.indexOf(a);
      final bi = menuOrder.indexOf(b);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      if (a == '기타 케어') return 1;
      if (b == '기타 케어') return -1;
      final ac = map[a]!.length;
      final bc = map[b]!.length;
      if (ac != bc) return bc.compareTo(ac);
      return a.compareTo(b);
    });

    _grouped = map;
    _sectionOrder = keys;
  }

  @override
  Widget build(BuildContext context) {
    if (!identical(_cachedSource, widget.cases) &&
        !_sameCaseIds(_cachedSource ?? const [], widget.cases)) {
      _rebuildGroups(widget.cases);
    }

    if (widget.cases.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            '등록된 B/A 케이스를 준비 중입니다 ✨\n차트에 Before/After를 남기면 서비스별로 모여요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
      itemCount: _sectionOrder.length,
      itemBuilder: (context, sectionIndex) {
        final title = _sectionOrder[sectionIndex];
        final items = _grouped[title] ?? const <CustomerChart>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenCasesTab,
                      style: TextButton.styleFrom(
                        foregroundColor: SoriTokens.textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        '더보기 >',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _sectionCardHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      return SizedBox(
                        width: _cardWidth,
                        child: _FeedBaPostCard(
                          chart: items[i],
                          store: widget.store,
                          onTap: widget.onOpenCasesTab,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedBaPostCard extends StatelessWidget {
  const _FeedBaPostCard({
    required this.chart,
    required this.store,
    required this.onTap,
  });

  final CustomerChart chart;
  final SoriStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final after = StorageImageUrl.resolve(chart.afterImageUrl);
    final before = StorageImageUrl.resolve(chart.beforeImageUrl);
    final url = (after ?? before ?? '').trim();
    final when = chart.relativeTimeLabel;
    // 커뮤니티 감성용 스테이블 더미 카운트 (로컬 해시)
    final likeSeed = chart.id.hashCode.abs();
    final likes = 12 + (likeSeed % 240);
    final comments = 2 + (likeSeed % 48);

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SoriTokens.outlinePurple),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xFF111113),
                      child: url.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: SoriTokens.textSecondary,
                                size: 36,
                              ),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: SoriTokens.textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                    ),
                    // 하단 가독성용 그라데이션
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xCC18181B),
                            ],
                          ),
                        ),
                        child: SizedBox(height: 72, width: double.infinity),
                      ),
                    ),
                    if (before != null && after != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'B/A',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      when.isEmpty ? '최근' : when,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('♡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('💬', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '$comments',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyTierTabBody extends StatelessWidget {
  const _MyTierTabBody({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        ShopTierProgressCard(shop: shop),
        const SizedBox(height: 14),
        if (shop.tierBadge.isVisible)
          Align(
            alignment: Alignment.centerLeft,
            child: ShopTierBadgeChip(badge: shop.tierBadge),
          ),
      ],
    );
  }
}

class _MySeminarTabBody extends StatelessWidget {
  const _MySeminarTabBody({
    required this.store,
    required this.onOpenClass,
  });

  final SoriStore store;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _SeminarEducationInsightCard(
          loading: store.seminarEducationLoading,
          totalRequests: store.seminarEducationInsight?.totalRequests ?? 0,
          soriCashBalance: store.shop.soriCashBalance,
          onOpenClass: onOpenClass,
        ),
        const SizedBox(height: 12),
        Material(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: SoriTokens.outlinePurple),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📊', style: TextStyle(fontSize: 18)),
            ),
            title: const Text(
              'AI 세미나 피드백 보관함',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: SoriTokens.textPrimary,
              ),
            ),
            subtitle: Text(
              store.seminarFeedbackReportsLoading
                  ? '리포트 불러오는 중…'
                  : '완료 리포트 ${store.seminarFeedbackReports.length}건',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: SoriTokens.textSecondary,
            ),
            onTap: () => SeminarFeedbackInboxPage.open(context, store: store),
          ),
        ),
        const SizedBox(height: 12),
        _MySeminarEnrollmentsSection(store: store),
      ],
    );
  }
}

class _MyAiTabBody extends StatelessWidget {
  const _MyAiTabBody({
    required this.report,
    required this.onApply,
    required this.onDownload,
  });

  final AiShopReportMock report;
  final VoidCallback onApply;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _AiManagementSheetBody(
          report: report,
          onApply: onApply,
          onDownload: onDownload,
        ),
      ],
    );
  }
}

/// 퀵 대시보드 공통 바텀시트 — 화이트, 상단 라운드 24, PC maxWidth 500.
class _SoriQuickSheet extends StatelessWidget {
  const _SoriQuickSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: maxH),
          child: Material(
            color: SoriTokens.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SoriTokens.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiManagementSheetBody extends StatelessWidget {
  const _AiManagementSheetBody({
    required this.report,
    required this.onApply,
    required this.onDownload,
  });

  final AiShopReportMock report;
  final VoidCallback onApply;
  final VoidCallback onDownload;

  String get _salesLabel {
    final won = report.revenue.estimatedSalesWon;
    if (won >= 100000000) {
      return '${(won / 100000000).toStringAsFixed(1)}억';
    }
    if (won >= 10000) {
      return '${_comma((won / 10000).round())}만원';
    }
    return '${_comma(won)}원';
  }

  String _comma(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final delta = report.revenue.salesDeltaPercent;
    final deltaLabel = delta >= 0
        ? '+${delta.toStringAsFixed(1)}%'
        : '${delta.toStringAsFixed(1)}%';
    final menus = report.portfolio.investMenus.take(2).toList();
    final month = DateTime.now().month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SoriTokens.card(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$month월 추정 성과',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _salesLabel,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: delta >= 0
                          ? const Color(0x3322C55E)
                          : const Color(0x33EF4444),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '전월 대비 $deltaLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: delta >= 0
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.revenue.highlight,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SoriTokens.card(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 맞춤 제안',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '이번 달 추천 집중 메뉴',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...menus.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SoriTokens.primarySoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          m.tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                report.targetSegment.summary,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onApply,
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'AI 솔루션 적용하기',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onDownload,
          style: OutlinedButton.styleFrom(
            foregroundColor: SoriTokens.textPrimary,
            side: const BorderSide(color: SoriTokens.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '상세 리포트 다운로드',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _QuickDashboardRow extends StatelessWidget {
  const _QuickDashboardRow({
    required this.shop,
    required this.seminarRequestCount,
    required this.onTierTap,
    required this.onSeminarTap,
    required this.onAiTap,
  });

  final Shop shop;
  final int seminarRequestCount;
  final VoidCallback onTierTap;
  final VoidCallback onSeminarTap;
  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;
    final progressPct =
        ((snap.socialRatio > snap.businessRatio
                    ? snap.socialRatio
                    : snap.businessRatio) *
                100)
            .round()
            .clamp(0, 100);
    final tierLabel = shop.tierBadge.label.trim();
    final tierSub = tierLabel.isNotEmpty ? tierLabel : '달성률 $progressPct%';
    final month = DateTime.now().month;

    return SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: _QuickDashCard(
              icon: Icons.military_tech_rounded,
              iconColor: const Color(0xFFB7791F),
              iconBg: SoriTokens.warningBg,
              title: '내 등급',
              subtitle: tierSub,
              onTap: onTierTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickDashCard(
              icon: Icons.school_rounded,
              iconColor: SoriTokens.primary,
              iconBg: SoriTokens.primarySoft,
              title: '세미나 센터',
              subtitle: '요청 $seminarRequestCount건',
              onTap: onSeminarTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickDashCard(
              icon: Icons.auto_graph_rounded,
              iconColor: const Color(0xFF0F766E),
              iconBg: const Color(0xFFCCFBF1),
              title: 'AI 경영',
              subtitle: '$month월 리포트',
              onTap: onAiTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDashCard extends StatelessWidget {
  const _QuickDashCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: SoriTokens.signatureBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

class _SeminarEducationInsightCard extends StatelessWidget {
  const _SeminarEducationInsightCard({
    required this.loading,
    required this.totalRequests,
    required this.soriCashBalance,
    required this.onOpenClass,
  });

  final bool loading;
  final int totalRequests;
  final int soriCashBalance;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: SoriTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '교육 수요 인사이트',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '내 게시물 세미나 요청 $totalRequests건',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'SORI Cash 잔액 ${soriCashBalance.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onOpenClass,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '클래스 오픈하기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}



class _MySeminarEnrollmentsSection extends StatelessWidget {
  const _MySeminarEnrollmentsSection({required this.store});

  final SoriStore store;

  Future<void> _complete(BuildContext context, SeminarEnrollment enrollment) async {
    final ok = await SeminarReviewModal.show(
      context,
      store: store,
      enrollmentId: enrollment.id,
      classId: enrollment.classId,
      classTitle: enrollment.classTitle,
    );
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${enrollment.classTitle} 수강 후기가 저장되었어요'),
        backgroundColor: SoriTokens.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final held = store.mySeminarEnrollments.where((e) => e.isHeld).toList();
    if (store.mySeminarEnrollmentsLoading && held.isEmpty) {
      return const _FloatCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (held.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '내 세미나 수강',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...held.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FloatCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.classTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.amount > 0 ? '결제 ${e.amount}원' : '수강 확정',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _complete(context, e),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      '후기 작성',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: SoriTokens.signatureBorder,
        boxShadow: _shadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}
