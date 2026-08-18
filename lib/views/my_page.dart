import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/customer_chart.dart';
import '../models/seminar_enrollment.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/media_permission_dialogs.dart';
import '../widgets/membership_ticket_wallet.dart';
import '../widgets/shop_funding_proof_chip.dart';
import '../widgets/shop_tier_badge_chip.dart';
import '../widgets/shop_tier_progress_card.dart';
import '../widgets/seminar_review_modal.dart';
import '../widgets/sori_logo.dart';
import 'ai_shop_report_page.dart';
import 'customer_review_history_page.dart';
import 'director_profile_edit_page.dart';
import 'my_info_edit_page.dart';
import 'seminar_class_open_page.dart';
import 'seminar_feedback_inbox_page.dart';

/// 마이페이지 전용 쿨그레이 배경.
const Color _myPageBg = Color(0xFFF5F6F8);
const Color _mutedText = Color(0xFF757575);

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  SoriStore get store => widget.store;
  ValueChanged<int>? get onSelectTab => widget.onSelectTab;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMembershipWallet();
      store.refreshMySeminarEnrollments();
      if (store.session?.activeMode == UserRole.director) {
        store.refreshSeminarEducationInsight();
        store.refreshSeminarFeedbackReports();
      }
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session;
    if (session == null) return const SizedBox.shrink();

    if (session.activeMode == UserRole.director) {
      return _DirectorVisualMyPage(
        store: store,
        onSelectTab: onSelectTab,
      );
    }
    return _CustomerMyPage(
      store: store,
      session: session,
    );
  }
}

/// 원장 모드 — Instagram형 시각적 프로필 대시보드.
class _DirectorVisualMyPage extends StatefulWidget {
  const _DirectorVisualMyPage({
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<_DirectorVisualMyPage> createState() => _DirectorVisualMyPageState();
}

class _DirectorVisualMyPageState extends State<_DirectorVisualMyPage> {
  SoriStore get store => widget.store;
  ValueChanged<int>? get onSelectTab => widget.onSelectTab;
  bool _avatarUploading = false;

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
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
                    ),
                  ),
                  subtitle: Text(
                    store.seminarFeedbackReportsLoading
                        ? '리포트 불러오는 중…'
                        : '완료 리포트 ${store.seminarFeedbackReports.length}건',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _avatarUploading ? null : _pickAndUploadAvatar,
                            customBorder: const CircleBorder(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
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
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: SoriTokens.primary
                                            .withValues(alpha: 0.22),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    image: avatarImage,
                                  ),
                                  child: avatarImage == null
                                      ? const Padding(
                                          padding: EdgeInsets.all(18),
                                          child: SoriLogo(width: 50, height: 50),
                                        )
                                      : null,
                                ),
                                if (_avatarUploading)
                                  Container(
                                    width: 86,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.4),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(28),
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
                                      width: 28,
                                      height: 28,
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
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
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
                    const SizedBox(height: 14),
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ownerLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
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
                    ] else if (shop.totalSeminarCount > 0 ||
                        shop.totalFundingAmount > 0) ...[
                      const SizedBox(height: 8),
                      ShopFundingProofChip(
                        totalSeminarCount: shop.totalSeminarCount,
                        totalFundingAmount: shop.totalFundingAmount,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DirectorProfileEditPage(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2F7),
                          foregroundColor: SoriTokens.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(height: 12),
                    _QuickDashboardRow(
                      shop: shop,
                      seminarRequestCount:
                          store.seminarEducationInsight?.totalRequests ?? 0,
                      onTierTap: () => _openTierSheet(shop),
                      onSeminarTap: () => _openSeminarSheet(),
                      onAiTap: () => _openAiReport(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '내 샵 관리 케이스',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onSelectTab?.call(3),
                          child: const Text(
                            '전체 보기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (cases.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
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
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 88),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chart = cases[index];
                      final after = chart.afterImageUrl?.trim() ?? '';
                      final before = chart.beforeImageUrl?.trim() ?? '';
                      final url = after.isNotEmpty ? after : before;
                      return Material(
                        color: const Color(0xFFF0F1F3),
                        child: InkWell(
                          onTap: () => onSelectTab?.call(3),
                          child: url.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey,
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
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                    childCount: cases.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
          ],
        ),
      ),
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
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.12),
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
                          color: Colors.grey.shade300,
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
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E4F8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$month월 추정 성과',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
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
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '전월 대비 $deltaLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: delta >= 0
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.revenue.highlight,
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E8EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 맞춤 제안',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '이번 달 추천 집중 메뉴',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
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
            side: const BorderSide(color: Color(0xFFE6E8EC)),
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
              iconBg: const Color(0xFFFFF4E5),
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
      color: const Color(0xFFFBFBFC),
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E8EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: Colors.grey.shade600,
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
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4F8)),
        boxShadow: [
          BoxShadow(
            color: SoriTokens.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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

/// 고객 모드 마이 — 지갑·리뷰 중심 (시스템 설정은 ⚙️).
class _CustomerMyPage extends StatelessWidget {
  const _CustomerMyPage({
    required this.store,
    required this.session,
  });

  final SoriStore store;
  final SessionUser session;

  @override
  Widget build(BuildContext context) {
    final customerId = session.customerId;
    final charts = customerId == null
        ? store.charts
        : store.chartsForCustomer(customerId);
    final reviewCount = charts.where((c) {
      final r = store.reviewForChart(c.id);
      return r != null && DirectorPeriodStats.isCompletedReview(r);
    }).length;
    final wallet = store.activeMembershipWallet;
    final remain = wallet.fold<int>(0, (s, t) => s + t.remainingVisits);
    final displayName =
        session.name.trim().isEmpty ? '고객' : session.name.trim();

    return ColoredBox(
      color: _myPageBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _FloatCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage: session.hasAvatar &&
                            !session.avatarUrl.startsWith('data:')
                        ? NetworkImage(session.avatarUrl)
                        : null,
                    child: session.hasAvatar &&
                            !session.avatarUrl.startsWith('data:')
                        ? null
                        : const Padding(
                            padding: EdgeInsets.all(10),
                            child: Opacity(
                              opacity: 0.85,
                              child: SoriLogo(width: 36, height: 36),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${session.phone} · ${session.providerLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyInfoEditPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      side: const BorderSide(color: SoriTokens.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '프로필',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FloatCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CustomerReviewHistoryPage(store: store),
                        ),
                      );
                    },
                    child: _MiniStat(
                      label: '내 소통 리뷰',
                      value: '$reviewCount',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FloatCard(
                    child: _MiniStat(
                      label: '보유 티켓',
                      value: '${wallet.length}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MySeminarEnrollmentsSection(store: store),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '스마트 회원권 지갑',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (remain > 0)
                  Text(
                    '잔여 합계 $remain회',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            MembershipTicketWallet(
              tickets: wallet,
              onRefresh: store.refreshMembershipWallet,
            ),
            const SizedBox(height: 16),
            Text(
              '모드 전환 · 로그아웃은 상단 ⚙️ 설정에서 관리합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        content: Text('「${enrollment.classTitle}」 수강 완료 · 에스크로 정산이 진행됐어요'),
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '에스크로 보관 중 · ${e.amount > 0 ? '${e.amount}원' : '수강료 결제 완료'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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
                      '수강 완료',
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
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: SoriTokens.primary,
          ),
        ),
      ],
    );
  }
}
