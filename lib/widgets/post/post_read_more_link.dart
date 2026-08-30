import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// Inline read-more control for truncated post captions.
class PostReadMoreLink extends StatelessWidget {
  const PostReadMoreLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '더 보기',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: SoriTokens.accentLink,
            ),
          ),
        ),
      ),
    );
  }
}
