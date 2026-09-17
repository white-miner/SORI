import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../widgets/before_after_slider.dart';
import 'ba_recall_cache.dart';

/// Full-screen BaRecall — warm ≤1s open + Customer Co-view masking (PRD v3.1-C).
///
/// Co-view ON: visit number + B/A photos only.
/// Masked: name, phone, internal notes, payment, care labels, chips.
Future<void> showBaRecallOverlay({
  required BuildContext context,
  required List<ChartBaThumb> thumbs,
  bool initiallyCoView = false,
  bool wasWarm = false,
}) {
  if (thumbs.isEmpty) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('과거 B/A'),
        content: const Text('비교할 촬영 사진이 아직 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'BaRecall',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) {
      return BaRecallOverlay(
        thumbs: thumbs,
        initiallyCoView: initiallyCoView,
        wasWarm: wasWarm,
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class BaRecallOverlay extends StatefulWidget {
  const BaRecallOverlay({
    super.key,
    required this.thumbs,
    this.initiallyCoView = false,
    this.wasWarm = false,
  });

  final List<ChartBaThumb> thumbs;
  final bool initiallyCoView;
  final bool wasWarm;

  @override
  State<BaRecallOverlay> createState() => _BaRecallOverlayState();
}

class _BaRecallOverlayState extends State<BaRecallOverlay> {
  late ChartBaThumb _left;
  late ChartBaThumb _right;
  late bool _coView;
  bool _useSlider = true;

  @override
  void initState() {
    super.initState();
    _coView = widget.initiallyCoView;
    _left = widget.thumbs.first;
    _right = widget.thumbs.length > 1 ? widget.thumbs.last : widget.thumbs.first;
  }

  String? _primaryUrl(ChartBaThumb t) {
    final after = t.afterUrl?.trim() ?? '';
    if (after.isNotEmpty) return after;
    final before = t.beforeUrl?.trim() ?? '';
    return before.isEmpty ? null : before;
  }

  String? _beforeUrl(ChartBaThumb t) {
    final b = t.beforeUrl?.trim() ?? '';
    return b.isEmpty ? null : b;
  }

  String? _afterUrl(ChartBaThumb t) {
    final a = t.afterUrl?.trim() ?? '';
    return a.isEmpty ? null : a;
  }

  @override
  Widget build(BuildContext context) {
    final leftBefore = _beforeUrl(_left) ?? _primaryUrl(_left);
    final rightAfter = _afterUrl(_right) ?? _primaryUrl(_right);
    final rightBefore = _beforeUrl(_right) ?? _primaryUrl(_right);

    // Prefer: left visit After vs right visit After when both sides have after.
    final compareLeft = _afterUrl(_left) ?? leftBefore;
    final compareRight = _afterUrl(_right) ?? rightAfter ?? rightBefore;

    return Material(
      color: const Color(0xFF0E0C10),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      _coView ? '경과 비교' : '과거 B/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!_coView && widget.wasWarm)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: VisitGlassTokens.sage.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '즉시',
                        style: TextStyle(
                          color: VisitGlassTokens.sage,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _CoViewToggle(
                    value: _coView,
                    onChanged: (v) => setState(() => _coView = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _VisitPicker(
                      label: _coView ? '왼쪽 회차' : '왼쪽',
                      selected: _left,
                      thumbs: widget.thumbs,
                      coView: _coView,
                      onChanged: (t) => setState(() => _left = t),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows_rounded,
                        color: Colors.white38),
                  ),
                  Expanded(
                    child: _VisitPicker(
                      label: _coView ? '오른쪽 회차' : '오른쪽',
                      selected: _right,
                      thumbs: widget.thumbs,
                      coView: _coView,
                      onChanged: (t) => setState(() => _right = t),
                    ),
                  ),
                ],
              ),
            ),
            if (!_coView)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('슬라이더'),
                      selected: _useSlider,
                      onSelected: (_) => setState(() => _useSlider = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('나란히'),
                      selected: !_useSlider,
                      onSelected: (_) => setState(() => _useSlider = false),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: _useSlider || _coView
                    ? _ComparePane(
                        leftUrl: compareLeft,
                        rightUrl: compareRight,
                        leftLabel: '${_left.visitNumber}회',
                        rightLabel: '${_right.visitNumber}회',
                        coView: _coView,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _SidePhoto(
                              url: compareLeft,
                              label: '${_left.visitNumber}회차'
                                  '${_left.careName.trim().isEmpty ? '' : ' · ${_left.careName}'}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SidePhoto(
                              url: compareRight,
                              label: '${_right.visitNumber}회차'
                                  '${_right.careName.trim().isEmpty ? '' : ' · ${_right.careName}'}',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_coView)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '고객에게 보이는 화면 · 회차와 사진만 표시됩니다',
                  textAlign: TextAlign.center,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: Colors.white38,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoViewToggle extends StatelessWidget {
  const _CoViewToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? VisitGlassTokens.care.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_outlined,
                size: 16,
                color: value ? VisitGlassTokens.care : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                value ? '고객에게 보여주기' : '원장 모드',
                style: TextStyle(
                  color: value ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitPicker extends StatelessWidget {
  const _VisitPicker({
    required this.label,
    required this.selected,
    required this.thumbs,
    required this.coView,
    required this.onChanged,
  });

  final String label;
  final ChartBaThumb selected;
  final List<ChartBaThumb> thumbs;
  final bool coView;
  final ValueChanged<ChartBaThumb> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selected.chartId,
          dropdownColor: const Color(0xFF1C1820),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            for (final t in thumbs)
              DropdownMenuItem(
                value: t.chartId,
                child: Text(
                  // Co-view: visit# only — no care name / PII.
                  coView
                      ? '${t.visitNumber}회차'
                      : '${t.visitNumber}회차'
                          '${t.careName.trim().isEmpty ? '' : ' · ${t.careName}'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            final match = thumbs.where((t) => t.chartId == id);
            if (match.isNotEmpty) onChanged(match.first);
          },
        ),
      ],
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({
    required this.leftUrl,
    required this.rightUrl,
    required this.leftLabel,
    required this.rightLabel,
    required this.coView,
  });

  final String? leftUrl;
  final String? rightUrl;
  final String leftLabel;
  final String rightLabel;
  final bool coView;

  @override
  Widget build(BuildContext context) {
    final left = leftUrl;
    final right = rightUrl;
    if (left == null || right == null) {
      return const Center(
        child: Text('사진이 부족해요', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: BeforeAfterSlider(
            before: _NetPhoto(url: left),
            after: _NetPhoto(url: right),
            aspectRatio: 3 / 4,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel,
                style: TextStyle(
                  color: coView ? Colors.white70 : VisitGlassTokens.care,
                  fontWeight: FontWeight.w700,
                )),
            Text(rightLabel,
                style: TextStyle(
                  color: coView ? Colors.white70 : VisitGlassTokens.sage,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ],
    );
  }
}

class _SidePhoto extends StatelessWidget {
  const _SidePhoto({required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: url == null
                ? Container(color: SoriTokens.border)
                : _NetPhoto(url: url!),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _NetPhoto extends StatelessWidget {
  const _NetPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(
        color: Color(0xFF1A1620),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VisitGlassTokens.care,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFF1A1620),
        child: Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );
  }
}
