import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/shop.dart';
import '../pages/case_detail_page.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/case_archive_tile.dart';
import '../widgets/case_feed_viewport.dart';

/// 관리 케이스 탐색 피드 — 전국 원장님 공개 차트.
class SuccessCasesPage extends StatefulWidget {
  const SuccessCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<SuccessCasesPage> createState() => _SuccessCasesPageState();
}

class _SuccessCasesPageState extends State<SuccessCasesPage> {
  final _searchController = TextEditingController();
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _bookmarked = <String>{};
  String _query = '';
  String? _activeTag;

  static const _risingTags = {'윤곽', '스페셜웨딩'};

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshCommunityHotCases();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _searchController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<String> get _popularTags {
    final counts = <String, int>{};
    for (final item in widget.store.communityHotCases) {
      for (final tag in item.displayCareTags) {
        final key = tag.replaceFirst('#', '').trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    final seeded = ['윤곽', '스페셜웨딩', '리프팅', '재생', '수분', '테라노바'];
    final out = <String>[];
    for (final s in seeded) {
      if (!out.contains(s)) out.add(s);
    }
    for (final k in keys) {
      if (!out.contains(k)) out.add(k);
      if (out.length >= 10) break;
    }
    return out;
  }

  bool _matches(CommunityCaseItem item) {
    final tokens = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final hay = [
      item.chart.careName,
      item.chart.deviceInfo ?? '',
      item.shop.name,
      ...item.displayCareTags,
    ].join(' ').toLowerCase();
    if (_activeTag != null && !hay.contains(_activeTag!.toLowerCase())) {
      return false;
    }
    if (tokens.isNotEmpty && !tokens.every(hay.contains)) return false;
    return true;
  }

  List<CommunityCaseItem> get _exploreItems {
    var items = List<CommunityCaseItem>.from(widget.store.communityHotCases);
    if (items.isEmpty) {
      items = widget.store.favoriteShopCaseItems();
    }
    items = items.where((item) {
      if (!item.chart.caseShared) return false;
      final b = item.chart.beforeImageUrl?.trim() ?? '';
      final a = item.chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) return false;
      return _matches(item);
    }).toList();
    items.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return items;
  }

  void _toggleLike(String id) {
    setState(() {
      if (_liked.remove(id)) {
        _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 9999);
      } else {
        _liked.add(id);
        _likeCounts[id] = (_likeCounts[id] ?? 0) + 1;
      }
    });
  }

  void _toggleBookmark(String id) {
    setState(() {
      if (!_bookmarked.remove(id)) _bookmarked.add(id);
    });
  }

  void _openCaseDetail(CommunityCaseItem item) {
    final id = item.chart.id;
    CaseDetailPage.push(
      context,
      page: CaseDetailPage(
        item: item,
        review: item.review ?? widget.store.reviewForChart(item.chart.id),
        currentUserId: widget.store.session?.id,
        liked: _liked.contains(id),
        likeCount: _likeCounts[id] ?? (3 + id.hashCode.abs() % 40),
        commentCount: 0,
        bookmarked: _bookmarked.contains(id),
        onLike: () => _toggleLike(id),
        onBookmark: () => _toggleBookmark(id),
        onShopProfile: () => _openShopProfile(item.shop),
        onBookingCta: () => _openNaverBooking(item.shop),
        onSeminarRequest: () => _requestSeminar(item),
      ),
    );
  }

  Future<void> _requestSeminar(CommunityCaseItem item) async {
    final store = widget.store;
    final session = store.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 세미나 요청을 보낼 수 있어요.')),
      );
      return;
    }
    final myShopId = store.shop.id.trim();
    final userId = session.id.trim();
    if (myShopId.isEmpty && userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청자 정보가 없어 세미나 요청을 보낼 수 없습니다.')),
      );
      return;
    }
    final ok = await store.requestSeminar(
      caseId: item.chart.id,
      requestorShopId: myShopId.isEmpty ? null : myShopId,
      requestorUserId: userId.isEmpty ? null : userId,
      caseOwnerShopId: item.shop.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '해당 케이스의 세미나 개설을 요청했습니다. 원장님이 클래스를 오픈하면 알림을 보내드립니다.'
              : '요청에 실패했습니다. 다시 시도해 주세요.',
        ),
        backgroundColor: ok ? SoriTokens.primary : Colors.redAccent,
      ),
    );
  }

  Future<void> _openNaverBooking(Shop shop) async {
    final url = shop.naverBookingOrPlaceUrl;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openShopProfile(Shop shop) async {
    if (!mounted) return;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final bio = shop.bio.trim();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 36,
                backgroundColor: SoriTokens.primarySoft,
                backgroundImage:
                    avatar.isNotEmpty && !avatar.startsWith('data:')
                        ? NetworkImage(avatar)
                        : null,
                child: avatar.isEmpty || avatar.startsWith('data:')
                    ? const Icon(Icons.storefront, size: 32)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                shop.name.trim().isEmpty ? 'SORI' : shop.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _exploreItems;
    final loading = widget.store.communityHotCasesLoading && items.isEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        bottom: false,
        child: CaseFeedViewport(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '케어명, 태그, 샵, 기기로 탐색',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tag = _popularTags[i];
                    final selected = _activeTag == tag;
                    final rising = _risingTags.contains(tag);
                    return Material(
                      color: selected ? SoriTokens.primarySoft : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => setState(() {
                          _activeTag = selected ? null : tag;
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? SoriTokens.primary.withValues(alpha: 0.4)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (rising) ...[
                                const Text('🔥', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '#$tag',
                                softWrap: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: selected
                                      ? SoriTokens.primary
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SoriTokens.primary,
                        ),
                      )
                    : items.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 공개된 탐색 케이스가 없어요',
                              style: TextStyle(
                                color: SoriTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              100 + bottomInset,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final id = item.chart.id;
                              return CaseArchiveTile(
                                chart: item.chart,
                                customer: widget.store
                                    .findCustomer(item.chart.customerId),
                                feedAge: item.customerAge ?? item.chart.age,
                                feedGenderLabel: item.customerGenderLabel ??
                                    item.chart.gender,
                                liked: _liked.contains(id),
                                likeCount: _likeCounts[id] ??
                                    (3 + id.hashCode.abs() % 40),
                                bookmarked: _bookmarked.contains(id),
                                onLike: () => _toggleLike(id),
                                onBookmark: () => _toggleBookmark(id),
                                onTap: () => _openCaseDetail(item),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
