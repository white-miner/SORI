import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'whisper_post_card.dart';

/// Home feed wrapper for public Whisper posts.
class HomeWhisperFeedCard extends StatelessWidget {
  const HomeWhisperFeedCard({
    super.key,
    required this.post,
    required this.store,
    this.onTap,
  });

  final CommunityPost post;
  final SoriStore store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: SoriTokens.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  '전체 공개 Whisper',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          WhisperPostCard(
            post: post,
            store: store,
            compact: true,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
