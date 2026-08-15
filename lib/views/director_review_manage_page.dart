import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/review_qr_modal.dart';
import '../widgets/sori_card.dart';
import 'customer_link_popup.dart';
import 'request_customer_review.dart';

enum _ReviewSort { recent, ratingHigh, ratingLow }

/// 원장용 리뷰 관리 — 다차원 인박스 + 답글 + 후기 요청.
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

  _ReviewSort _sort = _ReviewSort.recent;
  String? _careFilter;
  String? _bodyFilter;
  CustomerGender? _genderFilter;
  String? _ageFilter;
  String? _replyingReviewId;
  final _replyController = TextEditingController();
  bool _savingReply = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    widget.store.addListener(_onStore);
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
    var list = widget.store.directorReviewInboxItems();
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
        list.sort((a, b) => b.sortDate.compareTo(a.sortDate));
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
          TabBar(
            controller: _tabs,
            labelColor: SoriTokens.primary,
            unselectedLabelColor: SoriTokens.textSecondary,
            indicatorColor: SoriTokens.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(
                text:
                    '인박스 ${_filteredInbox.length}/${widget.store.directorReviewInboxItems().length}',
              ),
              const Tab(text: '후기 요청'),
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

  Widget _buildInboxTab() {
    final items = _filteredInbox;
    final cares = _careOptions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '이름 · 후기 · 관리명 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 156,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterRow(
                label: '정렬',
                children: [
                  _chip(
                    '최근순',
                    selected: _sort == _ReviewSort.recent,
                    onTap: () => setState(() => _sort = _ReviewSort.recent),
                  ),
                  _chip(
                    '별점높은순',
                    selected: _sort == _ReviewSort.ratingHigh,
                    onTap: () => setState(() => _sort = _ReviewSort.ratingHigh),
                  ),
                  _chip(
                    '별점낮은순',
                    selected: _sort == _ReviewSort.ratingLow,
                    onTap: () => setState(() => _sort = _ReviewSort.ratingLow),
                  ),
                ],
              ),
              _filterRow(
                label: '관리명',
                children: [
                  _chip(
                    '전체',
                    selected: _careFilter == null,
                    onTap: () => setState(() => _careFilter = null),
                  ),
                  ...cares.map(
                    (c) => _chip(
                      c,
                      selected: _careFilter == c,
                      onTap: () => setState(() => _careFilter = c),
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
                    onTap: () => setState(() => _bodyFilter = null),
                  ),
                  ..._bodyParts.map(
                    (p) => _chip(
                      p,
                      selected: _bodyFilter == p,
                      onTap: () => setState(() => _bodyFilter = p),
                    ),
                  ),
                ],
              ),
              _filterRow(
                label: '성별·나이',
                children: [
                  _chip(
                    '전체',
                    selected: _genderFilter == null && _ageFilter == null,
                    onTap: () => setState(() {
                      _genderFilter = null;
                      _ageFilter = null;
                    }),
                  ),
                  _chip(
                    '여성',
                    selected: _genderFilter == CustomerGender.female,
                    onTap: () => setState(
                      () => _genderFilter = _genderFilter == CustomerGender.female
                          ? null
                          : CustomerGender.female,
                    ),
                  ),
                  _chip(
                    '남성',
                    selected: _genderFilter == CustomerGender.male,
                    onTap: () => setState(
                      () => _genderFilter = _genderFilter == CustomerGender.male
                          ? null
                          : CustomerGender.male,
                    ),
                  ),
                  ..._ageBands.map(
                    (a) => _chip(
                      a,
                      selected: _ageFilter == a,
                      onTap: () => setState(
                        () => _ageFilter = _ageFilter == a ? null : a,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '표시할 후기가 없습니다.\n고객이 리뷰를 작성하면 여기에 모입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
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
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: SoriTokens.primarySoft,
        checkmarkColor: SoriTokens.primary,
        side: BorderSide(
          color: selected ? SoriTokens.primary : SoriTokens.border,
        ),
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
                    color: const Color(0xFFF5A524),
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
                      '네이버 후기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF03C75A),
                    ),
                  ),
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
        color: filled ? SoriTokens.primarySoft : const Color(0xFFF3F4F6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('오늘 케어 완료 고객이 없어요'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = list[index];
                    final chart = widget.store.latestChart(c.id);
                    final sent = _requestedIds.contains(c.id) ||
                        widget.store.isReviewRequested(c.id);
                    final hasLink = chart?.feedbackToken != null;

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
                                      chart == null
                                          ? c.treatmentType
                                          : '${chart.visitNumber}회차 · ${chart.careName.isNotEmpty ? chart.careName : c.treatmentType}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: SoriTokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed:
                                    sent ? null : () => _requestReview(c),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SoriTokens.primary,
                                  disabledBackgroundColor: SoriTokens.primary
                                      .withValues(alpha: 0.35),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  sent ? '요청 완료' : '후기 요청하기',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasLink) ...[
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
}
