import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/storage_image_url.dart';
import '../widgets/sori_logo.dart';
import '../widgets/debug_mode_chip.dart';
import 'customer_review_dashboard_page.dart';
import 'my_info_edit_page.dart';

/// 고객 모드 마이페이지 — Weverse형 4탭 (여정 / 회원권 / 리뷰 / 스크랩).
class CustomerMyPageView extends StatefulWidget {
  const CustomerMyPageView({
    super.key,
    required this.store,
    required this.session,
  });

  final SoriStore store;
  final SessionUser session;

  @override
  State<CustomerMyPageView> createState() => _CustomerMyPageViewState();
}

class _CustomerMyPageViewState extends State<CustomerMyPageView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  SoriStore get store => widget.store;
  SessionUser get session => widget.session;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMembershipWallet();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerId = session.customerId;
    final charts = customerId == null
        ? const <CustomerChart>[]
        : store.chartsForCustomer(customerId);
    final displayName =
        session.name.trim().isEmpty ? '고객' : session.name.trim();
    final myReviews = customerId == null
        ? store.reviews.where((_) => false).toList()
        : store.reviews
            .where(
              (r) =>
                  r.customerId == customerId &&
                  DirectorPeriodStats.isCompletedReview(r),
            )
            .toList();
    final scrapCount = store.favoriteShopCaseItems().length;
    final reviewCount = myReviews.length;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SoriTokens.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _TierBadgeChip(label: '🌿 Glow'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '단골 ${store.shop.name.trim().isEmpty ? '샵' : '1'} · '
                          '리뷰 $reviewCount · 스크랩 $scrapCount',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode) const DebugModeChip(),
                  IconButton(
                    tooltip: '리뷰 작성',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CustomerReviewDashboardPage(store: store),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_rounded,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: '프로필',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyInfoEditPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
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
              indicatorWeight: 2.4,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: const [
                Tab(text: '내 케어 여정'),
                Tab(text: '단골 샵/회원권'),
                Tab(text: '내 리뷰'),
                Tab(text: '스크랩'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _CareJourneyTab(charts: charts, store: store),
                  _MembershipTab(store: store),
                  _TwoColPlaceholderGrid(
                    emptyLabel: '작성한 리뷰가 여기에 모여요',
                    itemCount: reviewCount.clamp(0, 6),
                    labelBuilder: (i) => '리뷰 ${i + 1}',
                  ),
                  _TwoColPlaceholderGrid(
                    emptyLabel: '찜한 B/A 케이스가 여기에 모여요',
                    itemCount: scrapCount.clamp(0, 8),
                    labelBuilder: (i) => '스크랩 ${i + 1}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierBadgeChip extends StatelessWidget {
  const _TierBadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SoriTokens.primarySoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFFC4B5FD),
        ),
      ),
    );
  }
}

class _SquircleCard extends StatelessWidget {
  const _SquircleCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: child,
    );
  }
}

class _CareJourneyTab extends StatelessWidget {
  const _CareJourneyTab({required this.charts, required this.store});

  final List<CustomerChart> charts;
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    if (charts.isEmpty) {
      return const _EmptyTabHint(
        title: '아직 케어 여정이 없어요',
        subtitle: '첫 방문 후 Before/After가 여기에 타임라인으로 쌓여요',
      );
    }

    final sorted = [...charts]..sort((a, b) {
      final ad = a.createdAt ?? a.visitCheckedAt ?? DateTime(1970);
      final bd = b.createdAt ?? b.visitCheckedAt ?? DateTime(1970);
      return bd.compareTo(ad);
    });

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = sorted[i];
        final shopName = store.shop.name.trim().isEmpty
            ? '단골 샵'
            : store.shop.name.trim();
        final when = c.createdAt ?? c.visitCheckedAt ?? DateTime.now();
        final date =
            '${when.year}.${when.month.toString().padLeft(2, '0')}.${when.day.toString().padLeft(2, '0')}';
        final care =
            c.careName.trim().isEmpty ? '케어 기록' : c.careName.trim();
        final before = StorageImageUrl.resolve(c.beforeImageUrl);
        final after = StorageImageUrl.resolve(c.afterImageUrl);

        return _SquircleCard(
          child: Row(
            children: [
              _BaThumbPair(beforeUrl: before, afterUrl: after),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      care,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BaThumbPair extends StatelessWidget {
  const _BaThumbPair({this.beforeUrl, this.afterUrl});

  final String? beforeUrl;
  final String? afterUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: Row(
        children: [
          Expanded(child: _thumb(beforeUrl)),
          const SizedBox(width: 2),
          Expanded(child: _thumb(afterUrl)),
        ],
      ),
    );
  }

  Widget _thumb(String? url) {
    final u = (url ?? '').trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFF27272A),
        child: u.isEmpty
            ? const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: SoriTokens.textSecondary,
                ),
              )
            : Image.network(
                u,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF27272A),
                ),
              ),
      ),
    );
  }
}

class _MembershipTab extends StatelessWidget {
  const _MembershipTab({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final wallet = store.activeMembershipWallet;
    final shopName = shop.name.trim().isEmpty ? '단골 샵' : shop.name.trim();

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _SquircleCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SoriTokens.primarySoft,
                backgroundImage:
                    (shop.profileImageUrl ?? '').trim().isNotEmpty
                        ? NetworkImage(shop.profileImageUrl!.trim())
                        : null,
                child: (shop.profileImageUrl ?? '').trim().isEmpty
                    ? Text(
                        _initial(shopName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.primary,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (shop.ownerName ?? '').trim().isEmpty
                          ? '나의 단골 샵'
                          : '${shop.ownerName!.trim()} 원장',
                      style: const TextStyle(
                        fontSize: 13,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (wallet.isEmpty)
          const _SquircleCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '등록된 회원권이 없어요',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          ...wallet.map((t) {
            final label =
                t.ticketName.trim().isEmpty ? '회원권' : t.ticketName.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SquircleCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SoriTokens.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        color: SoriTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '잔여 ${t.remainingVisits}회',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TwoColPlaceholderGrid extends StatelessWidget {
  const _TwoColPlaceholderGrid({
    required this.emptyLabel,
    required this.itemCount,
    required this.labelBuilder,
  });

  final String emptyLabel;
  final int itemCount;
  final String Function(int index) labelBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) {
      return _EmptyTabHint(title: emptyLabel, subtitle: '');
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        return _SquircleCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                labelBuilder(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTabHint extends StatelessWidget {
  const _EmptyTabHint({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textPrimary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _initial(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'S';
  return String.fromCharCodes(t.runes.take(1));
}
