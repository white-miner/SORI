import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'sori_glass_chip.dart';
import 'sori_glass_tokens.dart';

/// L2 send / FAB chip — accent link, never solid black fill.
class SoriGlassFab extends StatelessWidget {
  const SoriGlassFab({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.send_rounded,
    this.tooltip = '전송',
    this.size = SoriGlassTokens.chipMd,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SoriGlassChip(
      icon: icon,
      semantic: SoriGlassSemantic.comment,
      active: true,
      loading: loading,
      size: size,
      tooltip: tooltip,
      onTap: onPressed,
    );
  }
}

/// Glass-styled text input bar with trailing send chip.
class SoriGlassInputBar extends StatelessWidget {
  const SoriGlassInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hint = '댓글을 입력하세요',
    this.sending = false,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;
  final bool sending;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: SoriTokens.outlinePurple.withValues(alpha: 0.45),
      ),
    );

    return DecoratedBox(
      decoration: SoriGlassTokens.dockTrayDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: maxLines,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: SoriTokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: SoriTokens.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.55),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(
                      color: SoriTokens.accentLink,
                      width: 1.2,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            SoriGlassFab(onPressed: sending ? null : onSend, loading: sending),
          ],
        ),
      ),
    );
  }
}
