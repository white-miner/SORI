import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'before_after_slider.dart';
import 'sori_network_image.dart';

/// Naver-style horizontal media carousel with top-right `2/5` pill.
class FeedMediaCarousel extends StatefulWidget {
  const FeedMediaCarousel({
    super.key,
    required this.slides,
    this.aspectRatio = 4 / 3,
    this.maxHeight = 380,
    this.onTap,
    this.onDoubleTap,
    this.heroTag,
    this.topTrailing,
  });

  final List<FeedMediaSlide> slides;
  final double aspectRatio;
  final double maxHeight;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? heroTag;

  /// Extra overlay (e.g. Sponsored) — placed left of page pill when both exist.
  final Widget? topTrailing;

  @override
  State<FeedMediaCarousel> createState() => _FeedMediaCarouselState();
}

class FeedMediaSlide {
  const FeedMediaSlide.image({
    required this.url,
    this.label = '',
  }) : isBaPair = false,
       beforeUrl = null,
       afterUrl = null;

  const FeedMediaSlide.baPair({
    required this.beforeUrl,
    required this.afterUrl,
  })  : isBaPair = true,
        url = null,
        label = 'B/A';

  final bool isBaPair;
  final String? url;
  final String? beforeUrl;
  final String? afterUrl;
  final String label;
}

class _FeedMediaCarouselState extends State<FeedMediaCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final media = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Material(
          color: const Color(0xFF111113),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _buildSlide(slides[i]),
              ),
              if (slides.length > 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _PagePill(
                    current: _index + 1,
                    total: slides.length,
                  ),
                ),
              if (widget.topTrailing != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: widget.topTrailing!,
                ),
              if (slides.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) {
                      final active = i == _index;
                      return Container(
                        width: active ? 6 : 5,
                        height: active ? 6 : 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: active ? 0.95 : 0.35,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final tappable = GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: media,
    );

    final tag = widget.heroTag?.trim() ?? '';
    if (tag.isEmpty) return tappable;
    return Hero(
      tag: tag,
      child: tappable,
    );
  }

  Widget _buildSlide(FeedMediaSlide slide) {
    if (slide.isBaPair) {
      return BeforeAfterSlider(
        aspectRatio: widget.aspectRatio,
        maxHeight: widget.maxHeight,
        borderRadius: BorderRadius.zero,
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
      );
    }
    final url = slide.url?.trim() ?? '';
    if (url.isEmpty) {
      return ColoredBox(
        color: const Color(0xFF111113),
        child: Center(
          child: Text(
            slide.label.isEmpty ? '이미지' : slide.label,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: SoriNetworkImage(
        url: url,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  const _PagePill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = total > 5 && current >= 5
        ? '$current/5+'
        : '$current/$total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Build default case slides: Before, After (Naver-style swipe).
List<FeedMediaSlide> feedSlidesForCase({
  String? beforeUrl,
  String? afterUrl,
}) {
  final out = <FeedMediaSlide>[];
  final b = beforeUrl?.trim() ?? '';
  final a = afterUrl?.trim() ?? '';
  if (b.isNotEmpty) {
    out.add(FeedMediaSlide.image(url: b, label: 'Before'));
  }
  if (a.isNotEmpty) {
    out.add(FeedMediaSlide.image(url: a, label: 'After'));
  }
  return out;
}
