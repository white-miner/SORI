import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import '../utils/storage_image_url.dart';

/// Before/After 오버랩 비교 슬라이더 (터치 드래그).
class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 240,
    this.aspectRatio,
    this.maxHeight = 520,
    this.dragHandleOnly = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showCornerTags = true,
  });

  final Widget before;
  final Widget after;
  final double height;

  /// 설정 시 [height] 대신 가로 대비 비율로 높이를 계산한다. (예: 1.0, 4/5)
  final double? aspectRatio;
  final double maxHeight;

  /// true면 중앙 핸들만 드래그 (핀치 줌과 제스처 공존).
  final bool dragHandleOnly;

  /// 홈 피드 몰입형은 [BorderRadius.zero]로 각진 Edge-to-Edge.
  final BorderRadius borderRadius;

  /// false면 코너 태그를 그리지 않는다. 비교 뷰어는 줌 바깥에 고정 라벨을 둔다.
  final bool showCornerTags;

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

  Widget _buildHandle(double split, double width) {
    return Positioned(
      left: split - 22,
      top: 0,
      bottom: 0,
      width: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          _updateFromLocalDx(d.localPosition.dx + split - 22, width);
        },
        onTapDown: (d) {
          _updateFromLocalDx(d.localPosition.dx + split - 22, width);
        },
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: SoriTokens.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              size: 18,
              color: SoriTokens.primary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final ratio = widget.aspectRatio;
        final h = ratio != null && ratio > 0
            ? (w / ratio).clamp(180.0, widget.maxHeight)
            : widget.height;
        final split = w * _ratio;

        final stack = Stack(
          fit: StackFit.expand,
          children: [
            widget.after,
            ClipRect(clipper: _LeftClipper(split), child: widget.before),
            if (widget.dragHandleOnly)
              _buildHandle(split, w)
            else
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
                      border: Border.all(color: SoriTokens.primary, width: 2),
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
            if (widget.showCornerTags) ...[
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
          ],
        );

        final clipped = ClipRRect(
          borderRadius: widget.borderRadius,
          child: stack,
        );

        if (widget.dragHandleOnly) {
          return SizedBox(
            height: h.isFinite ? h : null,
            width: double.infinity,
            child: clipped,
          );
        }

        return SizedBox(
          height: h,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              _updateFromLocalDx(d.localPosition.dx, w);
            },
            onTapDown: (d) => _updateFromLocalDx(d.localPosition.dx, w),
            child: clipped,
          ),
        );
      },
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

/// URL이 없거나 로드 실패 시 플레이스홀더. 웹은 [Image.network]로 CORS 호환.
class ChartImagePane extends StatelessWidget {
  const ChartImagePane({
    super.key,
    required this.url,
    required this.fallbackLabel,
    required this.tone,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String fallbackLabel;
  final Color tone;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolved = StorageImageUrl.resolve(url);
    if (resolved == null || !StorageImageUrl.isNetworkUrl(resolved)) {
      if ((url?.trim() ?? '').isNotEmpty) {
        debugPrint(
          'ChartImagePane[$fallbackLabel]: invalid/empty URL raw="$url"',
        );
      }
      return _Placeholder(label: fallbackLabel, tone: tone);
    }

    return Image.network(
      resolved,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      // Request-side CORS header는 무효(응답 헤더). 웹은 브라우저 기본 fetch 사용.
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: tone.withValues(alpha: 0.12),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'ChartImagePane[$fallbackLabel]: load failed url=$resolved '
          'error=$error'
          '${kIsWeb ? ' (check Supabase Storage CORS / 403)' : ''}',
        );
        return _Placeholder(
          label: '$fallbackLabel 로드 실패',
          tone: tone,
          icon: Icons.broken_image_outlined,
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.label,
    required this.tone,
    this.icon = Icons.photo_outlined,
  });

  final String label;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tone.withValues(alpha: 0.14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 88 || constraints.maxWidth < 88;
          if (tight) {
            return Center(
              child: Icon(
                icon,
                size: (constraints.biggest.shortestSide * 0.36).clamp(12, 22),
                color: tone,
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: tone),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: tone),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
