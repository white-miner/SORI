import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../before_after_slider.dart';
import '../feed_media_carousel.dart';
import 'ba_slider_scroll_shield.dart';

/// Symmetric inset around the centered media — top/bottom/left/right equal.
const double kFullScreenOverlayInset = 24.0;

/// Full-screen blurred overlay — B/A slider remains interactive.
class FullScreenImageOverlay {
  static Future<void> show(
    BuildContext context, {
    required List<FeedMediaSlide> slides,
    int initialIndex = 0,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, _) {
        return _FullScreenImageOverlayBody(
          slides: slides,
          initialIndex: initialIndex,
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}

class _FullScreenImageOverlayBody extends StatefulWidget {
  const _FullScreenImageOverlayBody({
    required this.slides,
    required this.initialIndex,
  });

  final List<FeedMediaSlide> slides;
  final int initialIndex;

  @override
  State<_FullScreenImageOverlayBody> createState() =>
      _FullScreenImageOverlayBodyState();
}

class _FullScreenImageOverlayBodyState extends State<_FullScreenImageOverlayBody> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.slides.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_index];
    final screen = MediaQuery.sizeOf(context);
    final insetBox = screen.shortestSide - (kFullScreenOverlayInset * 2);
    final maxMediaHeight = insetBox.clamp(120.0, screen.height * 0.85);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(kFullScreenOverlayInset),
              child: BaSliderScrollShield(
                child: slide.isBaPair
                    ? BeforeAfterSlider(
                        aspectRatio: 3 / 4,
                        maxHeight: maxMediaHeight,
                        borderRadius: BorderRadius.circular(16),
                        before: ChartImagePane(
                          url: slide.beforeUrl,
                          fallbackLabel: 'Before',
                          tone: SoriTokens.primary,
                        ),
                        after: ChartImagePane(
                          url: slide.afterUrl,
                          fallbackLabel: 'After',
                          tone: SoriTokens.textSecondary,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ChartImagePane(
                          url: slide.url,
                          fallbackLabel: 'Photo',
                          tone: SoriTokens.textSecondary,
                        ),
                      ),
              ),
            ),
          ),
          if (widget.slides.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: kFullScreenOverlayInset,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.slides.length, (i) {
                  final active = i == _index;
                  return GestureDetector(
                    onTap: () => setState(() => _index = i),
                    child: Container(
                      width: active ? 8 : 6,
                      height: active ? 8 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: active ? 0.95 : 0.35,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
