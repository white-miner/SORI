import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Official / Verified chip next to shop or author name.
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0x223B82F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x663B82F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: compact ? 11 : 12,
            color: const Color(0xFF60A5FA),
          ),
          SizedBox(width: compact ? 2 : 3),
          Text(
            '공식',
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF93C5FD),
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Name + optional Official badge row.
class ShopNameWithOfficialBadge extends StatelessWidget {
  const ShopNameWithOfficialBadge({
    super.key,
    required this.name,
    required this.isOfficial,
    this.style,
    this.compact = false,
  });

  final String name;
  final bool isOfficial;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name.trim().isEmpty ? 'SORI' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ??
                const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.2,
                  color: SoriTokens.textPrimary,
                ),
          ),
        ),
        if (isOfficial) ...[
          const SizedBox(width: 6),
          OfficialBadge(compact: compact),
        ],
      ],
    );
  }
}
