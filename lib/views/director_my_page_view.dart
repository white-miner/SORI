import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/customer_chart.dart';
import '../models/seminar_enrollment.dart';
import '../models/shop.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/case_persona.dart';
import '../widgets/debug_mode_chip.dart';
import '../widgets/media_permission_dialogs.dart';
import '../widgets/seminar_review_modal.dart';
import '../widgets/shop_funding_proof_chip.dart';
import '../widgets/shop_tier_badge_chip.dart';
import '../widgets/shop_tier_progress_card.dart';
import '../widgets/sori_logo.dart';
import 'ai_shop_report_page.dart';
import 'director_profile_edit_page.dart';
import 'seminar_class_open_page.dart';
import 'seminar_feedback_inbox_page.dart';

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
    final shopName = shop.name.trim().isEmpty ? 'SORI' : shop.name.trim();
    final owner = (shop.ownerName ?? '').trim();
    final ownerLabel = owner.isEmpty
        ? '원장'
        : (owner.contains('원장') ? owner : '$owner 원장');
    final reviewCount = store.reviews
        .where(DirectorPeriodStats.isCompletedReview)
        .length;
    final chartCount = store.charts.length;
    final cases = _baCases;
    final avatarUrl = shop.profileImageUrl?.trim() ?? '';
    DecorationImage? avatarImage;
    if (avatarUrl.startsWith('data:image')) {
      try {
        final b64 = avatarUrl.split(',').last;
        avatarImage = DecorationImage(
          image: MemoryImage(base64Decode(b64)),
          fit: BoxFit.cover,
        );
      } catch (_) {
        avatarImage = null;
      }
    } else if (avatarUrl.isNotEmpty) {
      avatarImage = DecorationImage(
        image: NetworkImage(avatarUrl),
        fit: BoxFit.cover,
      );
    }

    final report = AiShopReportMock.demo();

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              _avatarUploading ? null : _pickAndUploadAvatar,
                          customBorder: const CircleBorder(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B7CFF),
                                      Color(0xFF4A3BCF),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  image: avatarImage,
                                ),
                                child: avatarImage == null
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child:
                                            SoriLogo(width: 44, height: 44),
                                      )
                                    : null,
                              ),
                              if (_avatarUploading)
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Colors.black.withValues(alpha: 0.4),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: SoriTokens.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
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
                                onTap: () => onSelectTab?.call(1),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                      ),
                      if (kDebugMode) ...[
                        const DebugModeChip(),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ownerLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  if (shop.tierBadge.isVisible) ...[
                    const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DirectorProfileEditPage(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.surface,
                        foregroundColor: SoriTokens.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: SoriTokens.outlinePurple,
                          ),
                        ),
                      ),
                      child: const Text(
                        '프로필 편집',
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
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: SoriTokens.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.4,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: const [
                Tab(text: 'My 케이스'),
                Tab(text: '내 등급'),
                Tab(text: '세미나 센터'),
                Tab(text: 'AI 경영'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MyCasesHorizontalFeed(
                    cases: cases,
                    store: store,
                    onOpenCasesTab: () => onSelectTab?.call(3),
                  ),
                  _MyTierTabBody(shop: shop),
                  _MySeminarTabBody(
                    store: store,
                    onOpenClass: _openClass,
                  ),
                  _MyAiTabBody(
                    report: report,
                    onApply: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AiShopReportPage(data: report),
                        ),
                      );
                    },
                    onDownload: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('경영 리포트 요약이 준비되었어요'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: SoriTokens.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weverse형 3행 가로 스와이프 케이스 피드 — 고정 높이 카드로 TabBarView 제스처 분리.
class _MyCasesHorizontalFeed extends StatelessWidget {
  const _MyCasesHorizontalFeed({
    required this.cases,
    required this.store,
    required this.onOpenCasesTab,
  });

  final List<CustomerChart> cases;
  final SoriStore store;
  final VoidCallback onOpenCasesTab;

  static const double _cardHeight = 320;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: _cardHeight,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SoriTokens.outlinePurple,
            width: 1,
          ),
        ),
        child: cases.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '등록된 B/A 케이스를 준비 중입니다 ✨\n차트에 Before/After를 남기면 여기에 모여요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              )
            : NotificationListener<ScrollNotification>(
                // 피드 내부 가로 스크롤이 TabBarView로 버블링되지 않게 흡수.
                onNotification: (notification) => true,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.35,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final chart = cases[index];
                    return _WeverseCaseTile(
                      chart: chart,
                      store: store,
                      onTap: onOpenCasesTab,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _WeverseCaseTile extends StatelessWidget {
  const _WeverseCaseTile({
    required this.chart,
    required this.store,
    required this.onTap,
  });

  final CustomerChart chart;
  final SoriStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final after = chart.afterImageUrl?.trim() ?? '';
    final before = chart.beforeImageUrl?.trim() ?? '';
    final url = after.isNotEmpty ? after : before;
    final care = chart.serviceMenuLabel;
    final customer = store.findCustomer(chart.customerId);
    final meta = CasePersona.feedLine(
      chart: chart,
      customer: customer,
      age: chart.feedAge ?? chart.age,
      genderLabel: chart.feedGenderLabel ?? chart.gender,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: ColoredBox(
                  color: const Color(0xFF111113),
                  child: url.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: SoriTokens.textSecondary,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: SoriTokens.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    care,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
