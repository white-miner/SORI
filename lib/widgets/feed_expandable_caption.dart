import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Feed body caption — max 2 lines + inline 「더보기」 with [AnimatedSize].
class FeedExpandableCaption extends StatefulWidget {
  const FeedExpandableCaption({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.style,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<FeedExpandableCaption> createState() => _FeedExpandableCaptionState();
}

class _FeedExpandableCaptionState extends State<FeedExpandableCaption> {
  bool _expanded = false;
  bool _overflows = false;

  TextStyle get _style =>
      widget.style ??
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: SoriTokens.textPrimary,
      );

  @override
  void didUpdateWidget(covariant FeedExpandableCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
      _overflows = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.text.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: raw, style: _style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = tp.didExceedMaxLines;
        if (overflows != _overflows) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _overflows = overflows);
          });
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raw,
                maxLines: _expanded ? null : widget.maxLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: _style,
              ),
              if (overflows || _expanded)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? '접기' : '더보기',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7DD3FC),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
