import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../before_after_slider.dart';
import '../feed_media_carousel.dart';
import 'ba_slider_scroll_shield.dart';

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
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: BaSliderScrollShield(
                      child: slide.isBaPair
                          ? BeforeAfterSlider(
                              aspectRatio: 3 / 4,
                              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
