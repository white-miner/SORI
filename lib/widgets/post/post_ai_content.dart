import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'post_view_data.dart';

/// Conditional AI summary — collapsed when no content per PO rules.
class PostAiContent extends StatelessWidget {
  const PostAiContent({
    super.key,
    required this.data,
    this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 8),
  });

  final PostViewData data;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final summary = data.resolveAiSummary();
    if (summary == null || summary.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: SoriTokens.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: SoriTokens.primary),
                  SizedBox(width: 6),
                  Text(
                    'AI 설명',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
