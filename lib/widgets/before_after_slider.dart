import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Before/After 오버랩 비교 슬라이더 (터치 드래그).
class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 240,
  });

  final Widget before;
  final Widget after;
  final double height;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  /// 0.0 = 전부 Before, 1.0 = 전부 After 노출 비율(오른쪽 비율).
  double _ratio = 0.5;

  void _updateFromLocalDx(double dx, double width) {
    if (width <= 0) return;
    setState(() => _ratio = (dx / width).clamp(0.02, 0.98));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final split = w * _ratio;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              _updateFromLocalDx(d.localPosition.dx, w);
            },
            onTapDown: (d) => _updateFromLocalDx(d.localPosition.dx, w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // After (full)
                  widget.after,
                  // Before clipped to left
                  ClipRect(
                    clipper: _LeftClipper(split),
                    child: widget.before,
                  ),
                  // Divider handle
                  Positioned(
                    left: split - 18,
                    top: 0,
                    bottom: 0,
                    width: 36,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SoriTokens.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.code,
                          size: 18,
                          color: SoriTokens.primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: split - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const Positioned(
                    left: 10,
                    top: 10,
                    child: _CornerTag(label: 'Before'),
                  ),
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: _CornerTag(label: 'After'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.width != width;
}

class _CornerTag extends StatelessWidget {
  const _CornerTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// URL이 없거나 파일이면 플레이스홀더.
class ChartImagePane extends StatelessWidget {
  const ChartImagePane({
    super.key,
    required this.url,
    required this.fallbackLabel,
    required this.tone,
  });

  final String? url;
  final String fallbackLabel;
  final Color tone;

  bool get _isNetwork {
    final u = url?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: url!.trim(),
        fit: BoxFit.cover,
        memCacheWidth: 1200,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, _) => ColoredBox(
          color: tone.withValues(alpha: 0.12),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => _Placeholder(
          label: fallbackLabel,
          tone: tone,
        ),
      );
    }
    return _Placeholder(label: fallbackLabel, tone: tone);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tone.withValues(alpha: 0.14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 40, color: tone),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
