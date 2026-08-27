import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../utils/whisper_feed.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/community_hotspot_image.dart';
import '../widgets/community_motivation.dart';
import '../widgets/sori_insta_picker.dart';
import '../widgets/whisper_post_card.dart';
import 'device_review_detail_page.dart';
import 'seminar_class_detail_page.dart';
import 'whisper_composer_sheet.dart';

/// Community 탭 인덱스 — 속삭임 탭 삽입 후 오프셋.
abstract final class _CommunityTab {
  static const all = 0;
  static const whisper = 1;
  static const interior = 2;
  static const deviceReview = 3;
  static const marketplace = 4;
  static const seminar = 5;
  static const length = 6;
}

/// 글로벌 Community 탭 — B2B 광장 (속삭임·인테리어·리뷰·중고·세미나).
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  SoriStore get store => widget.store;

  bool get _isDirector =>
      store.session?.activeMode == UserRole.director;

  @override
  void initState() {
    super.initState();
    final pending = store.pendingCommunitySegment;
    final initial = (pending != null &&
            pending >= 0 &&
            pending < _CommunityTab.length)
        ? pending
        : 0;
    store.pendingCommunitySegment = null;
    _tabs = TabController(
      length: _CommunityTab.length,
      vsync: this,
      initialIndex: initial,
    );
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityPosts();
      store.refreshSeminarClasses();
      store.refreshPointWallet();
      final again = store.pendingCommunitySegment;
      if (again != null && again >= 0 && again < _CommunityTab.length) {
        store.pendingCommunitySegment = null;
        _tabs.animateTo(again);
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
    _tabs.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    final pending = store.pendingCommunitySegment;
    if (pending != null && pending >= 0 && pending < _CommunityTab.length) {
      store.pendingCommunitySegment = null;
      _tabs.animateTo(pending);
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
    await showWhisperComposer(context, store: store);
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Community',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (_isDirector) ...[
                    IconButton(
                      tooltip: '속삭임 작성',
                      onPressed: _composeWhisper,
                      icon: const Icon(Icons.lock_outline_rounded),
                      color: SoriTokens.primary,
                    ),
                    IconButton(
                      tooltip: '인테리어 올리기',
                      onPressed: _composeInterior,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      color: SoriTokens.primary,
                    ),
                    IconButton(
                      tooltip: '리뷰·매물 올리기',
                      onPressed: () => _composeDeviceMarket(),
                      icon: const Icon(Icons.devices_other_outlined),
                      color: SoriTokens.primary,
                    ),
                  ],
                ],
              ),
            ),
            if (!_isDirector) const _CommunityViewerBanner(),
            Material(
              color: SoriTokens.background,
              child: SoriYoutubeTabBar(
                controller: _tabs,
                labels: const [
                  '전체',
                  '속삭임',
                  '인테리어',
                  '기기 리뷰',
                  '중고·신상',
                  '세미나',
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _RecommendSegment(store: store),
                  _WhisperSegment(
                    store: store,
                    isDirector: _isDirector,
                    onCompose: _composeWhisper,
                  ),
                  _InteriorSegment(
                    store: store,
                    isOwner: _isDirector,
                    onCompose: _composeInterior,
                  ),
                  _MarketSegment(
                    store: store,
                    isOwner: _isDirector,
                    mode: _MarketRailMode.reviews,
                    onCompose: () => _composeDeviceMarket(preferListing: false),
                    onDirectorOnly: _showDirectorOnly,
                  ),
                  _MarketSegment(
                    store: store,
                    isOwner: _isDirector,
                    mode: _MarketRailMode.listings,
                    onCompose: () => _composeDeviceMarket(preferListing: true),
                    onDirectorOnly: _showDirectorOnly,
                  ),
                  _SeminarSegment(store: store),
                ],
              ),
            ),
          ],
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

class _WhisperSegment extends StatelessWidget {
  const _WhisperSegment({
    required this.store,
    required this.isDirector,
    required this.onCompose,
  });

  final SoriStore store;
  final bool isDirector;
  final VoidCallback onCompose;

