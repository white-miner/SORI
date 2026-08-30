import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../sori_network_image.dart';

/// Explore tab — Naver-style rich overlay card (image + scrim + metadata).
class ExploreRichInfoCard extends StatelessWidget {
  const ExploreRichInfoCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String authorName;
  final String authorAvatarUrl;
  final VoidCallback onTap;

  static const double borderRadius = 16;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: SoriTokens.surfaceOverlay,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                SoriNetworkImage(url: imageUrl, fit: BoxFit.cover)
              else
                const ColoredBox(color: SoriTokens.surfaceOverlay),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              height: 1.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.white24,
                              backgroundImage: authorAvatarUrl.isNotEmpty
                                  ? NetworkImage(authorAvatarUrl)
                                  : null,
                              child: authorAvatarUrl.isEmpty
                                  ? Text(
                                      authorName.isNotEmpty
                                          ? authorName.characters.first
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
