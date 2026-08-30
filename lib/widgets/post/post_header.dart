import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../animated_booster_avatar.dart';
import '../official_badge.dart';
import '../sori_logo.dart';
import 'post_view_data.dart';

/// Shared post header — avatar, author, community path, time, hot + menu.
class PostHeader extends StatelessWidget {
  const PostHeader({
    super.key,
    required this.data,
    this.onAvatarTap,
    this.onMore,
    this.dense = false,
  });

  final PostViewData data;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMore;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = dense ? 14.0 : 18.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, dense ? 8 : 10, 4, dense ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: data.isBoosted && !dense
                ? AnimatedBoosterAvatar(
                    imageUrl: data.avatarUrl ?? '',
                    isBoosted: data.isBoosted,
                    radius: avatarRadius,
                  )
                : _PlainAvatar(url: data.avatarUrl, radius: avatarRadius),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: dense ? 13 : 14,
                          color: SoriTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (data.caseItem?.shop.displayIsOfficial == true) ...[
                      const SizedBox(width: 4),
                      const OfficialBadge(compact: true),
                    ],
                    if (data.communityLabel != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: dense ? 14 : 16,
                        color: SoriTokens.textTertiary,
                      ),
                      Flexible(
                        child: Text(
                          data.communityLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Text(
                      data.timeLabel,
                      style: TextStyle(
                        fontSize: dense ? 10.5 : 11.5,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (data.affiliation.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.affiliation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: dense ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (data.isBoosted)
            Padding(
              padding: const EdgeInsets.only(right: 2, top: 2),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: dense ? 18 : 20,
                color: SoriTokens.warningText,
              ),
            ),
          IconButton(
            onPressed: onMore,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: dense ? 32 : 36,
              minHeight: dense ? 32 : 36,
            ),
            icon: Icon(
              Icons.more_vert_rounded,
              size: dense ? 18 : 20,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainAvatar extends StatelessWidget {
  const _PlainAvatar({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    final valid = u.isNotEmpty && !u.startsWith('data:');
    return CircleAvatar(
      radius: radius,
      backgroundColor: SoriTokens.primarySoft,
      backgroundImage: valid ? NetworkImage(u) : null,
      child: valid
          ? null
          : Padding(
              padding: EdgeInsets.all(radius * 0.28),
              child: SoriLogo(width: radius, height: radius),
            ),
    );
  }
}
