import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/case_archive_tile.dart';
import '../widgets/case_feed_viewport.dart';
import '../widgets/case_timeline_modal.dart';

enum _ArchiveView { favorites, myCases }

/// 관리 케이스 아카이브 — 즐겨찾기 / 내 작성 차트.
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
  _ArchiveView _view = _ArchiveView.myCases;

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
    for (final chart in widget.store.charts) {
      for (final tag in chart.careTags) {
        final key = tag.replaceFirst('#', '').trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    for (final item in widget.store.communityHotCases) {
      for (final tag in item.chart.careTags) {
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

  bool _matchesFilter(CustomerChart chart, Customer? customer) {
    final tokens = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final hay = [
      chart.careName,
      chart.deviceInfo ?? '',
      ...chart.careTags,
      if (customer != null) customer.name,
    ].join(' ').toLowerCase();
    if (_activeTag != null &&
        !hay.contains(_activeTag!.toLowerCase())) {
      return false;
    }
    if (tokens.isNotEmpty && !tokens.every(hay.contains)) return false;
    return true;
  }

  List<({CustomerChart chart, Customer? customer, bool mine})> get _items {
    final store = widget.store;
    final myShopId = store.shop.id;
    final out = <({CustomerChart chart, Customer? customer, bool mine})>[];

    if (_view == _ArchiveView.favorites) {
      final ids = {..._liked, ..._bookmarked};
      for (final id in ids) {
        final mine = store.charts.where((c) => c.id == id);
        if (mine.isNotEmpty) {
          final chart = mine.first;
          if (!_matchesFilter(chart, store.findCustomer(chart.customerId))) {
            continue;
          }
          out.add((
            chart: chart,
            customer: store.findCustomer(chart.customerId),
            mine: chart.shopId == myShopId || chart.shopId.isEmpty,
          ));
          continue;
        }
        CommunityCaseItem? hit;
        for (final item in store.communityHotCases) {
          if (item.chart.id == id) {
            hit = item;
            break;
          }
        }
        if (hit != null && _matchesFilter(hit.chart, null)) {
          out.add((chart: hit.chart, customer: null, mine: false));
        }
      }
    } else {
      for (final chart in store.charts) {
        if (chart.shopId.isNotEmpty &&
            myShopId.isNotEmpty &&
            chart.shopId != myShopId) {
          continue;
        }
        final b = chart.beforeImageUrl?.trim() ?? '';
        final a = chart.afterImageUrl?.trim() ?? '';
        if (b.isEmpty && a.isEmpty) continue;
        final customer = store.findCustomer(chart.customerId);
        if (!_matchesFilter(chart, customer)) continue;
        out.add((chart: chart, customer: customer, mine: true));
      }
    }

    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  void _onShareToggle(CustomerChart chart, bool value) {
    final ok = widget.store.setManagementCaseShared(chart.id, value);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객의 정보 활용 동의서 서명이 완료된 차트만 공유할 수 있습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final items = _items;
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
                child: Row(
                  children: [
                    Expanded(
                      child: _ArchiveTabCard(
                        selected: _view == _ArchiveView.favorites,
                        icon: Icons.star_rounded,
                        title: '즐겨찾기',
                        subtitle: '${_liked.length + _bookmarked.length}건',
                        onTap: () =>
                            setState(() => _view = _ArchiveView.favorites),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ArchiveTabCard(
                        selected: _view == _ArchiveView.myCases,
                        icon: Icons.folder_rounded,
                        title: 'My 관리 케이스',
                        subtitle: '${widget.store.charts.length}건',
                        onTap: () =>
                            setState(() => _view = _ArchiveView.myCases),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '케어명, 태그, 기기로 검색',
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
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final tag = _popularTags[i];
                    final selected = _activeTag == tag;
                    final rising = _risingTags.contains(tag);
                    return ActionChip(
                      avatar: rising
                          ? const Text('🔥', style: TextStyle(fontSize: 12))
                          : null,
                      label: Text('#$tag'),
                      onPressed: () => setState(() {
                        _activeTag = selected ? null : tag;
                      }),
                      backgroundColor: selected
                          ? SoriTokens.primarySoft
                          : Colors.white,
                      side: BorderSide(
                        color: selected
                            ? SoriTokens.primary.withValues(alpha: 0.4)
                            : const Color(0xFFE5E7EB),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected
                            ? SoriTokens.primary
                            : Colors.grey.shade800,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          _view == _ArchiveView.favorites
                              ? '즐겨찾기한 케이스가 없어요'
                              : '아직 작성한 관리 케이스가 없어요',
                          style: const TextStyle(
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
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final row = items[i];
                          final id = row.chart.id;
                          return CaseArchiveTile(
                            chart: row.chart,
                            customer: row.customer,
                            liked: _liked.contains(id),
                            likeCount: _likeCounts[id] ??
                                (3 + id.hashCode.abs() % 40),
                            bookmarked: _bookmarked.contains(id),
                            showShareSwitch: _view == _ArchiveView.myCases,
                            onLike: () => _toggleLike(id),
                            onBookmark: () => _toggleBookmark(id),
                            onShareChanged: _view == _ArchiveView.myCases
                                ? (v) => _onShareToggle(row.chart, v)
                                : null,
                            onTap: () {
                              CaseTimelineModal.show(
                                context,
                                store: widget.store,
                                chartId: row.chart.id,
                                careLabel: row.chart.careName,
                              );
                            },
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

class _ArchiveTabCard extends StatelessWidget {
  const _ArchiveTabCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFFBFBFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? SoriTokens.primary.withValues(alpha: 0.45)
                  : const Color(0xFFE8E4F8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? SoriTokens.primary : const Color(0xFFB7791F),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
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
