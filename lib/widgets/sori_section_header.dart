import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Weverse-like section header — short large title + optional trailing `>` action.
///
/// Body fields rhythm: hero → [SoriSectionHeader] → thin chips → large-radius cards.
class SoriSectionHeader extends StatelessWidget {
  const SoriSectionHeader({
    super.key,
    required this.title,
    this.onTrailing,
    this.trailingTooltip,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 0),
    this.fontSize = SoriTokens.typeSection,
  });

  final String title;
  final VoidCallback? onTrailing;
  final String? trailingTooltip;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.2,
        color: SoriTokens.textPrimary,
      ),
    );

    if (onTrailing == null) {
      return Padding(padding: padding, child: titleText);
    }

    final action = IconButton(
      tooltip: trailingTooltip,
      onPressed: onTrailing,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: SoriTokens.textTertiary,
      ),
    );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: titleText),
          action,
        ],
      ),
    );
  }
}
