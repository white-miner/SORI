import 'package:flutter/material.dart';

import '../../services/region_content_bookmark_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/sori_bottom_sheet.dart';
import '../../widgets/sori_action_buttons.dart';
import 'region_map_bloom.dart';
import 'region_map_content_pins.dart';

enum RegionMapContentFilter { all, post, seminar }

enum RegionMapSheetMode { hidden, markerPeek, clusterHalf, savedHalf }

/// 지도 하단 standard sheet — Peek 0.22 / Half 0.50 / Expanded 0.70.
/// sheet drag는 부모 MapCanvas를 rebuild하지 않도록 [NotificationListener]만 사용.
class RegionMapExploreSheet extends StatelessWidget {
  const RegionMapExploreSheet({
    super.key,
    required this.sheetController,
    required this.mode,
    required this.filter,
    required this.onFilterChanged,
    required this.onClose,
    this.selectedPin,
    this.clusterPins = const [],
    this.clusterTitle,
    this.savedPreview = const [],
    this.titleForBookmark,
    this.onOpenPin,
    this.onOpenSavedAll,
    this.onOpenBookmark,
  });

  final DraggableScrollableController sheetController;
  final RegionMapSheetMode mode;
  final RegionMapContentFilter filter;
  final ValueChanged<RegionMapContentFilter> onFilterChanged;
  final VoidCallback onClose;
  final RegionMapPin? selectedPin;
  final List<RegionMapPin> clusterPins;
  final String? clusterTitle;
  final List<RegionContentBookmark> savedPreview;
  final String Function(RegionContentBookmark)? titleForBookmark;
  final ValueChanged<RegionMapPin>? onOpenPin;
  final VoidCallback? onOpenSavedAll;
  final ValueChanged<RegionContentBookmark>? onOpenBookmark;

  static const peek = 0.22;
  static const half = 0.50;
  static const expanded = 0.70;

  bool get _visible => mode != RegionMapSheetMode.hidden;

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    final initial = mode == RegionMapSheetMode.markerPeek ? peek : half;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (_) => true, // 상위로 전파해 map rebuild 유발 금지 의도(흡수)
      child: DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: initial,
        minChildSize: peek,
        maxChildSize: expanded,
        snap: true,
        snapSizes: const [peek, half, expanded],
        builder: (context, scrollController) {
          return Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  // Half/Expanded: opaque cream (blur 없음 · 가독성·GPU).
                  // Peek도 지도 위 대비를 위해 실 BackdropFilter 없이 높은 alpha.
                  color: RegionMapBloom.sheetCream.withValues(
                    alpha: mode == RegionMapSheetMode.markerPeek ? 0.90 : 0.94,
                  ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(color: SoriTokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _Handle(onClose: onClose)),
                  if (mode != RegionMapSheetMode.savedHalf)
                    SliverToBoxAdapter(
                      child: _FilterRow(
                        filter: filter,
                        onChanged: onFilterChanged,
                      ),
                    ),
                  if (mode == RegionMapSheetMode.markerPeek &&
                      selectedPin != null)
                    ..._peekSlivers(context, selectedPin!)
                  else if (mode == RegionMapSheetMode.clusterHalf)
                    ..._listSlivers(
                      context,
                      title: clusterTitle ??
                          '이 지역의 이야기 ${clusterPins.length}개',
                      pins: clusterPins,
                    )
                  else if (mode == RegionMapSheetMode.savedHalf)
                    ..._savedSlivers(context),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: soriSheetBottomPadding(context) + 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _peekSlivers(BuildContext context, RegionMapPin pin) {
    final isPost = pin.kind == RegionMapPinKind.post;
    final kindLabel = isPost ? '커뮤니티 글' : '세미나';
    final cta = isPost ? '게시물 보기' : '세미나 보기';
    final accent = isPost ? RegionMapBloom.post : RegionMapBloom.seminar;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isPost ? Icons.chat_bubble_rounded : Icons.event_rounded,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    kindLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pin.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '우리 동네',
                style: TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SoriPrimaryButton(
                label: cta,
                onPressed: () => onOpenPin?.call(pin),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _listSlivers(
    BuildContext context, {
    required String title,
    required List<RegionMapPin> pins,
  }) {
    final shown = pins.take(4).toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final pin = shown[i];
            final isPost = pin.kind == RegionMapPinKind.post;
            return ListTile(
              leading: Icon(
                isPost ? Icons.chat_bubble_outline : Icons.event_outlined,
                color: isPost ? RegionMapBloom.post : RegionMapBloom.seminar,
              ),
              title: Text(
                pin.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(isPost ? '글' : '세미나'),
              onTap: () => onOpenPin?.call(pin),
            );
          },
          childCount: shown.length,
        ),
      ),
      if (pins.length > 4)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '외 ${pins.length - 4}개 · 지도를 확대해 더 볼 수 있어요',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _savedSlivers(BuildContext context) {
    final items = savedPreview;
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '저장한 지역 콘텐츠',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      if (items.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              '저장한 글과 세미나가 여기에 모여요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SoriTokens.textSecondary),
            ),
          ),
        )
      else ...[
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final b = items[i];
              final title = titleForBookmark?.call(b) ?? '저장 항목';
              final isPost = b.kind == RegionContentKind.post;
              return ListTile(
                leading: Icon(
                  isPost ? Icons.article_outlined : Icons.event_outlined,
                  color: SoriTokens.brand,
                ),
                title: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(isPost ? '글' : '세미나'),
                onTap: () => onOpenBookmark?.call(b),
              );
            },
            childCount: items.length.clamp(0, 3),
          ),
        ),
        if (onOpenSavedAll != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton(
                onPressed: onOpenSavedAll,
                child: const Text(
                  '전체 보기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    ];
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '목록 높이 조절',
      child: InkWell(
        onTap: onClose,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});
  final RegionMapContentFilter filter;
  final ValueChanged<RegionMapContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(RegionMapContentFilter f, String label) {
      final selected = filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onChanged(f),
          selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip(RegionMapContentFilter.all, '전체'),
          chip(RegionMapContentFilter.post, '글'),
          chip(RegionMapContentFilter.seminar, '세미나'),
        ],
      ),
    );
  }
}
