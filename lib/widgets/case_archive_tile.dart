import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';

/// 고밀도 가로형 케이스 아카이브 타일 (높이 ~108px).
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
  });

  final CustomerChart chart;
  final Customer? customer;
  final int likeCount;
  final bool liked;
  final bool bookmarked;
  final bool showShareSwitch;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final ValueChanged<bool>? onShareChanged;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.trim().isEmpty ? '관리 케이스' : chart.careName.trim();
    final age = customer?.koreanAge;
    final gender = customer?.gender?.label;
    final demo = [
      if (age != null) '만 $age세',
      if (gender != null) gender,
    ].join(' · ');
    final device = chart.deviceInfo?.trim() ?? '';
    final tag = chart.careTags.isNotEmpty ? '#${chart.careTags.first}' : '';
    final shared = chart.caseShared && chart.isConsentSigned;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 108,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E4F8)),
          ),
          child: Row(
            children: [
              _BaThumb(
                beforeUrl: chart.beforeImageUrl,
                afterUrl: chart.afterImageUrl,
              ),
              const SizedBox(width: 10),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (demo.isNotEmpty) _MiniBadge(demo),
                        if (device.isNotEmpty)
                          _MiniBadge(device, icon: Icons.precision_manufacturing_outlined),
                        if (tag.isNotEmpty)
                          _MiniBadge(tag, tint: SoriTokens.primarySoft),
                      ],
                    ),
                  ],
                ),
              ),
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
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            Icon(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
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
                    InkWell(
                      onTap: onBookmark,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                          color: bookmarked
                              ? SoriTokens.primary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaThumb extends StatelessWidget {
  const _BaThumb({this.beforeUrl, this.afterUrl});
  final String? beforeUrl;
  final String? afterUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Row(
          children: [
            Expanded(child: _Shot(url: beforeUrl, fallback: Icons.image_outlined)),
            Expanded(child: _Shot(url: afterUrl, fallback: Icons.auto_awesome)),
          ],
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
    final src = url?.trim() ?? '';
    if (src.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF3F0FA),
        child: Icon(fallback, size: 16, color: SoriTokens.primary),
      );
    }
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: const Color(0xFFF3F0FA),
        child: Icon(fallback, size: 16, color: SoriTokens.primary),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.text, {this.icon, this.tint});
  final String text;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tint ?? const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.grey.shade700),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
