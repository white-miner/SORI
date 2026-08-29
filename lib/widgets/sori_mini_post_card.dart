import 'package:flutter/material.dart';

import '../models/unified_feed_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/mini_post_navigation.dart';
import '../utils/relative_time.dart';
import 'sori_logo.dart';
import 'sori_network_image.dart';

/// High-density mini feed card — Community explore + Home SORI Spot.
class SoriMiniPostCard extends StatelessWidget {
  const SoriMiniPostCard({
    super.key,
    required this.item,
    required this.store,
    this.onMore,
    this.horizontal = false,
    this.width,
  });

  final UnifiedFeedItem item;
  final SoriStore store;
  final VoidCallback? onMore;
  final bool horizontal;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final data = _MiniPostViewData.fromItem(item);
    final card = Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(data: data),
            const SizedBox(height: 8),
            _Body(data: data),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMore ??
                    () => openMiniPostDetail(
                          context,
                          item: item,
                          store: store,
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '더보기',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!horizontal) return card;
    return SizedBox(width: width ?? 288, child: card);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final _MiniPostViewData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(url: data.avatarUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: data.badgeBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: data.badgeBorder),
                  ),
                  child: Text(
                    data.categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: data.badgeForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final _MiniPostViewData data;

  @override
  Widget build(BuildContext context) {
    final thumb = data.thumbnailUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            data.bodyText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: data.bodyLocked
                  ? SoriTokens.textTertiary
                  : SoriTokens.textPrimary,
            ),
          ),
        ),
        if (thumb != null && thumb.isNotEmpty) ...[
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: SoriNetworkImage(
                url: thumb,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    final valid = u.isNotEmpty && !u.startsWith('data:');
    return CircleAvatar(
      radius: 14,
      backgroundColor: SoriTokens.primarySoft,
      backgroundImage: valid ? NetworkImage(u) : null,
      child: valid
          ? null
          : const Padding(
              padding: EdgeInsets.all(4),
              child: SoriLogo(width: 16, height: 16),
            ),
    );
  }
}

class _MiniPostViewData {
  const _MiniPostViewData({
    required this.avatarUrl,
    required this.categoryLabel,
    required this.timeLabel,
    required this.bodyText,
    required this.thumbnailUrl,
    required this.bodyLocked,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.badgeBorder,
  });

  final String? avatarUrl;
  final String categoryLabel;
  final String timeLabel;
  final String bodyText;
  final String? thumbnailUrl;
  final bool bodyLocked;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color badgeBorder;

  static _MiniPostViewData _fromBa(UnifiedFeedItem item) {
    final c = item.caseItem!;
    final mentoring = c.hasActiveMentoring;
    return _MiniPostViewData(
      avatarUrl: _firstNonEmpty([
        c.authorAvatarUrl,
        c.shop.profileImageUrl ?? '',
      ]),
      categoryLabel: mentoring ? '멘토링' : 'B/A',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: c.chart.metadataSummaryLine.ifEmpty(c.chart.concerns),
      thumbnailUrl: c.chart.afterImageUrl ?? c.chart.beforeImageUrl,
      bodyLocked: false,
      badgeBackground: mentoring
          ? const Color(0xFF312E81).withValues(alpha: 0.45)
          : SoriTokens.primarySoft,
      badgeForeground: mentoring ? const Color(0xFFC4B5FD) : SoriTokens.primary,
      badgeBorder: mentoring
          ? const Color(0xFF6366F1).withValues(alpha: 0.35)
          : SoriTokens.primary.withValues(alpha: 0.25),
    );
  }

  static _MiniPostViewData _fromSeminar(UnifiedFeedItem item) {
    final s = item.seminar!;
    return _MiniPostViewData(
      avatarUrl: null,
      categoryLabel: '세미나',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: s.title.trim().ifEmpty(s.description),
      thumbnailUrl:
          s.additionalImages.isNotEmpty ? s.additionalImages.first : null,
      bodyLocked: false,
      badgeBackground: const Color(0xFF1E3A5F).withValues(alpha: 0.55),
      badgeForeground: const Color(0xFF93C5FD),
      badgeBorder: const Color(0xFF3B82F6).withValues(alpha: 0.35),
    );
  }

