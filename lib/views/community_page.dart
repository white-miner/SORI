import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../models/unified_feed_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../widgets/community_hotspot_image.dart';
import '../widgets/community_motivation.dart';
import '../widgets/post/post_view_data.dart';
import '../widgets/post/sori_post_mini.dart';
import '../widgets/sori_insta_picker.dart';
import '../widgets/unified_compose_sheet.dart';
import 'whisper_composer_sheet.dart';

/// 글로벌 Community 탭 — Unified Feed (필터 칩 + 로컬 필터링).
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late CommunityFeedFilter _filter;
  final _searchCtrl = TextEditingController();
  bool _recentRefreshing = false;

  SoriStore get store => widget.store;

  bool get _isDirector =>
      store.session?.activeMode == UserRole.director;

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filter = CommunityFeedFilter.fromLegacySegment(store.pendingCommunitySegment);
    store.pendingCommunitySegment = null;
    store.communityFeedFilter = _filter;
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(store.refreshUnifiedCommunityFeed());
      final again = store.pendingCommunitySegment;
      if (again != null) {
        store.pendingCommunitySegment = null;
        _setFilter(CommunityFeedFilter.fromLegacySegment(again));
      }
      if (store.pendingCommunityComposeDevice) {
        store.pendingCommunityComposeDevice = false;
        unawaited(_composeDeviceMarket(preferListing: false));
      }
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setFilter(CommunityFeedFilter next) {
    if (_filter == next) return;
    setState(() => _filter = next);
    store.communityFeedFilter = next;
  }

  void _onStore() {
    if (!mounted) return;
    final pending = store.pendingCommunitySegment;
    if (pending != null) {
      store.pendingCommunitySegment = null;
      _setFilter(CommunityFeedFilter.fromLegacySegment(pending));
    }
    if (store.pendingCommunityComposeDevice) {
      store.pendingCommunityComposeDevice = false;
      unawaited(_composeDeviceMarket(preferListing: false));
    }
    setState(() {});
  }

  Future<void> _composeWhisper() async {
    if (!_isDirector) {
      _showDirectorOnly();
      return;
    }
    final published = await showWhisperComposer(context, store: store);
    if (published) {
      await store.refreshUnifiedCommunityFeed(force: true);
    }
  }

  Future<void> _composeInterior() async {
    if (!_isDirector) {
      _showDirectorOnly();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _InteriorComposerSheet(store: store),
    );
  }

  Future<void> _composeDeviceMarket({bool preferListing = false}) async {
    if (!_isDirector) {
      _showDirectorOnly();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _DeviceMarketComposerSheet(
        store: store,
        initialSellUsed: preferListing,
      ),
    );
  }

  void _showDirectorOnly() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('원장 전용 기능입니다. 원장 모드로 전환해 주세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUnifiedCompose() {
    return showUnifiedComposeSheet(
      context,
      store: store,
      isDirector: _isDirector,
      onDirectorOnly: _showDirectorOnly,
      onComposeWhisper: _composeWhisper,
      onComposeInterior: _composeInterior,
      onComposeDeviceReview: () => _composeDeviceMarket(preferListing: false),
      onComposeMarketplace: () => _composeDeviceMarket(preferListing: true),
    );
  }

  Future<void> _refreshRecent() async {
    if (_recentRefreshing) return;
    setState(() => _recentRefreshing = true);
    await store.refreshUnifiedCommunityFeed(force: true);
    if (mounted) setState(() => _recentRefreshing = false);
  }

  Future<void> _onPullRefresh() async {
    await store.refreshUnifiedCommunityFeed(force: true);
  }

  List<UnifiedFeedItem> get _mainFeedItems {
    if (_isSearching) {
      return store.searchUnifiedCommunityFeed(_searchCtrl.text);
    }
    return store.filteredUnifiedCommunityFeed(_filter);
  }

  @override
  Widget build(BuildContext context) {
    final mainItems = _mainFeedItems;
    final recentItems = store.recentUnifiedFeedItems();
    final loading = store.unifiedFeedLoading && mainItems.isEmpty;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      floatingActionButton: _isDirector
          ? FloatingActionButton(
              onPressed: _openUnifiedCompose,
              backgroundColor: SoriTokens.primary,
              foregroundColor: SoriTokens.onPrimary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: ColoredBox(
        color: SoriTokens.background,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: SoriTokens.primary,
            onRefresh: _onPullRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: SoriTokens.textPrimary),
                      cursorColor: SoriTokens.primary,
                      decoration: InputDecoration(
                        hintText: '게시물·샵·기기를 검색하세요',
                        hintStyle:
                            const TextStyle(color: SoriTokens.textQuaternary),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: SoriTokens.textTertiary,
                        ),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                color: SoriTokens.textTertiary,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: SoriTokens.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text(
                      '커뮤니티',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                if (!_isSearching) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _refreshRecent,
                            child: const Text(
                              '최근 게시물',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed:
                                _recentRefreshing ? null : _refreshRecent,
                            icon: _recentRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SoriTokens.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                    color: SoriTokens.textSecondary,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: SoriPostMini.horizontalStripHeight,
                      child: recentItems.isEmpty
                          ? const Center(
                              child: Text(
                                '최근 게시물이 없어요',
                                style: TextStyle(
                                  color: SoriTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              itemCount: recentItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final item = recentItems[index];
                                return SoriPostMini(
                                  key: ValueKey('recent_${item.stableKey}'),
                                  data: PostViewData.fromUnifiedFeedItem(item),
                                  store: store,
                                  horizontal: true,
                                );
                              },
                            ),
                    ),
                  ),
                ],
                if (!_isDirector) const SliverToBoxAdapter(child: _CommunityViewerBanner()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CommunityFilterChipsDelegate(
                    filter: _filter,
                    onSelected: _setFilter,
                  ),
                ),
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (mainItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _CommunityEmptyState(
                      filter: _filter,
                      isSearching: _isSearching,
                      isDirector: _isDirector,
                      onComposeWhisper: _composeWhisper,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = mainItems[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoriPostMini(
                              key: ValueKey('feed_${item.stableKey}'),
                              data: PostViewData.fromUnifiedFeedItem(item),
                              store: store,
                            ),
                          );
                        },
                        childCount: mainItems.length,
                      ),
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

class _CommunityViewerBanner extends StatelessWidget {
  const _CommunityViewerBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1228),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SoriTokens.primary.withValues(alpha: 0.35),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: SoriTokens.textTertiary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '원장 전용 업계 광장 · 읽기 전용으로 둘러볼 수 있어요',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE4E4E7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityFilterChipsDelegate extends SliverPersistentHeaderDelegate {
  _CommunityFilterChipsDelegate({
    required this.filter,
    required this.onSelected,
  });

  final CommunityFeedFilter filter;
  final ValueChanged<CommunityFeedFilter> onSelected;

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
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          itemCount: CommunityFeedFilter.exploreFilters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final f = CommunityFeedFilter.exploreFilters[index];
            final selected = filter == f;
            return FilterChip(
              label: Text(f.label),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected
                    ? SoriTokens.onPrimary
                    : SoriTokens.textSecondary,
              ),
              selectedColor: SoriTokens.primary,
              backgroundColor: SoriTokens.surface,
              side: BorderSide(
                color: selected ? SoriTokens.primary : SoriTokens.border,
              ),
              onSelected: (_) => onSelected(f),
            );
          },
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CommunityFilterChipsDelegate oldDelegate) {
    return oldDelegate.filter != filter;
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState({
    required this.filter,
    required this.isSearching,
    required this.isDirector,
    required this.onComposeWhisper,
  });

  final CommunityFeedFilter filter;
  final bool isSearching;
  final bool isDirector;
  final VoidCallback onComposeWhisper;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '검색 결과가 없어요.',
            style: TextStyle(
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final icon = switch (filter) {
      CommunityFeedFilter.whisper => Icons.lock_outline_rounded,
      CommunityFeedFilter.interior => Icons.apartment_outlined,
      CommunityFeedFilter.deviceReview => Icons.devices_other_outlined,
      CommunityFeedFilter.productReview => Icons.shopping_bag_outlined,
      CommunityFeedFilter.marketplace => Icons.storefront_outlined,
      CommunityFeedFilter.seminar => Icons.school_outlined,
      CommunityFeedFilter.ba => Icons.photo_library_outlined,
      CommunityFeedFilter.mentoring => Icons.school_outlined,
      _ => Icons.forum_outlined,
    };

    final title = switch (filter) {
      CommunityFeedFilter.whisper => 'Whisper',
      CommunityFeedFilter.interior => '샵 인테리어',
      CommunityFeedFilter.deviceReview => '기기리뷰',
      CommunityFeedFilter.productReview => '제품리뷰',
      CommunityFeedFilter.marketplace => '중고거래',
      CommunityFeedFilter.seminar => '세미나',
      CommunityFeedFilter.ba => 'B/A',
      CommunityFeedFilter.mentoring => '멘토링',
      _ => 'Community',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: SoriTokens.textSecondary),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '아직 올라온 글이 없어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: SoriTokens.textSecondary,
              ),
            ),
            if (isDirector && filter == CommunityFeedFilter.whisper) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onComposeWhisper,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Whisper 남기기'),
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InteriorComposerSheet extends StatefulWidget {
  const _InteriorComposerSheet({required this.store});
  final SoriStore store;

  @override
  State<_InteriorComposerSheet> createState() => _InteriorComposerSheetState();
}

