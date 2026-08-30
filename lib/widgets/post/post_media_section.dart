import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../before_after_slider.dart';
import '../feed_media_carousel.dart';
import 'ba_slider_scroll_shield.dart';
import 'full_screen_image_overlay.dart';

/// Post media block — B/A slider with scroll shield + expand overlay trigger.
class PostMediaSection extends StatelessWidget {
  const PostMediaSection({
    super.key,
    required this.slides,
    this.maxHeight = 380,
    this.aspectRatio = 4 / 3,
    this.heroTag,
    this.onOpenDetail,
    this.compact = false,
  });

  final List<FeedMediaSlide> slides;
  final double maxHeight;
  final double aspectRatio;
  final String? heroTag;
  final VoidCallback? onOpenDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) return const SizedBox.shrink();

    return BaSliderScrollShield(
      child: FeedMediaCarousel(
        slides: slides,
        aspectRatio: aspectRatio,
        maxHeight: compact ? 120 : maxHeight,
        heroTag: heroTag,
        onTap: () => FullScreenImageOverlay.show(context, slides: slides),
        onDoubleTap: onOpenDetail,
      ),
    );
  }
}

/// Mini-tier thumbnail (left) with optional pager dots styling.
class PostMiniThumbnail extends StatelessWidget {
  const PostMiniThumbnail({
    super.key,
    required this.slides,
    this.size = 72,
  });

  final List<FeedMediaSlide> slides;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) return const SizedBox.shrink();
    final slide = slides.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (slide.isBaPair)
              BeforeAfterMiniThumb(
                beforeUrl: slide.beforeUrl,
                afterUrl: slide.afterUrl,
              )
            else
              ChartImagePane(
                url: slide.url,
                fallbackLabel: '',
                tone: SoriTokens.surfaceOverlay,
              ),
            if (slides.length > 1)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    slides.length.clamp(0, 5),
                    (i) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: i == 0 ? 0.95 : 0.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BeforeAfterMiniThumb extends StatelessWidget {
  const BeforeAfterMiniThumb({
    super.key,
    this.beforeUrl,
    this.afterUrl,
  });

  final String? beforeUrl;
  final String? afterUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ChartImagePane(
          url: afterUrl,
          fallbackLabel: '',
          tone: SoriTokens.surfaceOverlay,
        ),
        Align(
          alignment: Alignment.centerLeft,
          widthFactor: 0.5,
          child: ChartImagePane(
            url: beforeUrl,
            fallbackLabel: '',
            tone: SoriTokens.primary,
          ),
        ),
      ],
    );
  }
}
