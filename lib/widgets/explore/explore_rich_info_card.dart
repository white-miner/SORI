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
    this.categoryLabel,
    this.textOnly = false,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String authorName;
  final String authorAvatarUrl;
  final VoidCallback onTap;
  final String? categoryLabel;
  final bool textOnly;

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
              else if (textOnly)
                ColoredBox(
                  color: SoriTokens.surfaceOverlay,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const ColoredBox(color: SoriTokens.surfaceOverlay),
              if (categoryLabel != null && categoryLabel!.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Text(
                        categoryLabel!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
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
