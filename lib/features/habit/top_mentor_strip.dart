import 'package:flutter/material.dart';

import '../../models/subscription.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';

/// Top Mentor strip — discover directors with online ring (PRD v3.1).
class TopMentorStrip extends StatelessWidget {
  const TopMentorStrip({
    super.key,
    required this.store,
    this.onDirectorTap,
  });

  final SoriStore store;
  final void Function(DiscoverDirector director)? onDirectorTap;

  @override
  Widget build(BuildContext context) {
    final mentors = store.discoverDirectors
        .where((d) => d.shopId != store.shop.id)
        .take(10)
        .toList();

    if (mentors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            'Top Mentor',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mentors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final m = mentors[index];
              return _MentorAvatar(
                director: m,
                onTap: onDirectorTap == null ? null : () => onDirectorTap!(m),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  const _MentorAvatar({
    required this.director,
    this.onTap,
  });

  final DiscoverDirector director;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final online = director.isOnline;
    final specialty = director.bio.trim().isNotEmpty
        ? director.bio.trim()
        : (director.line2.isNotEmpty ? director.line2 : '멘토링');

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: online
                    ? LinearGradient(
                        colors: [
                          VisitGlassTokens.sage,
                          VisitGlassTokens.care,
                        ],
                      )
                    : null,
                border: online
                    ? null
                    : Border.all(
                        color: SoriTokens.border.withValues(alpha: 0.5),
                      ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: VisitGlassTokens.care.withValues(alpha: 0.12),
                backgroundImage: director.avatarUrl.trim().isNotEmpty
                    ? NetworkImage(director.avatarUrl.trim())
                    : null,
                child: director.avatarUrl.trim().isEmpty
                    ? Text(
                        director.nickname.characters.first,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              director.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textPrimary,
              ),
            ),
            Text(
              specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: SoriTokens.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
