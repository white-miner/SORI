import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../widgets/community_hotspot_image.dart';
import '../widgets/community_trust_header.dart';
import '../widgets/sori_insta_picker.dart';
import 'customer_management_cases_page.dart';
import 'seminar_class_detail_page.dart';
import 'success_cases_page.dart';

/// 글로벌 Community 탭 — B2B 광장 (케이스·인테리어·기기·중고·세미나).
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
    _tabs = TabController(length: 5, vsync: this);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityPosts();
      store.refreshCommunityHotCases();
      store.refreshSeminarClasses();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _composeInterior() async {
    if (!_isDirector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원장 모드에서만 인테리어를 올릴 수 있어요')),
      );
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

  Future<void> _composeDeviceMarket() async {
    if (!_isDirector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원장 모드에서만 리뷰·중고를 올릴 수 있어요')),
      );
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
      builder: (ctx) => _DeviceMarketComposerSheet(store: store),
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
                  if (_isDirector)
                    IconButton(
                      tooltip: '인테리어 올리기',
                      onPressed: _composeInterior,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      color: SoriTokens.primary,
                    ),
                  if (_isDirector)
                    IconButton(
                      tooltip: '기기·중고 올리기',
                      onPressed: _composeDeviceMarket,
                      icon: const Icon(Icons.devices_other_outlined),
                      color: SoriTokens.primary,
                    ),
                ],
              ),
            ),
            Material(
              color: SoriTokens.background,
              child: TabBar(
                controller: _tabs,
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
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: const [
                  Tab(text: '추천'),
                  Tab(text: '케이스'),
                  Tab(text: '인테리어'),
                  Tab(text: '기기·중고'),
                  Tab(text: '세미나'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _RecommendSegment(store: store),
                  _isDirector
                      ? SuccessCasesPage(store: store)
                      : CustomerManagementCasesPage(store: store),
                  _InteriorSegment(
                    store: store,
                    isOwner: _isDirector,
                    onCompose: _composeInterior,
                  ),
                  _MarketSegment(
                    store: store,
                    isOwner: _isDirector,
                    onCompose: _composeDeviceMarket,
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

class _RecommendSegment extends StatelessWidget {
  const _RecommendSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final interiors = store.communityPosts
        .where((p) => p.postType == CommunityPostType.interior)
        .take(6)
        .toList();
    final markets = store.communityPosts
        .where(
          (p) =>
              p.postType == CommunityPostType.marketplace ||
              p.postType == CommunityPostType.deviceReview,
        )
        .take(4)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const Text(
          '업계 광장에서 인테리어·실사용 기기·중고를 한곳에서',
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
          '기기 · 중고',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (markets.isEmpty)
          const _EmptyHint(
            text: '실사용 리뷰와 중고 매물이 여기에 모입니다. (채팅·연락 기반)',
          )
        else
          ...markets.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MarketCard(post: p, store: store),
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
    final posts = store.communityPosts
        .where((p) => p.postType == CommunityPostType.interior)
        .toList();

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

    return Container(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: CommunityTrustHeader(
              post: post,
              trailing: post.shopId == store.shop.id
                  ? IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => store.removeCommunityPost(post.id),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    )
                  : null,
            ),
          ),
          if (media.length <= 1)
            CommunityHotspotImage(
              imageUrl: primary?.imageUrl ?? post.primaryImageUrl,
              tags: tags,
            )
          else
            SizedBox(
              height: 260,
              child: PageView.builder(
                itemCount: media.length,
                itemBuilder: (context, i) {
                  final m = media[i];
                  return CommunityHotspotImage(
                    imageUrl: m.imageUrl,
                    tags: post.tagsForMedia(m.id),
                    aspectRatio: 1,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title.trim().isNotEmpty)
                  Text(
                    post.title.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                if (post.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.body.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
                if (styleTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: styleTags
                        .take(5)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SoriTokens.primarySoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              t.startsWith('#') ? t : '#$t',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: SoriTokens.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '핀 ${post.tags.length}개 · 사진을 탭해 제품·업체를 확인하세요',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '핀 $pinCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
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

class _MarketSegment extends StatefulWidget {
  const _MarketSegment({
    required this.store,
    required this.isOwner,
    required this.onCompose,
  });

  final SoriStore store;
  final bool isOwner;
  final VoidCallback onCompose;

  @override
  State<_MarketSegment> createState() => _MarketSegmentState();
}

class _MarketSegmentState extends State<_MarketSegment> {
  MarketListingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    var posts = widget.store.communityPosts
        .where(
          (p) =>
              p.postType == CommunityPostType.marketplace ||
              p.postType == CommunityPostType.deviceReview,
        )
        .toList();

    if (_filter != null) {
      posts = posts
          .where((p) => p.listing?.status == _filter)
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: '전체',
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
                        label: '예약 중',
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
                        const Icon(Icons.devices_other_outlined,
                            size: 48, color: SoriTokens.textSecondary),
                        const SizedBox(height: 14),
                        const Text(
                          '기기 리뷰 · 중고 장터',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '사용 기간·만족도·장단점을 남기고\n중고 판매를 함께 연결할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                        if (widget.isOwner) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: widget.onCompose,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('리뷰·매물 올리기'),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _MarketCard(post: posts[i], store: widget.store),
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
          color: selected ? SoriTokens.primarySoft : SoriTokens.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? SoriTokens.primary : SoriTokens.outlinePurple,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.post, required this.store});
  final CommunityPost post;
  final SoriStore store;

  bool get _isOwner =>
      post.shopId.isNotEmpty && post.shopId == store.shop.id;

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
    final phone = listing?.contactPhone?.trim() ?? '';
    final sold = status == MarketListingStatus.sold;
    final img = post.primaryImageUrl;

    return Opacity(
      opacity: sold ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SoriTokens.outlinePurple),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
              child: CommunityTrustHeader(
                post: post,
                trailing: _isOwner && listing != null
                    ? IconButton(
                        tooltip: '판매 상태',
                        onPressed: () => _showStatusSheet(context),
                        icon: const Icon(Icons.more_vert_rounded),
                      )
                    : null,
              ),
            ),
            if (img != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) {
                  return const ColoredBox(color: Color(0xFF1A1028));
                }),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (listing != null) _StatusBadge(status: status),
                      if (review?.rating != null) ...[
                        const SizedBox(width: 8),
                        _StarRow(rating: review!.rating!),
                      ],
                      const Spacer(),
                      if (listing != null && listing.price > 0)
                        Text(
                          '${_formatWon(listing.price)}원',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: SoriTokens.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    listing?.deviceName.trim().isNotEmpty == true
                        ? listing!.deviceName
                        : (review?.deviceName.trim().isNotEmpty == true
                            ? review!.deviceName
                            : (post.title.trim().isEmpty
                                ? post.body
                                : post.title)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (review != null && review.usageMonths > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '사용 ${review.usageMonths}개월'
                      '${listing != null ? ' · ${_conditionLabel(listing.condition)}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (review != null &&
                      (review.pros.isNotEmpty || review.cons.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    if (review.pros.isNotEmpty)
                      Text(
                        '장점 · ${review.pros.take(3).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (review.cons.isNotEmpty)
                      Text(
                        '단점 · ${review.cons.take(3).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF87171),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                  if (post.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.body.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                  if (listing != null && !sold) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (phone.isNotEmpty)
                          TextButton.icon(
                            onPressed: () =>
                                launchUrl(Uri.parse('tel:$phone')),
                            icon: const Icon(Icons.phone_outlined, size: 18),
                            label: const Text('연락하기'),
                          ),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '문의 메시지를 남기면 판매자에게 전달됩니다',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                          ),
                          label: const Text('채팅 문의'),
                        ),
                      ],
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

  static String _conditionLabel(String c) => switch (c) {
        'new' => '새제품',
        'like_new' => '거의 새것',
        'fair' => '사용감 있음',
        _ => '양호',
      };

  static String _formatWon(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return buf.toString();
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
            color: const Color(0xFFFBBF24),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MarketListingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MarketListingStatus.active => SoriTokens.primary,
      MarketListingStatus.reserved => const Color(0xFFFBBF24),
      MarketListingStatus.sold => SoriTokens.textSecondary,
      _ => SoriTokens.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시 실패 — DB 마이그레이션(049)을 확인해 주세요'),
          backgroundColor: Colors.redAccent,
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
  const _DeviceMarketComposerSheet({required this.store});
  final SoriStore store;

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
  bool _sellUsed = false;
  String _condition = 'good';
  bool _saving = false;

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
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시 실패 — DB 마이그레이션(049)을 확인해 주세요'),
          backgroundColor: Colors.redAccent,
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
                      color: const Color(0xFFFBBF24),
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
