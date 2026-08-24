import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Community 허브 — 탐색(Discover) 디렉터리 (KeepAlive + collapsing ring).
class CommunityDiscoverPane extends StatefulWidget {
  const CommunityDiscoverPane({super.key, required this.store});

  final SoriStore store;

  @override
  State<CommunityDiscoverPane> createState() => _CommunityDiscoverPaneState();
}

class _CommunityDiscoverPaneState extends State<CommunityDiscoverPane>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshDiscoverDirectors(soft: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DiscoverDirector> get _followedRing {
    return store.discoverDirectors
        .where((d) => store.isFollowingShop(d.shopId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ring = _followedRing;
    final rows = store.discoverDirectors;

    return RefreshIndicator(
      color: SoriTokens.primary,
      onRefresh: () => store.refreshDiscoverDirectors(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: SoriTokens.textPrimary),
                cursorColor: SoriTokens.primary,
                decoration: InputDecoration(
                  hintText: '원장·샵 이름을 입력하세요',
                  hintStyle: const TextStyle(color: SoriTokens.textQuaternary),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: SoriTokens.textTertiary,
                  ),
                  filled: true,
                  fillColor: SoriTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => store.refreshDiscoverDirectors(query: v),
                onChanged: (v) {
                  if (v.trim().isEmpty) {
                    store.refreshDiscoverDirectors(query: '');
                  }
                },
              ),
            ),
          ),
          if (ring.isNotEmpty)
            SliverPersistentHeader(
              pinned: false,
              floating: false,
              delegate: _MyCommunityRingDelegate(directors: ring),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  _Chip(
                    label: '전체',
                    active: true,
                    onTap: () => store.refreshDiscoverDirectors(query: ''),
                  ),
                  _Chip(
                    label: '강남',
                    onTap: () => store.refreshDiscoverDirectors(query: '강남'),
                  ),
                  _Chip(
                    label: '성수',
                    onTap: () => store.refreshDiscoverDirectors(query: '성수'),
                  ),
                  _Chip(
                    label: '한남',
                    onTap: () => store.refreshDiscoverDirectors(query: '한남'),
                  ),
                  _Chip(
                    label: '청담',
                    onTap: () => store.refreshDiscoverDirectors(query: '청담'),
                  ),
                ],
              ),
            ),
          ),
          if (store.discoverDirectorsLoading && rows.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (rows.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '검색 결과가 없어요',
                  style: TextStyle(color: SoriTokens.textSecondary),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final d = rows[i];
                  return _DiscoverRow(
                    director: d,
                    following: store.isFollowingShop(d.shopId),
                    onToggle: () => store.toggleDiscoverFollow(d),
                  );
                },
                childCount: rows.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? SoriTokens.primarySoft : SoriTokens.surfaceOverlay,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? SoriTokens.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? SoriTokens.primary : SoriTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyCommunityRingDelegate extends SliverPersistentHeaderDelegate {
  _MyCommunityRingDelegate({required this.directors});

  final List<DiscoverDirector> directors;

  @override
  double get maxExtent => 88;

  @override
  double get minExtent => 0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    final height = (maxExtent * (1 - t)).clamp(0.0, maxExtent);
    if (height < 1) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -8 * t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  '나의 커뮤니티',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: directors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final d = directors[i];
                    return SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: SoriTokens.surfaceOverlay,
                            backgroundImage: d.avatarUrl.isNotEmpty
                                ? NetworkImage(d.avatarUrl)
                                : null,
                            child: d.avatarUrl.isEmpty
                                ? Text(
                                    d.nickname.characters.first,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
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

  @override
  bool shouldRebuild(covariant _MyCommunityRingDelegate oldDelegate) {
    return oldDelegate.directors != directors;
  }
}

class _DiscoverRow extends StatelessWidget {
  const _DiscoverRow({
    required this.director,
    required this.following,
    required this.onToggle,
  });

  final DiscoverDirector director;
  final bool following;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: SoriTokens.surfaceOverlay,
              backgroundImage: director.avatarUrl.isNotEmpty
                  ? NetworkImage(director.avatarUrl)
                  : null,
              child: director.avatarUrl.isEmpty
                  ? Text(
                      director.nickname.characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          director.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                      ),
                      if (director.isSeed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    director.line2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: following
                  ? OutlinedButton(
                      onPressed: onToggle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SoriTokens.textSecondary,
                        side: const BorderSide(color: SoriTokens.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '팔로잉',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : FilledButton(
                      onPressed: onToggle,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '팔로우',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
