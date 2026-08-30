import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// iOS-style link blue — explicit affordance for read-more taps.
const Color kPostReadMoreBlue = Color(0xFF007AFF);

const String kPostReadMoreLabel = '더 보기';

/// Right inset so inline "더 보기" is never clipped by card/carousel edges.
const double kPostReadMoreRightPadding = 12.0;

const TextStyle kPostReadMoreSpanStyle = TextStyle(
  color: kPostReadMoreBlue,
  fontWeight: FontWeight.bold,
);

/// Truncated caption with body + inline blue bold [kPostReadMoreLabel] via [TextSpan].
class PostTruncatedCaption extends StatefulWidget {
  const PostTruncatedCaption({
    super.key,
    required this.text,
    required this.onReadMore,
    this.maxLines = 3,
    this.bodyStyle,
  });

  final String text;
  final VoidCallback onReadMore;
  final int maxLines;
  final TextStyle? bodyStyle;

  @override
  State<PostTruncatedCaption> createState() => _PostTruncatedCaptionState();
}

class _PostTruncatedCaptionState extends State<PostTruncatedCaption> {
  TapGestureRecognizer? _readMoreRecognizer;

  @override
  void didUpdateWidget(covariant PostTruncatedCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    _readMoreRecognizer?.onTap = widget.onReadMore;
  }

  @override
  void dispose() {
    _readMoreRecognizer?.dispose();
    super.dispose();
  }

  TextStyle get _bodyStyle =>
      widget.bodyStyle ??
      const TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w400,
        color: SoriTokens.textPrimary,
      );

  TextStyle get _linkStyle => _bodyStyle.merge(kPostReadMoreSpanStyle).copyWith(
        color: kPostReadMoreBlue,
        fontWeight: FontWeight.bold,
      );

  @override
  Widget build(BuildContext context) {
    final raw = widget.text.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(raw, style: _bodyStyle, maxLines: widget.maxLines);
        }

        final layoutWidth = (maxWidth - kPostReadMoreRightPadding).clamp(0.0, maxWidth);

        final overflowProbe = TextPainter(
          text: TextSpan(text: raw, style: _bodyStyle),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: layoutWidth);

        if (!_textExceedsLines(overflowProbe, layoutWidth, widget.maxLines)) {
          return Padding(
            padding: const EdgeInsets.only(right: kPostReadMoreRightPadding),
            child: Text(
              raw,
              style: _bodyStyle,
              maxLines: widget.maxLines,
            ),
          );
        }

        _readMoreRecognizer ??= TapGestureRecognizer()..onTap = widget.onReadMore;

        final linkSpan = TextSpan(
          text: ' $kPostReadMoreLabel',
          style: _linkStyle,
          recognizer: _readMoreRecognizer,
        );

        final visible = _truncateToFit(
          raw,
          _bodyStyle,
          linkSpan,
          layoutWidth,
          widget.maxLines,
        );

        return Padding(
          padding: const EdgeInsets.only(right: kPostReadMoreRightPadding),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$visible…', style: _bodyStyle),
                linkSpan,
              ],
            ),
            maxLines: widget.maxLines,
            overflow: TextOverflow.clip,
          ),
        );
      },
    );
  }

  static bool _textExceedsLines(
    TextPainter painter,
    double maxWidth,
    int maxLines,
  ) {
    if (painter.didExceedMaxLines) return true;
    final metrics = painter.computeLineMetrics();
    if (metrics.length > maxLines) return true;
    if (metrics.isEmpty) return false;
    return metrics.last.width > maxWidth + 0.5;
  }

  static String _truncateToFit(
    String text,
    TextStyle bodyStyle,
    InlineSpan suffix,
    double maxWidth,
    int maxLines,
  ) {
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final candidate = text.substring(0, mid).trimRight();
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '$candidate…', style: bodyStyle),
            suffix,
          ],
        ),
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (!_textExceedsLines(painter, maxWidth, maxLines)) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    if (low == 0) return text.substring(0, 1);
    return text.substring(0, low).trimRight();
  }
}
