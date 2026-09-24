import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/sori_stage_folder_tabs.dart';
import 'package:sori/theme/sori_tokens.dart';

const _labels = ['DESK', 'CHART', 'PROGRAMS', 'FLOW'];
const _minWidths = [80.0, 84.0, 116.0, 80.0];

/// Test host — SoriStageFolderTabs takes an external TabController.
class _Host extends StatefulWidget {
  const _Host({this.dotIndex, this.onController, this.labels = _labels});

  final int? dotIndex;
  final ValueChanged<TabController>? onController;
  final List<String> labels;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.labels.length, vsync: this);
    widget.onController?.call(_tabs);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SoriStageFolderTabs(
          controller: _tabs,
          labels: widget.labels,
          minWidths: widget.labels == _labels ? _minWidths : null,
          dotIndex: widget.dotIndex,
        ),
      ),
    );
  }
}

AnimatedContainer _fillOf(WidgetTester tester, int index) =>
    tester.widget<AnimatedContainer>(
      find.byKey(Key('sori-stage-tab-fill-$index')),
    );

AnimatedContainer _underlineOf(WidgetTester tester, int index) =>
    tester.widget<AnimatedContainer>(
      find.byKey(Key('sori-stage-tab-underline-$index')),
    );

void main() {
  for (final width in [320.0, 430.0, 1024.0]) {
    testWidgets('휴대폰/태블릿 폭 $width 에서 모든 탭을 선택할 수 있다', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TabController? controller;
      await tester.pumpWidget(_Host(onController: (c) => controller = c));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(Key('sori-stage-tab-$i')));
        await tester.pumpAndSettle();
        expect(controller!.index, i);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('모든 스테이지 탭 라벨(DESK/CHART/PROGRAMS/FLOW)이 보인다', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();

    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('sori-stage-tabs-hairline')), findsOneWidget);
  });

  testWidgets('선택 탭 밑줄은 라벨 폭이며 charcoal, 비선택은 폭 0', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();

    final selected = _underlineOf(tester, 0);
    final unselected = _underlineOf(tester, 1);
    final selectedDeco = selected.decoration! as BoxDecoration;
    expect(selectedDeco.color, SoriTokens.textCharcoal);
    // Selected underline uses intrinsic label width (not full tab slot - 16).
    final selectedSize =
        tester.getSize(find.byKey(const Key('sori-stage-tab-underline-0')));
    final unselectedSize =
        tester.getSize(find.byKey(const Key('sori-stage-tab-underline-1')));
    expect(selectedSize.width, greaterThan(20));
    expect(selectedSize.width, lessThan(80));
    final unselectedDeco = unselected.decoration! as BoxDecoration;
    expect(unselectedDeco.color, Colors.transparent);
    expect(unselectedSize.width, 0);
  });

  testWidgets('탭을 누르면 controller.index가 바뀌고 밑줄이 함께 이동한다', (tester) async {
    TabController? controller;
    await tester.pumpWidget(_Host(onController: (c) => controller = c));
    await tester.pump();

    expect(controller!.index, 0);
    await tester.tap(find.text('CHART'));
    await tester.pumpAndSettle();

    expect(controller!.index, 1);
    expect(
      (_underlineOf(tester, 1).decoration! as BoxDecoration).color,
      SoriTokens.textCharcoal,
    );
    expect(
      (_underlineOf(tester, 0).decoration! as BoxDecoration).color,
      Colors.transparent,
    );
  });

  testWidgets('dotIndex가 지정된 탭에만 진행 표시 점이 붙는다', (tester) async {
    await tester.pumpWidget(const _Host(dotIndex: 3));
    await tester.pump();

    final flowFill = _fillOf(tester, 3);
    final flowColumn = flowFill.child! as Column;
    final flowRow = flowColumn.children.first as Row;
    // Flow(3): Flexible(label) + gap + green dot.
    expect(flowRow.children.length, 3);

    final deskFill = _fillOf(tester, 0);
    final deskColumn = deskFill.child! as Column;
    final deskRow = deskColumn.children.first as Row;
    expect(deskRow.children.length, 1);
  });

  testWidgets('탭은 뷰포트 equal-fit이 아니라 왼쪽 정렬 고유 폭을 쓴다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const _Host(labels: ['추천', '탐색', '우리지역', '상권분석']),
    );
    await tester.pump();

    final first = tester.getRect(find.byKey(const Key('sori-stage-tab-0')));
    final last = tester.getRect(find.byKey(const Key('sori-stage-tab-3')));
    // Left-aligned: first tab near side pad; last tab leaves right breathing room.
    expect(first.left, lessThan(24));
    expect(last.right, lessThan(800 - 80));
    // Slots are intrinsic — not equal-fit across the viewport.
    final widths = [
      for (var i = 0; i < 4; i++)
        tester.getRect(find.byKey(Key('sori-stage-tab-$i'))).width,
    ];
    expect(widths.toSet().length, greaterThan(1));
  });
}
