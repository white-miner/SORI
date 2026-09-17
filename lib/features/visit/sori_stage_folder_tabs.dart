import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// 최상단 스테이지 탭(Desk/Chart/Programs/Flow) — 서류철 폴더 탭 문법.
///
/// 기본 [TabBar]나 독립된 [Container] 버튼 나열이 아니다. rail 전체에
/// 1dp 하단 hairline이 있고, 각 탭은 위쪽 두 모서리만 둥근 파일 탭이다.
/// 비선택 탭은 종이색 배경 + 위/좌/우 테두리만(아래 테두리 없음)으로 조용히
/// rail 위에 앉아 있고, 선택된 탭만 더 높이·진하게(SORI purple) 떠올라
/// rail 하단선을 1dp 덮으며 아래 본문과 하나의 면으로 이어진다.
///
/// 라우팅·상태는 전달받은 [controller](TabController)를 그대로 따른다 —
/// 이 위젯은 시각 표현만 담당한다.
class SoriStageFolderTabs extends StatefulWidget {
  const SoriStageFolderTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.minWidths,
    this.dotIndex,
  });

  final TabController controller;

  /// 왼쪽부터 순서대로. controller.length와 같은 길이여야 한다.
  final List<String> labels;

  /// 라벨별 최소 폭(선택 사항) — 좁은 화면에서도 눌리는 순간 폭이 흔들리지
  /// 않도록 사전 확보한다. 미지정 시 텍스트 폭 그대로 사용한다.
  final List<double>? minWidths;

  /// 이 인덱스의 탭 라벨 옆에 작은 초록 점을 붙인다(예: 진행 중 타이머).
  /// null이면 표시하지 않는다.
  final int? dotIndex;

  static const double railHeight = 52;
  static const double _unselectedHeight = 46;
  static const double _selectedHeight = 52;
  static const double _sidePad = 16;
  static const double _hPad = 18;
  static const double _gap = 2; // 0~2dp — 붙어있는 서류철처럼, 분리된 카드 아님.
  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(11),
    topRight: Radius.circular(11),
  );

  static const _unselectedFill = SoriTokens.surface; // 밝은 종이색.
  static const _unselectedBorder = SoriTokens.inputBorder;
  static const _unselectedText = SoriTokens.textCharcoal;
  static const _selectedFill = SoriTokens.brand; // LOCKED SORI purple.
  static const _selectedText = SoriTokens.onBrand;
  static const _hairline = SoriTokens.inputBorder;

  static const _unselectedStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: _unselectedText,
    height: 1.2,
  );
  static const _selectedStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: _selectedText,
    height: 1.2,
  );

  @override
  State<SoriStageFolderTabs> createState() => _SoriStageFolderTabsState();
}

class _SoriStageFolderTabsState extends State<SoriStageFolderTabs> {
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SoriStageFolderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final n = labels.length;
    final selectedIndex = widget.controller.index;
    final scaler = MediaQuery.textScalerOf(context);

    final textWidths = [
      for (var i = 0; i < n; i++) _labelWidth(labels[i], scaler, i),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = MediaQuery.sizeOf(context).width;
        final raw = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewW;
        // 제약이 뷰포트보다 넓게 잡히는 경우(클립 없음 Stack) Flow가
        // 화면 밖으로 나가 탭이 미스가 난다 — 뷰포트 폭으로 상한을 건다.
        final maxWidth = raw < viewW ? raw : viewW;
        final layout = _tabWidths(textWidths, maxWidth);
        final widths = layout.widths;
        final gap = layout.gap;

        final lefts = <double>[];
        var cursor = SoriStageFolderTabs._sidePad;
        for (final w in widths) {
          lefts.add(cursor);
          cursor += w + gap;
        }

        final children = <Widget>[
          // 1) rail 전체를 가로지르는 1dp 하단 hairline — 서류철이 놓인 선반.
          const Positioned(
            key: Key('sori-stage-tabs-hairline'),
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: SoriStageFolderTabs._hairline),
          ),
        ];

        // 2) 비선택 탭 먼저 그린다 — rail 위에 조용히 앉아 있는 상태.
        for (var i = 0; i < n; i++) {
          if (i == selectedIndex) continue;
          children.add(
            _tab(
              index: i,
              left: lefts[i],
              width: widths[i],
              selected: false,
            ),
          );
        }

        // 3) 선택된 탭을 맨 마지막(가장 앞 z-order)에 그린다 — rail
        //    하단선을 1dp 덮으며 튀어 오른 파일 탭.
        children.add(
          _tab(
            index: selectedIndex,
            left: lefts[selectedIndex],
            width: widths[selectedIndex],
            selected: true,
          ),
        );

