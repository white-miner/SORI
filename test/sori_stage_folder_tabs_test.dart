import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/sori_stage_folder_tabs.dart';
import 'package:sori/theme/sori_tokens.dart';

const _labels = ['DESK', 'CHART', 'PROGRAMS', 'FLOW'];
const _minWidths = [80.0, 84.0, 116.0, 80.0];

/// 테스트 전용 host — SoriStageFolderTabs는 자체 TabController를 만들지
/// 않고 밖에서 받으므로, vsync 제공용 StatefulWidget으로 감싼다.
class _Host extends StatefulWidget {
  const _Host({this.dotIndex, this.onController});

  final int? dotIndex;
  final ValueChanged<TabController>? onController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
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
          labels: _labels,
          minWidths: _minWidths,
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

BoxDecoration _decorationOf(WidgetTester tester, int index) =>
    _fillOf(tester, index).decoration! as BoxDecoration;

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

  testWidgets('선택 탭은 밑줄로 구분하며 비선택 탭은 투명 밑줄이다', (tester) async {
    await tester.pumpWidget(const _Host());
    final selected = _decorationOf(tester, 0);
    expect(selected.color, SoriTokens.surface);
    expect((selected.border! as Border).bottom.color, SoriTokens.textCharcoal);
    expect((_decorationOf(tester, 1).border! as Border).bottom.color, Colors.transparent);
  });

  testWidgets('탭을 누르면 controller.index가 바뀌고 채움 색이 함께 이동한다', (tester) async {
    TabController? controller;
    await tester.pumpWidget(_Host(onController: (c) => controller = c));
    await tester.pump();

    expect(controller!.index, 0);
    await tester.tap(find.text('CHART'));
    await tester.pumpAndSettle();

    expect(controller!.index, 1);
    // 이제 index 1이 보라색 채움, index 0은 종이색으로 돌아간다 — 선택됐다고
    // 전부 보라로 통일되지 않는다는 요구사항을 동일 계열로 재확인.
    expect((_decorationOf(tester, 1).border! as Border).bottom.color, SoriTokens.textCharcoal);
    expect(_decorationOf(tester, 0).color, SoriTokens.surface);
  });

  testWidgets('dotIndex가 지정된 탭에만 진행 표시 점이 붙는다', (tester) async {
    await tester.pumpWidget(const _Host(dotIndex: 3));
    await tester.pump();

    final flowFill = tester.widget<AnimatedContainer>(
      find.byKey(const Key('sori-stage-tab-fill-3')),
    );
    final flowRow = flowFill.child! as Row;
    // Flow(3)는 Flexible(라벨) + 간격 SizedBox + 점 Container = 3개 children.
    expect(flowRow.children.length, 3);

    final deskFill = tester.widget<AnimatedContainer>(
      find.byKey(const Key('sori-stage-tab-fill-0')),
    );
    final deskRow = deskFill.child! as Row;
    // Desk(0)는 점 없이 Flexible(라벨)만 = 1개 child.
    expect(deskRow.children.length, 1);
  });
}
