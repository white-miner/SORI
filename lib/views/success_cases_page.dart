import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/community_post.dart';
import '../models/shop.dart';
import '../pages/case_detail_page.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/case_archive_tile.dart';
import '../widgets/case_feed_viewport.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/community_motivation.dart';
import '../widgets/fan_sponsor_credits.dart';
import '../widgets/official_badge.dart';
import '../widgets/sori_network_image.dart';

/// 관리 케이스 탐색 피드 — case_share + 공개 차트 단일 레일.
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
      widget.store.refreshCommunityPosts();
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

  Set<String> get _linkedChartIds {
    return {
      for (final p in widget.store.communityPosts)
        if (p.postType == CommunityPostType.caseShare &&
            (p.sourceChartId?.trim().isNotEmpty ?? false))
          p.sourceChartId!.trim(),
    };
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
    for (final p in widget.store.communityPosts) {
      if (p.postType != CommunityPostType.caseShare) continue;
      for (final tag in p.styleTags) {
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

  bool _matchesChart(CommunityCaseItem item) {
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

  bool _matchesPost(CommunityPost post) {
    final tokens = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final hay = [
      post.title,
      post.body,
      post.shopName,
      ...post.styleTags,
    ].join(' ').toLowerCase();
    if (_activeTag != null && !hay.contains(_activeTag!.toLowerCase())) {
      return false;
    }
    if (tokens.isNotEmpty && !tokens.every(hay.contains)) return false;
    return true;
  }

  List<_CaseRailEntry> get _railEntries {
    final linked = _linkedChartIds;
    final entries = <_CaseRailEntry>[];

    final posts = widget.store.communityPosts
        .where((p) => p.postType == CommunityPostType.caseShare)
        .where(_matchesPost)
        .toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    for (final p in posts) {
      entries.add(_CaseRailEntry.post(p));
    }

    var items = List<CommunityCaseItem>.from(widget.store.communityHotCases);
    if (items.isEmpty) {
      items = widget.store.favoriteShopCaseItems();
    }
    items = items.where((item) {
      if (!item.chart.caseShared) return false;
      if (linked.contains(item.chart.id)) return false; // already on case_share
      final b = item.chart.beforeImageUrl?.trim() ?? '';
      final a = item.chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) return false;
      return _matchesChart(item);
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
    for (final item in items) {
      entries.add(_CaseRailEntry.chart(item));
    }
    return entries;
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
        onOpenCommunitySeminar: () {
          widget.store.pendingCommunitySegment = 5;
          final shell = StatefulNavigationShell.maybeOf(context);
          shell?.goBranch(3);
        },
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
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
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
                  color: SoriTokens.border,
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
              ShopNameWithOfficialBadge(
                name: shop.name.trim().isEmpty ? 'SORI' : shop.name,
                isOfficial: shop.displayIsOfficial,
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
              const SizedBox(height: 16),
              ShopTopSupportersSection(
                entries: ShopTopSupportersSection.fromBoosts(
                  widget.store.activeBoostPlacements,
                  shopId: shop.id,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _railEntries;
    final loading = widget.store.communityHotCasesLoading && entries.isEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: SoriTokens.background,
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
                  style: const TextStyle(color: SoriTokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: '케어명, 태그, 샵, 기기로 탐색',
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
                      color: selected ? SoriTokens.primarySoft : SoriTokens.surface,
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
                                  ? SoriTokens.primary.withValues(alpha: 0.45)
                                  : SoriTokens.outlinePurple,
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
                                      : SoriTokens.textSecondary,
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
                    : entries.isEmpty
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
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final entry = entries[i];
                              if (entry.post != null) {
                                return _CaseShareRailCard(
                                  store: widget.store,
                                  post: entry.post!,
                                );
                              }
                              final item = entry.chartItem!;
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

class _CaseRailEntry {
  const _CaseRailEntry._({this.post, this.chartItem});

  factory _CaseRailEntry.post(CommunityPost post) =>
      _CaseRailEntry._(post: post);

  factory _CaseRailEntry.chart(CommunityCaseItem item) =>
      _CaseRailEntry._(chartItem: item);

  final CommunityPost? post;
  final CommunityCaseItem? chartItem;
}

class _CaseShareRailCard extends StatelessWidget {
  const _CaseShareRailCard({required this.store, required this.post});

  final SoriStore store;
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    final title = post.title.trim();
    final body = post.body.trim();

    return CommunityPostShell(
      store: store,
      post: post,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (img != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: SoriNetworkImage(url: img, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFFD4D4D8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CommunityCommentsSection(
            store: store,
            postId: post.id,
          ),
        ],
      ),
    );
  }
}