class _InteriorComposerSheetState extends State<_InteriorComposerSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<Uint8List> _images = [];
  final List<List<HotspotPinDraft>> _pinsByImage = [];
  int _activeImage = 0;
  bool _saving = false;
  CommunityVisibility _visibility = CommunityVisibility.public;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await openSoriInstaPicker(
      context,
      maxAssets: (12 - _images.length).clamp(1, 12),
      title: '인테리어 사진',
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      _images.addAll(files);
      for (var i = 0; i < files.length; i++) {
        _pinsByImage.add([]);
      }
      _activeImage = _images.length - 1;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_images.isEmpty && _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 또는 소개글을 입력해 주세요')),
      );
      return;
    }
    setState(() => _saving = true);
    final tags = _tagCtrl.text
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.replaceFirst('#', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final drafts = <CommunityTagDraft>[];
    for (var i = 0; i < _pinsByImage.length; i++) {
      for (final p in _pinsByImage[i]) {
        drafts.add(p.toTagDraft(i));
      }
    }

    final post = await widget.store.createCommunityPost(
      postType: CommunityPostType.interior,
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      imageBytesList: List.from(_images),
      styleTags: tags,
      tagDrafts: drafts,
      visibility: _visibility,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시 실패 — DB 마이그레이션(049)을 확인해 주세요'),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          drafts.isEmpty
              ? '인테리어 쇼룸이 등록되었어요'
              : '쇼룸 등록 · 핀 ${drafts.length}개',
        ),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = _images.isNotEmpty;
    final safeIndex =
        hasImages ? _activeImage.clamp(0, _images.length - 1) : 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + soriSheetBottomPadding(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '인테리어 쇼룸',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '예: 20평 의료미용 리뉴얼',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '소개',
                hintText: '조명·카운터·시술실 포인트',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagCtrl,
              decoration: const InputDecoration(
                labelText: '스타일 태그',
                hintText: '미니멀 조명 카운터',
              ),
            ),
            const SizedBox(height: 12),
            CommunityVisibilityPicker(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 12),
            if (hasImages) ...[
              if (_images.length > 1)
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final selected = i == safeIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _activeImage = i),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? SoriTokens.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _images[i],
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_images.length > 1) const SizedBox(height: 10),
              CommunityHotspotDraftEditor(
                bytes: _images[safeIndex],
                pins: _pinsByImage[safeIndex],
                onChanged: (next) {
                  setState(() => _pinsByImage[safeIndex] = next);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                '사진을 탭해 핫스팟 핀을 추가하세요. 핀을 길게 누르면 삭제됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _saving ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    foregroundColor: SoriTokens.onPrimary,
                  ),
                  child: Text(_saving ? '등록 중…' : '게시'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceMarketComposerSheet extends StatefulWidget {
  const _DeviceMarketComposerSheet({
    required this.store,
    this.initialSellUsed = false,
  });
  final SoriStore store;
  final bool initialSellUsed;

  @override
  State<_DeviceMarketComposerSheet> createState() =>
      _DeviceMarketComposerSheetState();
}

class _DeviceMarketComposerSheetState extends State<_DeviceMarketComposerSheet> {
  final _deviceCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _prosCtrl = TextEditingController();
  final _consCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<Uint8List> _images = [];
  int _usageMonths = 6;
  double _rating = 4;
  late bool _sellUsed;
  String _condition = 'good';
  bool _saving = false;
  CommunityVisibility _visibility = CommunityVisibility.public;

  @override
  void initState() {
    super.initState();
    _sellUsed = widget.initialSellUsed;
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _brandCtrl.dispose();
    _bodyCtrl.dispose();
    _prosCtrl.dispose();
    _consCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<String> _splitLines(String raw) => raw
      .split(RegExp(r'[\n,·]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pick() async {
    final files = await openSoriInstaPicker(
      context,
      maxAssets: (6 - _images.length).clamp(1, 6),
      title: '기기 사진',
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _images.addAll(files));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final device = _deviceCtrl.text.trim();
    if (device.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기기명을 입력해 주세요')),
      );
      return;
    }
    if (_sellUsed) {
      final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('중고 판매가를 입력해 주세요')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final review = DeviceReviewDraft(
      deviceName: device,
      brand: _brandCtrl.text.trim(),
      usageMonths: _usageMonths,
      rating: _rating,
      pros: _splitLines(_prosCtrl.text),
      cons: _splitLines(_consCtrl.text),
      wouldRecommend: _rating >= 3.5,
    );
    MarketListingDraft? listing;
    if (_sellUsed) {
      listing = MarketListingDraft(
        deviceName: device,
        brand: _brandCtrl.text.trim(),
        price: int.parse(_priceCtrl.text.replaceAll(',', '').trim()),
        condition: _condition,
        contactPhone: _phoneCtrl.text.trim(),
      );
    }

    final post = await widget.store.createCommunityPost(
      postType: _sellUsed
          ? CommunityPostType.marketplace
          : CommunityPostType.deviceReview,
      title: device,
      body: _bodyCtrl.text.trim().isEmpty
          ? '$device 실사용 리뷰'
          : _bodyCtrl.text,
      imageBytesList: List.from(_images),
      deviceReview: review,
      marketListing: listing,
      visibility: _visibility,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시 실패 — DB 마이그레이션(049)을 확인해 주세요'),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_sellUsed ? '리뷰·중고 매물이 등록되었어요' : '기기 리뷰가 등록되었어요'),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 +
            MediaQuery.viewInsetsOf(context).bottom +
            soriSheetBottomPadding(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '기기 리뷰 · 중고',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceCtrl,
              decoration: const InputDecoration(
                labelText: '기기명',
                hintText: '예: 울쎄라 프라임',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: '브랜드'),
            ),
            const SizedBox(height: 12),
            Text(
              '사용 기간 · $_usageMonths개월',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Slider(
              value: _usageMonths.toDouble(),
              min: 0,
              max: 60,
              divisions: 60,
              label: '$_usageMonths개월',
              activeColor: SoriTokens.primary,
              onChanged: (v) => setState(() => _usageMonths = v.round()),
            ),
            const Text(
              '만족도',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i.toDouble()),
                    icon: Icon(
                      i <= _rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: SoriTokens.warningText,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _prosCtrl,
              decoration: const InputDecoration(
                labelText: '장점 (Pros)',
                hintText: '콤마 또는 줄바꿈으로 구분',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _consCtrl,
              decoration: const InputDecoration(
                labelText: '단점 (Cons)',
                hintText: '콤마 또는 줄바꿈으로 구분',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '한줄 후기',
                hintText: '실사용 소감을 적어 주세요',
              ),
            ),
            const SizedBox(height: 12),
            CommunityVisibilityPicker(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _images[i],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '중고 판매',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                '가격·제품 상태를 추가하고 장터에 노출합니다',
                style: TextStyle(fontSize: 12),
              ),
              value: _sellUsed,
              activeThumbColor: SoriTokens.primary,
              onChanged: (v) => setState(() => _sellUsed = v),
            ),
            if (_sellUsed) ...[
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '판매가 (원)',
                  hintText: '3500000',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _condition,
                decoration: const InputDecoration(labelText: '제품 상태'),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('새제품')),
                  DropdownMenuItem(value: 'like_new', child: Text('거의 새것')),
                  DropdownMenuItem(value: 'good', child: Text('양호')),
                  DropdownMenuItem(value: 'fair', child: Text('사용감 있음')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _condition = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '연락처 (선택)',
                  hintText: '010-…',
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _saving ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    foregroundColor: SoriTokens.onPrimary,
                  ),
                  child: Text(_saving ? '등록 중…' : '게시'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
