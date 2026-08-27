import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/customer_review.dart';
import '../models/review_request_event.dart';
import '../routing/sori_router.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../widgets/review_qr_modal.dart';
import '../widgets/sori_card.dart';
import 'customer_link_popup.dart';
import 'request_customer_review.dart';

enum _ReviewSort { recent, ratingHigh, ratingLow }

enum _RequestSegment { pending, sent, converted }

/// 원장용 리뷰 관리 — 운영 콘솔 (우선순위 인박스 + 후기 요청).
class DirectorReviewManagePage extends StatefulWidget {
  const DirectorReviewManagePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorReviewManagePage> createState() =>
      _DirectorReviewManagePageState();
}

class _DirectorReviewManagePageState extends State<DirectorReviewManagePage>
    with SingleTickerProviderStateMixin {
  static const _bodyParts = ['얼굴', '복부', '등', '하체'];
  static const _ageBands = ['20대', '30대', '40대', '50대 이상'];

  late final TabController _tabs;
  final Set<String> _requestedIds = {};
  final _search = TextEditingController();

  ReviewOpsLane _lane = ReviewOpsLane.unreplied;
  _RequestSegment _requestSegment = _RequestSegment.pending;
  _ReviewSort _sort = _ReviewSort.recent;
  String? _careFilter;
  String? _bodyFilter;
  CustomerGender? _genderFilter;
  String? _ageFilter;
  String? _replyingReviewId;
  final _replyController = TextEditingController();
  bool _savingReply = false;
  bool _togglingNaver = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshReviewRequestEvents(soft: true);
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _tabs.dispose();
    _search.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<Customer> get _todayDone {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = widget.store.customersForDate(today);
    if (byDate.isNotEmpty) return byDate;
    final checked = widget.store.customers.where((c) {
      final chart = widget.store.latestChart(c.id);
      return chart?.visitChecked == true;
    }).toList();
    if (checked.isNotEmpty) return checked;
    return widget.store.customers;
  }

  List<String> get _careOptions {
    final set = <String>{};
    for (final item in widget.store.directorReviewInboxItems()) {
      final name = item.careName.trim();
      if (name.isNotEmpty && name != '케어') set.add(name);
    }
    for (final s in widget.store.shop.serviceMenu) {
      final n = s.name.trim();
      if (n.isNotEmpty) set.add(n);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<DirectorReviewInboxItem> get _filteredInbox {
    var list = widget.store.directorReviewInboxItems(lane: _lane);
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((item) {
        final blob =
            '${item.displayName} ${item.careName} ${item.review.displayText} ${item.bodyTags.join(' ')}'
                .toLowerCase();
        return blob.contains(q);
      }).toList();
    }
    if (_careFilter != null) {
      list = list.where((i) => i.careName == _careFilter).toList();
    }
    if (_bodyFilter != null) {
      list = list.where((i) => i.matchesBodyPart(_bodyFilter!)).toList();
    }
    if (_genderFilter != null) {
      list = list.where((i) => i.gender == _genderFilter).toList();
    }
    if (_ageFilter != null) {
      list = list.where((i) => i.ageBand == _ageFilter).toList();
    }

    list = List.of(list);
    switch (_sort) {
      case _ReviewSort.recent:
        if (_lane == ReviewOpsLane.unreplied) {
          list.sort((a, b) => a.sortDate.compareTo(b.sortDate));
        } else {
          list.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        }
      case _ReviewSort.ratingHigh:
        list.sort((a, b) {
          final c = b.review.effectiveRating.compareTo(a.review.effectiveRating);
          return c != 0 ? c : b.sortDate.compareTo(a.sortDate);
        });
      case _ReviewSort.ratingLow:
        list.sort((a, b) {
          final c = a.review.effectiveRating.compareTo(b.review.effectiveRating);
          return c != 0 ? c : b.sortDate.compareTo(a.sortDate);
        });
    }
    return list;
  }

  int get _activeFilterCount {
    var n = 0;
    if (_careFilter != null) n++;
    if (_bodyFilter != null) n++;
    if (_genderFilter != null) n++;
    if (_ageFilter != null) n++;
    if (_sort != _ReviewSort.recent) n++;
    return n;
  }

  Future<void> _requestReview(Customer customer) async {
    setState(() => _requestedIds.add(customer.id));
    await requestCustomerReviewWithQr(
      context,
      store: widget.store,
      customer: customer,
    );
    if (mounted) setState(() {});
  }

  Future<void> _shareCustomerLink(Customer customer) async {
    final chart = widget.store.latestChart(customer.id);
    final token = chart?.feedbackToken;
    if (chart == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰 링크가 아직 없어요. 방문 확인 후 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SoriShare.shareReviewLink(
      url: SoriStore.buildCustomerReviewUrl(token),
      customerName: customer.name,
      careName: chart.careName,
    );
  }

  Future<void> _copyNaverReview(DirectorReviewInboxItem item) async {
    final text = item.review.displayText.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    try {
      if (item.review.effectiveNaverStatus == NaverPublishStatus.none) {
        await widget.store.setNaverPublishStatus(
          reviewId: item.review.id,
          status: NaverPublishStatus.copied,
        );
      }
      await widget.store.markNaverRegistered(
        chartId: item.review.chartId,
        composedText: text,
      );
    } catch (_) {
      // 복사 자체는 성공 — 트래킹 실패는 안내만
    }
    if (!mounted) return;
    final shop = widget.store.shop;
    final link = shop.naverReviewDeepLink.trim().isNotEmpty
        ? shop.naverReviewDeepLink.trim()
        : shop.naverPlaceUrl.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          link.isEmpty
              ? '후기 문구를 복사했어요. 네이버 플레이스에 붙여넣기 하세요.'
              : '후기 문구를 복사했어요. 네이버 플레이스로 이동합니다.',
        ),
        behavior: SnackBarBehavior.floating,
        action: link.isEmpty
            ? null
            : SnackBarAction(
                label: '열기',
                onPressed: () => launchUrl(
                  Uri.parse(link),
                  mode: LaunchMode.externalApplication,
                ),
              ),
      ),
    );
    if (link.isNotEmpty) {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitReply(DirectorReviewInboxItem item) async {
    final body = _replyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답글 내용을 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _savingReply = true);
    try {
      await widget.store.saveDirectorReviewReply(
        reviewId: item.review.id,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _replyingReviewId = null;
        _replyController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답글이 저장되었습니다.'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('답글 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingReply = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '리뷰 관리',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    widget.store.openCommunityDeviceReviewComposer();
                    context.go(AppPaths.appCommunity);
                  },
                  icon: const Icon(Icons.devices_other_outlined, size: 18),
                  label: const Text(
                    '기기후기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      showShopReviewQrModal(context, store: widget.store),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: const Text(
                    'QR',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                  ),
                ),
              ],
            ),
          ),
          SoriYoutubeTabBar(
            controller: _tabs,
            labels: [
              '인박스 ${widget.store.directorReviewInboxItems(lane: ReviewOpsLane.all).length}',
              '후기 요청',
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildInboxTab(),
                _buildRequestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNaver(DirectorReviewInboxItem item, bool value) async {
    if (_togglingNaver) return;
    setState(() => _togglingNaver = true);
    try {
      if (value) {
        await widget.store.setNaverPublishStatus(
          reviewId: item.review.id,
          status: NaverPublishStatus.registered,
        );
      } else {
        await widget.store.setNaverPublishStatus(
          reviewId: item.review.id,
          status: NaverPublishStatus.none,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '네이버 등록으로 표시했어요.' : '네이버 등록 표시를 해제했어요.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: value ? SoriTokens.primary : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('네이버 상태 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _togglingNaver = false);
    }
  }

  Future<void> _confirmNaver(DirectorReviewInboxItem item) async {
    await widget.store.setNaverPublishStatus(
      reviewId: item.review.id,
      status: NaverPublishStatus.confirmed,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('네이버 게시 확인으로 표시했어요.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
  }

  Future<void> _promotePortfolio(DirectorReviewInboxItem item) async {
    final err = await widget.store.promoteReviewToPortfolio(item.review.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'BA 포트폴리오에 공개했어요.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: err == null ? SoriTokens.primary : null,
      ),
    );
  }

  Future<void> _draftAiReply(DirectorReviewInboxItem item) async {
    try {
      final ai = await widget.store.requestAiReplyFeedback(item.review.id);
      if (!mounted) return;
      setState(() {
        _replyingReviewId = item.review.id;
        _replyController.text = (ai.replyText ?? '').trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 답글 초안을 넣었어요. 확인하고 저장하세요.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI 초안 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendAlimtalkRemind(Customer customer) async {
    final chart = widget.store.latestChart(customer.id);
    final result = await widget.store.sendReviewRequestAlimtalk(
      customerId: customer.id,
      chartId: chart?.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? '후기 요청 알림톡을 보냈어요.'
              : (result.message ?? '알림톡 발송 실패'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.ok ? SoriTokens.primary : null,
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    await showSoriModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            void apply(VoidCallback fn) {
              setModal(fn);
              setState(fn);
            }

            final cares = _careOptions;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + kSoriFloatingNavClearance,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: SoriTokens.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '필터',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => apply(() {
                              _sort = _ReviewSort.recent;
                              _careFilter = null;
                              _bodyFilter = null;
                              _genderFilter = null;
                              _ageFilter = null;
                            }),
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _filterRow(
                        label: '정렬',
                        children: [
                          _chip(
                            '최근순',
                            selected: _sort == _ReviewSort.recent,
                            onTap: () =>
                                apply(() => _sort = _ReviewSort.recent),
                          ),
                          _chip(
                            '별점높은순',
                            selected: _sort == _ReviewSort.ratingHigh,
                            onTap: () =>
                                apply(() => _sort = _ReviewSort.ratingHigh),
                          ),
                          _chip(
                            '별점낮은순',
                            selected: _sort == _ReviewSort.ratingLow,
                            onTap: () =>
                                apply(() => _sort = _ReviewSort.ratingLow),
                          ),
                        ],
                      ),
                      _filterRow(
                        label: '관리명',
                        children: [
                          _chip(
                            '전체',
                            selected: _careFilter == null,
                            onTap: () => apply(() => _careFilter = null),
                          ),
                          ...cares.map(
                            (c) => _chip(
                              c,
                              selected: _careFilter == c,
                              onTap: () => apply(() => _careFilter = c),
                            ),
                          ),
                        ],
                      ),
                      _filterRow(
                        label: '부위',
                        children: [
                          _chip(
                            '전체',
                            selected: _bodyFilter == null,
                            onTap: () => apply(() => _bodyFilter = null),
                          ),
                          ..._bodyParts.map(
                            (p) => _chip(
                              p,
                              selected: _bodyFilter == p,
                              onTap: () => apply(() => _bodyFilter = p),
                            ),
                          ),
                        ],
                      ),
                      _filterRow(
                        label: '성별·나이',
                        children: [
                          _chip(
                            '전체',
                            selected:
                                _genderFilter == null && _ageFilter == null,
                            onTap: () => apply(() {
                              _genderFilter = null;
                              _ageFilter = null;
                            }),
                          ),
                          _chip(
                            '여성',
                            selected: _genderFilter == CustomerGender.female,
                            onTap: () => apply(
                              () => _genderFilter =
                                  _genderFilter == CustomerGender.female
                                      ? null
                                      : CustomerGender.female,
                            ),
                          ),
                          _chip(
                            '남성',
                            selected: _genderFilter == CustomerGender.male,
                            onTap: () => apply(
                              () => _genderFilter =
                                  _genderFilter == CustomerGender.male
                                      ? null
                                      : CustomerGender.male,
                            ),
                          ),
                          ..._ageBands.map(
                            (a) => _chip(
                              a,
                              selected: _ageFilter == a,
                              onTap: () => apply(
                                () => _ageFilter = _ageFilter == a ? null : a,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          '적용',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInboxTab() {
    final items = _filteredInbox;
    final kpi = widget.store.reviewOpsKpi();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: '미답글',
                  value: '${kpi.unreplied}',
                  accent: kpi.unreplied > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiTile(
                  label: '오늘신규',
                  value: '${kpi.new24h}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiTile(
                  label: '요청중',
                  value: '${kpi.requestedPending}',
                  accent: kpi.remindDue > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiTile(
                  label: '7일',
                  value: '${kpi.weekCount}',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _WeeklySummaryCard(
            kpi: kpi,
            careStats: widget.store.careRatingStats(),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _laneChip(
                        '미답글',
                        ReviewOpsLane.unreplied,
                        count: kpi.unreplied,
                      ),
                      _laneChip(
                        '신규',
                        ReviewOpsLane.new24h,
                        count: kpi.new24h,
                      ),
                      _laneChip(
                        '전체',
                        ReviewOpsLane.all,
                        count: kpi.inboxTotal,
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openFilterSheet,
                icon: Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  backgroundColor: SoriTokens.systemRed,
                  label: Text(
                    '$_activeFilterCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 20),
                ),
                label: const Text(
                  '필터',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: SoriTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: SoriTokens.textPrimary),
            decoration: InputDecoration(
              hintText: '이름 · 후기 · 관리명 검색',
              hintStyle: const TextStyle(color: SoriTokens.textSecondary),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: SoriTokens.textSecondary,
              ),
              filled: true,
              fillColor: SoriTokens.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: SoriTokens.outlinePurple,
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: SoriTokens.outlinePurple,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: SoriTokens.primary,
                  width: 1.2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyLane()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildReviewCard(items[index]),
                ),
        ),
      ],
    );
  }

  Widget _laneChip(String label, ReviewOpsLane lane, {required int count}) {
    final selected = _lane == lane;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? SoriTokens.onPrimary
                : SoriTokens.tabUnselected,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _lane = lane),
        selectedColor: SoriTokens.primary,
        backgroundColor: SoriTokens.chipIdleBg,
        side: BorderSide.none,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildEmptyLane() {
    final String title;
    final String body;
    switch (_lane) {
      case ReviewOpsLane.unreplied:
        title = '답글 달 후기가 없어요';
        body = '잘하고 있어요. 새 후기가 오면 여기에 모입니다.';
      case ReviewOpsLane.new24h:
        title = '최근 24시간 새 후기가 없어요';
        body = '후기 요청으로 수집을 늘려 보세요.';
      case ReviewOpsLane.all:
        title = '표시할 후기가 없습니다';
        body = '고객이 리뷰를 작성하면 여기에 모입니다.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (_lane != ReviewOpsLane.all) ...[
              const SizedBox(height: 16),
              if (_lane == ReviewOpsLane.unreplied)
                TextButton(
                  onPressed: () => setState(() => _lane = ReviewOpsLane.new24h),
                  child: const Text('신규 보기'),
                ),
              FilledButton(
                onPressed: () => _tabs.animateTo(1),
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                ),
                child: const Text('후기 요청하기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterRow({required String label, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? SoriTokens.onPrimary
                : SoriTokens.tabUnselected,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: SoriTokens.primary,
        backgroundColor: SoriTokens.chipIdleBg,
        checkmarkColor: SoriTokens.onPrimary,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildReviewCard(DirectorReviewInboxItem item) {
    final review = item.review;
    final replying = _replyingReviewId == review.id;
    final rating = review.effectiveRating;

    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: SoriTokens.primarySoft,
                child: Text(
                  item.displayName.characters.first,
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
                      item.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(item.sortDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: SoriTokens.textSecondary,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(item.careName, filled: true),
              ...item.bodyTags.take(3).map(_tag),
              if (item.gender != null) _tag(item.gender!.label),
              if (item.ageBand != null) _tag(item.ageBand!),
              if (review.naverRegistered)
                _tag('네이버 등록', filled: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.displayText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: SoriTokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (review.hasDirectorReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '원장 답글',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.directorReply!,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          if (replying) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _replyController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '고객 후기에 답글을 남겨 주세요',
                filled: true,
                fillColor: SoriTokens.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _savingReply
                        ? null
                        : () => setState(() {
                              _replyingReviewId = null;
                              _replyController.clear();
                            }),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _savingReply ? null : () => _submitReply(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    child: Text(_savingReply ? '저장 중…' : '답글 저장'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  review.hasDirectorReply
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: review.hasDirectorReply
                      ? SoriTokens.primary
                      : SoriTokens.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  review.hasDirectorReply ? '답글 완료' : '답글 대기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: review.hasDirectorReply
                        ? SoriTokens.primary
                        : SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  review.naverRegistered
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: review.naverRegistered
                      ? SoriTokens.primary
                      : SoriTokens.textTertiary,
                ),
                const SizedBox(width: 6),
                const Text(
                  '네이버',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  review.effectiveNaverStatus.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: review.effectiveNaverStatus == NaverPublishStatus.none
                        ? SoriTokens.textTertiary
                        : SoriTokens.primary,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: review.effectiveNaverStatus ==
                          NaverPublishStatus.registered ||
                      review.effectiveNaverStatus ==
                          NaverPublishStatus.confirmed,
                  activeThumbColor: SoriTokens.primary,
                  onChanged: _togglingNaver
                      ? null
                      : (v) => _toggleNaver(item, v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _replyingReviewId = review.id;
                        _replyController.text = review.directorReply ?? '';
                      });
                    },
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: Text(
                      review.hasDirectorReply ? '답글 수정' : '답글 달기',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      side: const BorderSide(color: SoriTokens.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _copyNaverReview(item),
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: const Text(
                      '네이버 복사',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI 초안'),
                  onPressed: () => _draftAiReply(item),
                ),
                ActionChip(
                  avatar: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('포트폴리오'),
                  onPressed: () => _promotePortfolio(item),
                ),
                if (review.effectiveNaverStatus != NaverPublishStatus.confirmed)
                  ActionChip(
                    avatar: const Icon(Icons.verified_outlined, size: 16),
                    label: Text(
                      '네이버 ${review.effectiveNaverStatus.label}→확인',
                    ),
                    onPressed: () => _confirmNaver(item),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.verified, size: 16, color: SoriTokens.primary),
                    label: Text('네이버 확인됨'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? SoriTokens.primarySoft : SoriTokens.border,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? SoriTokens.primary : SoriTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRequestTab() {
    final list = _todayDone;
    final reviewedIds = <String>{
      for (final r in widget.store.reviews)
        if (r.isInboxVisible) r.customerId,
    };

    List<Customer> filtered;
    switch (_requestSegment) {
      case _RequestSegment.pending:
        filtered = list
            .where(
              (c) =>
                  !widget.store.isReviewRequested(c.id) &&
                  !reviewedIds.contains(c.id),
            )
            .toList();
      case _RequestSegment.sent:
        filtered = list
            .where(
              (c) =>
                  widget.store.isReviewRequested(c.id) &&
                  !reviewedIds.contains(c.id),
            )
            .toList();
      case _RequestSegment.converted:
        filtered = list.where((c) => reviewedIds.contains(c.id)).toList();
    }

    final due = widget.store.reviewRequestEvents
        .where((e) => e.isDueForRemind)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (due.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SoriTokens.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: SoriTokens.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '리마인드 대상 ${due.length}명 — 방문 후 24시간이 지났어요',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        for (final e in due) {
                          await widget.store.acknowledgeReviewRemind(e.id);
                        }
                      },
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            '오늘 케어 완료 고객에게 후기를 요청해 보세요',
            style: TextStyle(
              fontSize: 13,
              color: SoriTokens.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _requestSegChip(
                '미요청',
                _RequestSegment.pending,
                list
                    .where(
                      (c) =>
                          !widget.store.isReviewRequested(c.id) &&
                          !reviewedIds.contains(c.id),
                    )
                    .length,
              ),
              _requestSegChip(
                '요청됨',
                _RequestSegment.sent,
                list
                    .where(
                      (c) =>
                          widget.store.isReviewRequested(c.id) &&
                          !reviewedIds.contains(c.id),
                    )
                    .length,
              ),
              _requestSegChip(
                '작성완료',
                _RequestSegment.converted,
                list.where((c) => reviewedIds.contains(c.id)).length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('오늘 케어 완료 고객이 없어요'))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        switch (_requestSegment) {
                          _RequestSegment.pending => '미요청 고객이 없어요',
                          _RequestSegment.sent => '대기 중인 요청이 없어요',
                          _RequestSegment.converted => '작성 완료된 후기가 없어요',
                        },
                        style: const TextStyle(color: SoriTokens.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final chart = widget.store.latestChart(c.id);
                        final event =
                            widget.store.latestReviewRequestFor(c.id);
                        final sent = widget.store.isReviewRequested(c.id);
                        final converted = reviewedIds.contains(c.id);
                        final hasLink = chart?.feedbackToken != null;
                        final dueRemind = event?.isDueForRemind ?? false;

                        return SoriCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          chart == null
                                              ? c.treatmentType
                                              : '${chart.visitNumber}회차 · ${chart.careName.isNotEmpty ? chart.careName : c.treatmentType}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: SoriTokens.textSecondary,
                                          ),
                                        ),
                                        if (event != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${event.channel.label} · ${event.status.label}'
                                            '${event.sentAt != null ? ' · ${_formatDate(event.sentAt!)}' : ''}'
                                            '${dueRemind ? ' · 리마인드' : ''}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: dueRemind
                                                  ? SoriTokens.primary
                                                  : SoriTokens.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!converted)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        FilledButton(
                                          onPressed: sent && !dueRemind
                                              ? null
                                              : () => _requestReview(c),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: SoriTokens.primary,
                                            disabledBackgroundColor: SoriTokens
                                                .primary
                                                .withValues(alpha: 0.35),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                          ),
                                          child: Text(
                                            dueRemind
                                                ? '다시 요청'
                                                : (sent
                                                    ? '요청 완료'
                                                    : '후기 요청하기'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _sendAlimtalkRemind(c),
                                          child: const Text(
                                            '알림톡',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    const Text(
                                      '작성완료',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: SoriTokens.primary,
                                      ),
                                    ),
                                ],
                              ),
                              if (hasLink && !converted) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _shareCustomerLink(c),
                                        icon: const Icon(
                                          Icons.ios_share_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          '링크 공유하기',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: SoriTokens.primary,
                                          side: const BorderSide(
                                            color: SoriTokens.primary,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () => showCustomerLinkPopup(
                                        context,
                                        chart: chart!,
                                        store: widget.store,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: SoriTokens.primary,
                                        side: const BorderSide(
                                          color: SoriTokens.primary,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _requestSegChip(String label, _RequestSegment seg, int count) {
    final selected = _requestSegment == seg;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? SoriTokens.onPrimary
                : SoriTokens.tabUnselected,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _requestSegment = seg),
        selectedColor: SoriTokens.primary,
        backgroundColor: SoriTokens.chipIdleBg,
        side: BorderSide.none,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? SoriTokens.primary.withValues(alpha: 0.45)
              : SoriTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: accent ? SoriTokens.primary : SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.kpi,
    required this.careStats,
  });

  final ReviewOpsKpi kpi;
  final List<CareRatingStat> careStats;

  @override
  Widget build(BuildContext context) {
    final avg = kpi.avgRating <= 0 ? '-' : kpi.avgRating.toStringAsFixed(1);
    final reply = (kpi.replyRate * 100).round();
    final naver = (kpi.naverRate * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이번 주 요약',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '후기 ${kpi.weekCount} · 평균 ★$avg · 답글율 $reply% · 네이버 $naver%',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
                height: 1.35,
              ),
            ),
            if (careStats.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                '케어별 별점',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...careStats.map((s) {
                final ratio = (s.avgRating / 5).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          s.careName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: SoriTokens.border,
                            color: SoriTokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '★${s.avgRating.toStringAsFixed(1)} (${s.count})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

