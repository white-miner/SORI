import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/unified_feed_item.dart';
import '../pages/case_detail_page.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/home_feed_card.dart';
import '../widgets/home_seminar_feed_card.dart';
import '../widgets/home_whisper_feed_card.dart';
import '../widgets/whisper_post_card.dart';
import '../views/device_review_detail_page.dart';
import '../views/seminar_class_detail_page.dart';

/// Single scroll list for unified community feed — filter applied locally.
class CommunityUnifiedFeedList extends StatelessWidget {
  const CommunityUnifiedFeedList({
    super.key,
    required this.store,
    required this.filter,
    required this.isDirector,
    required this.onComposeWhisper,
  });

  final SoriStore store;
  final CommunityFeedFilter filter;
  final bool isDirector;
  final VoidCallback onComposeWhisper;

  @override
  Widget build(BuildContext context) {
    final items = store.filteredUnifiedCommunityFeed(filter);
    final loading = store.unifiedFeedLoading && items.isEmpty;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 120),
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _emptyIcon(filter),
                size: 48,
                color: SoriTokens.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                _emptyTitle(filter),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emptyBody(filter),
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
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('community_unified_${filter.name}'),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return KeyedSubtree(
          key: ValueKey(item.stableKey),
          child: _UnifiedFeedRow(item: item, store: store),
        );
      },
    );
  }

  IconData _emptyIcon(CommunityFeedFilter f) => switch (f) {
        CommunityFeedFilter.whisper => Icons.lock_outline_rounded,
        CommunityFeedFilter.interior => Icons.apartment_outlined,
        CommunityFeedFilter.deviceReview => Icons.devices_other_outlined,
        CommunityFeedFilter.marketplace => Icons.storefront_outlined,
        CommunityFeedFilter.seminar => Icons.school_outlined,
        CommunityFeedFilter.ba => Icons.photo_library_outlined,
        _ => Icons.forum_outlined,
      };

  String _emptyTitle(CommunityFeedFilter f) => switch (f) {
        CommunityFeedFilter.whisper => 'Whisper',
        CommunityFeedFilter.interior => '인테리어 쇼룸',
        CommunityFeedFilter.deviceReview => '기기·제품 리뷰',
        CommunityFeedFilter.marketplace => '중고·신상 장터',
        CommunityFeedFilter.seminar => '세미나',
        CommunityFeedFilter.ba => 'B/A 케이스',
        _ => 'Community',
      };

  String _emptyBody(CommunityFeedFilter f) => switch (f) {
        CommunityFeedFilter.whisper =>
          '선택한 사람에게만 보이는 글을 남겨 보세요.',
        CommunityFeedFilter.interior =>
          '샵 사진을 올리고 소품·시공에 링크를 태그하세요.',
        CommunityFeedFilter.deviceReview =>
          '실사용 후기를 남기면 동료 원장의 구매 판단에 도움이 됩니다.',
        CommunityFeedFilter.marketplace =>
          '신상·중고 기기/제품을 올리고 동료 원장과 거래하세요.',
        CommunityFeedFilter.seminar => '모집 중인 세미나가 없어요.',
        CommunityFeedFilter.ba => '공유된 B/A 케이스가 없어요.',
        _ => '아직 올라온 글이 없어요.',
      };
}

class _UnifiedFeedRow extends StatelessWidget {
  const _UnifiedFeedRow({required this.item, required this.store});

  final UnifiedFeedItem item;
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return switch (item.kind) {
      UnifiedFeedKind.ba => HomeFeedCard(
          item: item.caseItem!,
          liked: false,
          likeCount: 5 + item.caseItem!.chart.id.hashCode.abs() % 48,
          commentCount: 0,
          bookmarked: false,
          onLike: () {},
          onComment: () {},
          onBookmark: () {},
          onOpenDetail: () => CaseDetailPage.push(
            context,
            page: CaseDetailPage(
              item: item.caseItem!,
              review: store.reviewForChart(item.caseItem!.chart.id),
              currentUserId: store.session?.id,
            ),
          ),
          onBookingCta: () {},
          onShopProfile: () {},
        ),
      UnifiedFeedKind.seminar => HomeSeminarFeedCard(
          seminar: item.seminar!,
          onOpenDetail: () => SeminarClassDetailPage.open(
            context,
            store: store,
            classId: item.seminar!.id,
          ),
        ),
      UnifiedFeedKind.whisper => HomeWhisperFeedCard(
          post: item.post!,
          store: store,
          onTap: () => _openWhisper(context, item.post!),
        ),
      UnifiedFeedKind.interior => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _InteriorMiniCard(post: item.post!, store: store),
        ),
      UnifiedFeedKind.deviceReview => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            tileColor: SoriTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.devices_other_outlined),
            title: Text(
              item.post!.deviceReview?.deviceName ??
                  item.post!.title.trim().ifEmpty('기기 후기'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(item.post!.shopName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => DeviceReviewDetailPage.open(
              context,
              store: store,
              post: item.post!,
            ),
          ),
        ),
      UnifiedFeedKind.marketplace => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            tileColor: SoriTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.storefront_outlined),
            title: Text(
              item.post!.listing?.deviceName ??
                  item.post!.title.trim().ifEmpty('매물'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              item.post!.listing != null
                  ? '${item.post!.listing!.price}원'
                  : item.post!.shopName,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ),
    };
  }

  void _openWhisper(BuildContext context, CommunityPost post) {
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
}

class _InteriorMiniCard extends StatelessWidget {
  const _InteriorMiniCard({required this.post, required this.store});

  final CommunityPost post;
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Row(
          children: [
            if (img != null)
              Image.network(
                img,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: ColoredBox(color: SoriTokens.surfaceOverlay),
                ),
              )
            else
              const SizedBox(
                width: 72,
                height: 72,
                child: ColoredBox(color: SoriTokens.surfaceOverlay),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '인테리어',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    Text(
                      post.title.trim().ifEmpty(post.shopName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
}