  void _openPost(BuildContext context, CommunityPost post) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: WhisperPostCard(post: post, store: store),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = store.session?.id;
    final incoming = whisperIncomingPosts(
      store.communityPosts,
      viewerId: viewerId,
    );
    final authored = whisperAuthoredPosts(
      store.communityPosts,
      viewerId: viewerId,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF064E3B).withValues(alpha: 0.55),
                        SoriTokens.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SoriTokens.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: SoriTokens.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '속삭임',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '많은 사람에게 말하기 부담스러울 때, 선택한 사람에게만 남겨 보세요.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isDirector) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: onCompose,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('속삭임 남기기'),
                            style: FilledButton.styleFrom(
                              backgroundColor: SoriTokens.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _WhisperZoneHeader(
                  title: '나에게 들려온 속삭임',
                  subtitle: '조건에 맞아 나만 볼 수 있는 글이에요.',
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        if (incoming.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _EmptyHint(
                text: '아직 들려온 속삭임이 없어요. 팔로우·방문하면 여기에 모여요.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _WhisperMasonryGrid(
                posts: incoming,
                store: store,
                onOpen: (p) => _openPost(context, p),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WhisperZoneHeader(
                  title: '내가 남긴 속삭임',
                  subtitle: '내가 선택한 사람에게만 전달된 글이에요.',
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        if (authored.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverToBoxAdapter(
              child: _EmptyHint(
                text: isDirector
                    ? '첫 속삭임을 남겨 보세요. 선택한 사람에게만 전달됩니다.'
                    : '아직 남긴 속삭임이 없어요.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverToBoxAdapter(
              child: _WhisperMasonryGrid(
                posts: authored,
                store: store,
                onOpen: (p) => _openPost(context, p),
              ),
            ),
          ),
      ],
    );
  }
}

class _WhisperZoneHeader extends StatelessWidget {
  const _WhisperZoneHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WhisperMasonryGrid extends StatelessWidget {
  const _WhisperMasonryGrid({
    required this.posts,
    required this.store,
    required this.onOpen,
  });

  final List<CommunityPost> posts;
  final SoriStore store;
  final void Function(CommunityPost post) onOpen;

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    const gap = 8.0;
    final columns = List.generate(cols, (_) => <CommunityPost>[]);
    for (var i = 0; i < posts.length; i++) {
      columns[i % cols].add(posts[i]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (final p in posts) ...[
                WhisperPostCard(
                  post: p,
                  store: store,
                  compact: true,
                  onTap: () => onOpen(p),
                ),
                const SizedBox(height: gap),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++) ...[
              if (c > 0) const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    for (final p in columns[c]) ...[
                      WhisperPostCard(
                        post: p,
                        store: store,
                        compact: true,
                        onTap: () => onOpen(p),
                      ),
                      const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RecommendSegment extends StatelessWidget {
  const _RecommendSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final interiors = store.communityPosts
        .where((p) => p.postType == CommunityPostType.interior && !p.isWhisper)
        .take(6)
        .toList();
    final reviews = store.communityPosts
        .where((p) =>
            p.postType == CommunityPostType.deviceReview && !p.isWhisper)
        .take(4)
        .toList();
    final listings = store.communityPosts
        .where((p) =>
            p.postType == CommunityPostType.marketplace && !p.isWhisper)
        .take(4)
        .toList();
    final seminars = store.seminarClasses.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const Text(
          '원장 업계 광장 — 인테리어·실사용 리뷰·매물·세미나',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '인테리어 쇼룸',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (interiors.isEmpty)
          const _EmptyHint(text: '아직 올라온 인테리어가 없어요. 첫 쇼룸을 올려보세요.')
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: interiors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _InteriorCard(post: interiors[i], width: 140),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          '기기 실사용 리뷰',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const _EmptyHint(text: '동료 원장의 실사용 후기가 여기에 모입니다.')
        else
          ...reviews.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MarketCard(post: p, store: store),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          '중고·신상 매물',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (listings.isEmpty)
          const _EmptyHint(text: '판매·구매 매물이 여기에 모입니다.')
        else
          ...listings.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MarketCard(post: p, store: store),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          '모집 중 세미나',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (seminars.isEmpty)
          const _EmptyHint(text: '개설된 세미나가 없어요. 세미나 탭에서 확인해 보세요.')
        else
          ...seminars.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.school_outlined,
                  color: SoriTokens.primary,
                ),
                title: Text(
                  c.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('정원 ${c.currentEnrollment}/${c.maxCapacity}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => SeminarClassDetailPage.open(
                  context,
                  store: store,
                  classId: c.id,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InteriorSegment extends StatelessWidget {
  const _InteriorSegment({
    required this.store,
    required this.isOwner,
    required this.onCompose,
  });

  final SoriStore store;
  final bool isOwner;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final posts = store.interleavedCommunityPosts(
      CommunityPostType.interior,
      viewerId: store.session?.id,
    );

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_outlined,
                  size: 48, color: SoriTokens.textSecondary),
              const SizedBox(height: 14),
              const Text(
                '인테리어 쇼룸',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '샵 사진을 올리고 소품·시공에 링크를 태그하세요.\n다른 원장이 랜선으로 투어합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: SoriTokens.textSecondary,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onCompose,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('쇼룸 올리기'),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: posts.length + (isOwner ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (isOwner && i == 0) {
          return OutlinedButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.add),
            label: const Text('인테리어 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SoriTokens.primary,
              side: const BorderSide(color: SoriTokens.outlinePurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          );
        }
        final post = posts[isOwner ? i - 1 : i];
        return _InteriorFeedTile(post: post, store: store);
      },
    );
  }
}

class _InteriorFeedTile extends StatelessWidget {
  const _InteriorFeedTile({required this.post, required this.store});

  final CommunityPost post;
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    final primary = media.isNotEmpty ? media.first : null;
    final tags = primary == null
        ? const <CommunityPostTag>[]
        : post.tagsForMedia(primary.id);
    final styleTags = post.styleTags;
    final title = post.title.trim();
    final body = post.body.trim();

    return CommunityPostShell(
      store: store,
      post: post,
      onComposeReview: () {
        // Switch hint — parent TabBar isn't accessible; snack + rely on GNB.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기기·중고 탭에서 리뷰를 작성하면 잠금이 해제됩니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      trailing: post.shopId == store.shop.id
          ? IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => store.removeCommunityPost(post.id),
              icon: const Icon(Icons.delete_outline, size: 20),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      height: 1.35,
                      letterSpacing: -0.35,
                    ),
                  ),
                if (body.isNotEmpty) ...[
                  SizedBox(height: title.isEmpty ? 0 : 12),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.72,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFD4D4D8),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
                if (styleTags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: styleTags
                        .take(5)
                        .map(
                          (t) => Text(
                            t.startsWith('#') ? t : '#$t',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: SoriTokens.primary.withValues(alpha: 0.9),
                              height: 1.3,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (media.length <= 1)
            CommunityHotspotImage(
              imageUrl: primary?.imageUrl ?? post.primaryImageUrl,
              tags: tags,
              aspectRatio: 4 / 3,
              store: store,
              ownerShopId: post.shopId,
              postId: post.id,
            )
          else
            SizedBox(
              height: 280,
              child: PageView.builder(
                itemCount: media.length,
                itemBuilder: (context, i) {
                  final m = media[i];
                  return CommunityHotspotImage(
                    imageUrl: m.imageUrl,
                    tags: post.tagsForMedia(m.id),
                    aspectRatio: 1,
                    store: store,
                    ownerShopId: post.shopId,
                    postId: post.id,
                  );
                },
              ),
            ),
          if (post.tags.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Text(
                '사진 속 작은 점을 탭하면 제품·업체 정보를 볼 수 있어요',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          CommunityCommentsSection(store: store, postId: post.id),
        ],
      ),
    );
  }
}

class _InteriorCard extends StatelessWidget {
  const _InteriorCard({required this.post, required this.width});
  final CommunityPost post;
  final double width;

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    final pinCount = post.tags.length;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              Image.network(
                img,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF18181B)),
              )
            else
              const ColoredBox(color: Color(0xFF18181B)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0A0A0C)],
                ),
              ),
            ),
            if (pinCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                post.title.trim().isEmpty
                    ? (post.body.trim().isEmpty ? '인테리어' : post.body.trim())
                    : post.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MarketRailMode { reviews, listings }

class _MarketSegment extends StatefulWidget {
  const _MarketSegment({
    required this.store,
    required this.isOwner,
    required this.onCompose,
    required this.mode,
    this.onDirectorOnly,
  });

  final SoriStore store;
  final bool isOwner;
  final VoidCallback onCompose;
  final _MarketRailMode mode;
  final VoidCallback? onDirectorOnly;

  @override
  State<_MarketSegment> createState() => _MarketSegmentState();
}

class _MarketSegmentState extends State<_MarketSegment> {
  MarketListingStatus? _filter;

  bool get _listingsMode => widget.mode == _MarketRailMode.listings;

  @override
  Widget build(BuildContext context) {
    var posts = _listingsMode
        ? widget.store.communityPosts.where((p) {
            if (p.isWhisper) return false;
            return p.postType == CommunityPostType.marketplace ||
                (p.postType == CommunityPostType.deviceReview &&
                    p.listing != null);
          }).toList()
        : widget.store.interleavedCommunityPosts(
            CommunityPostType.deviceReview,
            viewerId: widget.store.session?.id,
          );

    if (_listingsMode && _filter != null) {
      posts = posts.where((p) => p.listing?.status == _filter).toList();
    }

    final emptyTitle = _listingsMode ? '중고·신상 장터' : '기기·제품 리뷰';
    final emptyBody = _listingsMode
        ? '신상·중고 기기/제품을 올리고 동료 원장과 거래하세요.'
        : '실사용 후기를 남기면 동료 원장의 구매 판단에 도움이 됩니다.';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              if (_listingsMode)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: '전체 매물',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '판매 중',
                          selected: _filter == MarketListingStatus.active,
                          onTap: () => setState(
                            () => _filter = MarketListingStatus.active,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '예약',
                          selected: _filter == MarketListingStatus.reserved,
                          onTap: () => setState(
                            () => _filter = MarketListingStatus.reserved,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '거래 완료',
                          selected: _filter == MarketListingStatus.sold,
                          onTap: () => setState(
                            () => _filter = MarketListingStatus.sold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    '실사용 후기',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
              if (widget.isOwner)
                IconButton(
                  onPressed: widget.onCompose,
                  icon: const Icon(Icons.add_circle_outline),
                  color: SoriTokens.primary,
                ),
            ],
          ),
        ),
        Expanded(
          child: posts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _listingsMode
                              ? Icons.storefront_outlined
                              : Icons.rate_review_outlined,
                          size: 48,
                          color: SoriTokens.textSecondary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          emptyTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                        if (widget.isOwner) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: widget.onCompose,
                            icon: const Icon(Icons.add),
                            label: Text(_listingsMode ? '매물 등록' : '리뷰 작성'),
                            style: FilledButton.styleFrom(
                              backgroundColor: SoriTokens.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    return _MarketCard(
                      post: posts[i],
                      store: widget.store,
                      readOnly: !widget.isOwner,
                      onDirectorOnly: widget.onDirectorOnly,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? SoriTokens.primary : SoriTokens.chipIdleBg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected
                ? SoriTokens.onPrimary
                : SoriTokens.tabUnselected,
          ),
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.post,
    required this.store,
    this.readOnly = false,
    this.onDirectorOnly,
  });
  final CommunityPost post;
  final SoriStore store;
  final bool readOnly;
  final VoidCallback? onDirectorOnly;

  bool get _isOwner =>
      !readOnly && post.shopId.isNotEmpty && post.shopId == store.shop.id;

  String get _deviceName {
    final r = post.deviceReview?.deviceName.trim() ?? '';
    if (r.isNotEmpty) return r;
    final l = post.listing?.deviceName.trim() ?? '';
    if (l.isNotEmpty) return l;
    final t = post.title.trim();
    return t.isEmpty ? '기기 후기' : t;
  }

  Future<void> _showStatusSheet(BuildContext context) async {
    final listing = post.listing;
    if (listing == null) return;
    final choice = await showModalBottomSheet<MarketListingStatus>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '판매 상태 변경',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              for (final s in [
                MarketListingStatus.active,
                MarketListingStatus.reserved,
                MarketListingStatus.sold,
              ])
                ListTile(
                  title: Text(s.label),
                  trailing: listing.status == s
                      ? const Icon(Icons.check, color: SoriTokens.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    await store.updateMarketListingStatus(
      listingId: listing.id,
      status: choice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = post.listing;
    final review = post.deviceReview;
    final status = listing?.status ?? MarketListingStatus.active;
    final sold = listing != null && status == MarketListingStatus.sold;
    final img = post.primaryImageUrl;
    final months = review?.usageMonths ?? 0;

    return Opacity(
      opacity: sold ? 0.55 : 1,
      child: CommunityPostShell(
        store: store,
        post: post,
        onComposeReview: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('기기·중고 탭 상단 + 로 리뷰를 작성해 주세요'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        trailing: _isOwner && listing != null
            ? IconButton(
                tooltip: '판매 상태',
                onPressed: () => _showStatusSheet(context),
                icon: const Icon(Icons.more_vert_rounded),
              )
            : null,
        body: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => DeviceReviewDetailPage.open(
              context,
              store: store,
              post: post,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (months > 0)
                            Flexible(
                              child: Text(
                                '$months개월 실사용 후기',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SoriTokens.primary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            )
                          else
                            const Flexible(
                              child: Text(
                                '실사용 후기',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SoriTokens.primary,
                                ),
                              ),
                            ),
                          if (review?.rating != null) ...[
                            const SizedBox(width: 8),
                            _StarRow(rating: review!.rating!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                      ),
                      if (post.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          post.body.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFD4D4D8),
                          ),
                        ),
                      ],
                      if (review != null &&
                          (review.pros.isNotEmpty ||
                              review.cons.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        if (review.pros.isNotEmpty)
                          _ProsConsLine(
                            label: '장점',
                            text: review.pros.take(2).join(' · '),
                            color: SoriTokens.primary,
                          ),
                        if (review.cons.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _ProsConsLine(
                            label: '단점',
                            text: review.cons.take(2).join(' · '),
                            color: const Color(0xFFF87171),
                          ),
                        ],
                      ],
                      if (listing != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          sold
                              ? '거래 완료된 매물이 연결된 후기예요'
                              : '중고 매물 연결됨 · 자세히에서 알아보기',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: SoriTokens.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (img != null)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: SoriTokens.primaryDark),
                    ),
                  ),
                CommunityCommentsSection(store: store, postId: post.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProsConsLine extends StatelessWidget {
  const _ProsConsLine({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE4E4E7),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.round().clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= full ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: SoriTokens.warningText,
          ),
      ],
    );
  }
}

class _SeminarSegment extends StatelessWidget {
  const _SeminarSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final classes = store.seminarClasses;
    if (classes.isEmpty) {
      return const Center(
        child: Text(
          '모집 중 세미나가 없어요',
          style: TextStyle(color: SoriTokens.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = classes[i];
        final when = c.eventDate;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: SoriTokens.outlinePurple),
          ),
          tileColor: SoriTokens.surface,
          leading: const Icon(Icons.school_outlined, color: SoriTokens.primary),
          title: Text(
            c.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            when == null
                ? '정원 ${c.currentEnrollment}/${c.maxCapacity}'
                : '${when.month}/${when.day} · 정원 ${c.currentEnrollment}/${c.maxCapacity}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => SeminarClassDetailPage.open(
            context,
            store: store,
            classId: c.id,
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: SoriTokens.textSecondary,
          fontWeight: FontWeight.w600,
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
