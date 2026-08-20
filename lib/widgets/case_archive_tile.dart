import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../pages/case_detail_page.dart';
import '../theme/sori_tokens.dart';
import '../utils/case_persona.dart';
import '../utils/storage_image_url.dart';

/// 고밀도 가로형 케이스 타일 (높이 ~120px, 썸네일 100x100).
class CaseArchiveTile extends StatelessWidget {
  const CaseArchiveTile({
    super.key,
    required this.chart,
    this.customer,
    this.likeCount = 0,
    this.liked = false,
    this.bookmarked = false,
    this.showShareSwitch = false,
    this.onTap,
    this.onLike,
    this.onBookmark,
    this.onShareChanged,
    this.feedAge,
    this.feedGenderLabel,
  });

  final CustomerChart chart;
  final Customer? customer;
  final int? feedAge;
  final String? feedGenderLabel;
  final int likeCount;
  final bool liked;
  final bool bookmarked;
  final bool showShareSwitch;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final ValueChanged<bool>? onShareChanged;

  String get _demoLine => CasePersona.feedLine(
        chart: chart,
        age: feedAge ?? chart.age,
        genderLabel: feedGenderLabel ?? chart.gender,
        customer: customer,
      );

  @override
  Widget build(BuildContext context) {
    final care =
        chart.careName.trim().isEmpty ? '관리 케이스' : chart.careName.trim();
    final demo = _demoLine;
    final device = chart.deviceInfo?.trim() ?? '';
    final tags = chart.careTags
        .map((t) => t.replaceFirst('#', '').trim())
        .where((t) => t.isNotEmpty)
        .map((t) => '#$t')
        .toList();
    final shared = chart.caseShared && chart.isConsentSigned;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E4F8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BaThumb(
                heroTag: CaseDetailPage.imageHeroTag(chart.id),
                beforeUrl: chart.beforeImageUrl,
                afterUrl: chart.afterImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      care,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (demo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        demo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (device.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$device 사용',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        tags.join('  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.primary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (showShareSwitch)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch.adaptive(
                      value: shared,
                      activeThumbColor: const Color(0xFF22C55E),
                      onChanged: onShareChanged,
                    ),
                    Text(
                      shared ? '공개' : '비공개',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: shared
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            children: [
                              Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: liked
                                    ? const Color(0xFFE11D48)
                                    : Colors.grey.shade600,
                              ),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: onBookmark,
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: bookmarked
                              ? SoriTokens.primary
                              : Colors.grey.shade600,
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

class _BaThumb extends StatelessWidget {
  const _BaThumb({
    required this.heroTag,
    this.beforeUrl,
    this.afterUrl,
  });
  final String heroTag;
  final String? beforeUrl;
  final String? afterUrl;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Row(
              children: [
                Expanded(
                  child: _Shot(url: beforeUrl, fallback: Icons.image_outlined),
                ),
                Expanded(
                  child: _Shot(url: afterUrl, fallback: Icons.auto_awesome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shot extends StatelessWidget {
  const _Shot({this.url, required this.fallback});
  final String? url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final src = StorageImageUrl.resolve(url);
    if (src == null || !StorageImageUrl.isNetworkUrl(src)) {
      return ColoredBox(
        color: const Color(0xFFF3F0FA),
        child: Icon(fallback, size: 18, color: SoriTokens.primary),
      );
    }
    return Image.network(
      src,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFFF3F0FA),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('CaseArchiveThumb: load failed url=$src error=$error');
        return ColoredBox(
          color: const Color(0xFFF3F0FA),
          child: Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: SoriTokens.primary,
          ),
        );
      },
    );
  }
}