        return SizedBox(
          width: double.infinity,
          height: SoriStageFolderTabs.railHeight,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  Widget _tab({
    required int index,
    required double left,
    required double width,
    required bool selected,
  }) {
    final height = selected
        ? SoriStageFolderTabs._selectedHeight
        : SoriStageFolderTabs._unselectedHeight;
    // 선택 탭만 rail 하단선을 1dp 덮으며 겹친다. 비선택 탭은 선 바로
    // 위에서 멈춘다(자체 아래 테두리 없음 — hairline이 선반 역할).
    final bottom = selected ? 0.0 : 1.0;
    final pressed = _pressedIndex == index;

    return Positioned(
      key: Key('sori-stage-tab-$index'),
      left: left,
      bottom: bottom,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.labels[index],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressedIndex = index),
          onTapUp: (_) => setState(() => _pressedIndex = null),
          onTapCancel: () => setState(() => _pressedIndex = null),
          onTap: () {
            if (widget.controller.index != index) {
              // 테스트·좁은 화면에서도 즉시 전환. 애니메이션 중 탭 유실 방지.
              widget.controller.index = index;
            }
          },
          child: KeyedSubtree(
            key: selected
                ? const Key('home-filed-label')
                : Key('sori-stage-tab-unfiled-$index'),
            child: AnimatedContainer(
              key: Key('sori-stage-tab-fill-$index'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 선택 탭은 채움만(테두리 없음) — 아래 본문 면과 색 경계 없이
                // 바로 이어져 보이도록 한다. 절대 전부 둥근 pill/card로
                // 만들지 않는다 — 위쪽 모서리만 라운드.
                color: selected
                    ? SoriStageFolderTabs._selectedFill.withValues(
                        alpha: pressed ? 0.92 : 1,
                      )
                    : SoriStageFolderTabs._unselectedFill,
                borderRadius: SoriStageFolderTabs._radius,
                border: selected
                    ? null
                    : const Border(
                        top: BorderSide(
                          color: SoriStageFolderTabs._unselectedBorder,
                        ),
                        left: BorderSide(
                          color: SoriStageFolderTabs._unselectedBorder,
                        ),
                        right: BorderSide(
                          color: SoriStageFolderTabs._unselectedBorder,
                        ),
                        // 아래 테두리는 의도적으로 없음 — hairline이 대신한다.
                      ),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.labels[index],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: selected
                          ? SoriStageFolderTabs._selectedStyle
                          : SoriStageFolderTabs._unselectedStyle,
                    ),
                  ),
                  if (widget.dotIndex == index) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SoriTokens.semanticGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _labelWidth(String label, TextScaler scaler, int index) {
    final painter = TextPainter(
      // 선택 시 더 크고 굵은 스타일을 쓰므로, 그 폭을 기준으로 레이아웃해야
      // 선택되는 순간 좁아서 잘리는 일이 없다.
      text: TextSpan(text: label, style: SoriStageFolderTabs._selectedStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    var width = painter.size.width;
    if (widget.dotIndex == index) width += 11;
    final minWidths = widget.minWidths;
    if (minWidths != null && index < minWidths.length) {
      width = _max(width, minWidths[index] - 16);
    }
    return width;
  }

  ({List<double> widths, double gap}) _tabWidths(
    List<double> textWidths,
    double maxWidth,
  ) {
    final n = textWidths.length;
    var gap = SoriStageFolderTabs._gap;
    final minWidths = widget.minWidths;

    // 각 탭의 콘텐츠 최소 폭(텍스트 + 좌우 패딩, 또는 전달된 minWidth).
    final contentMins = [
      for (var i = 0; i < n; i++)
        _max(
          textWidths[i] + 16, // horizontal padding 8*2
          minWidths != null && i < minWidths.length ? minWidths[i] : 0,
        ),
    ];

    // 좌·우 sidePad를 모두 확보한 뒤 남는 폭에 탭을 넣는다.
    double spanFor(double g) =>
        maxWidth - SoriStageFolderTabs._sidePad * 2 - g * (n - 1);

    var available = spanFor(gap);
    while (available < contentMins.fold<double>(0, (a, b) => a + b) &&
        gap > 0) {
      gap -= 1;
      available = spanFor(gap);
    }

    final minSum = contentMins.fold<double>(0, (a, b) => a + b);
    final widths = List<double>.from(contentMins);
    if (minSum <= available && minSum > 0) {
      final grow = available - minSum;
      for (var i = 0; i < n; i++) {
        widths[i] += grow * (contentMins[i] / minSum);
      }
    } else if (minSum > available && minSum > 0) {
      final scale = available / minSum;
      for (var i = 0; i < n; i++) {
        widths[i] = contentMins[i] * scale;
      }
    }

    // 안전: 마지막 탭 오른쪽이 뷰포트 안에 남도록 합을 재클램프.
    final sum = widths.fold<double>(0, (a, b) => a + b);
    final limit = spanFor(gap);
    if (sum > limit && sum > 0) {
      final scale = limit / sum;
      for (var i = 0; i < n; i++) {
        widths[i] *= scale;
      }
    }
    return (widths: widths, gap: gap);
  }

  static double _max(double a, double b) => a > b ? a : b;
}