  static _MiniPostViewData _fromWhisper(UnifiedFeedItem item) {
    final p = item.post!;
    final locked = p.isBodyLocked;
    return _MiniPostViewData(
      avatarUrl: p.shopAvatarUrl,
      categoryLabel: 'Whisper',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: locked
          ? '선택한 수신자에게만 공개된 Whisper입니다.'
          : p.body.trim().ifEmpty(p.title),
      thumbnailUrl: p.primaryImageUrl,
      bodyLocked: locked,
      badgeBackground: const Color(0xFF064E3B).withValues(alpha: 0.55),
      badgeForeground: SoriTokens.primary,
      badgeBorder: SoriTokens.primary.withValues(alpha: 0.35),
    );
  }

  static _MiniPostViewData _fromInterior(UnifiedFeedItem item) {
    final p = item.post!;
    return _MiniPostViewData(
      avatarUrl: p.shopAvatarUrl,
      categoryLabel: '샵 인테리어',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: p.title.trim().ifEmpty(p.body),
      thumbnailUrl: p.primaryImageUrl,
      bodyLocked: false,
      badgeBackground: SoriTokens.surfaceOverlay,
      badgeForeground: SoriTokens.textSecondary,
      badgeBorder: SoriTokens.border,
    );
  }

  static _MiniPostViewData _fromDeviceReview(UnifiedFeedItem item) {
    final p = item.post!;
    final name = p.deviceReview?.deviceName.trim() ?? '';
    return _MiniPostViewData(
      avatarUrl: p.shopAvatarUrl,
      categoryLabel: '기기리뷰',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: p.body.trim().ifEmpty(name.ifEmpty(p.title)),
      thumbnailUrl: p.primaryImageUrl,
      bodyLocked: p.isBodyLocked,
      badgeBackground: const Color(0xFF422006).withValues(alpha: 0.45),
      badgeForeground: const Color(0xFFFCD34D),
      badgeBorder: const Color(0xFFF59E0B).withValues(alpha: 0.35),
    );
  }

  static _MiniPostViewData _fromMarketplace(UnifiedFeedItem item) {
    final p = item.post!;
    final used = item.isMarketplaceUsed;
    final listing = p.listing;
    final price = listing != null ? '${listing.price}원 · ' : '';
    final device = listing?.deviceName.trim() ?? p.title.trim();
    return _MiniPostViewData(
      avatarUrl: p.shopAvatarUrl,
      categoryLabel: used ? '중고거래' : '제품리뷰',
      timeLabel: formatRelativeTime(item.sortAt),
      bodyText: '$price${p.body.trim().ifEmpty(device)}',
      thumbnailUrl: p.primaryImageUrl,
      bodyLocked: p.isBodyLocked,
      badgeBackground: used
          ? const Color(0xFF1C1917).withValues(alpha: 0.55)
          : const Color(0xFF14532D).withValues(alpha: 0.45),
      badgeForeground: used ? const Color(0xFFA8A29E) : SoriTokens.primary,
      badgeBorder: used
          ? SoriTokens.border
          : SoriTokens.primary.withValues(alpha: 0.35),
    );
  }

  factory _MiniPostViewData.fromItem(UnifiedFeedItem item) {
    return switch (item.kind) {
      UnifiedFeedKind.ba => _fromBa(item),
      UnifiedFeedKind.seminar => _fromSeminar(item),
      UnifiedFeedKind.whisper => _fromWhisper(item),
      UnifiedFeedKind.interior => _fromInterior(item),
      UnifiedFeedKind.deviceReview => _fromDeviceReview(item),
      UnifiedFeedKind.marketplace => _fromMarketplace(item),
    };
  }

  static String? _firstNonEmpty(List<String> values) {
    for (final raw in values) {
      final v = raw.trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }
}

extension _MiniPostStringExt on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
}
