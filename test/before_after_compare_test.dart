import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/widgets/ba_workspace_dock.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/views/before_after_compare_page.dart';
import 'package:sori/views/before_after_compare_sheet.dart';
import 'package:sori/widgets/before_after_slider.dart';

CustomerChart _chart({
  required String id,
  required int visit,
  required String care,
  String? before,
  String? after,
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: 'cus-1',
    visitNumber: visit,
    careName: care,
    beforeImageUrl: before ?? 'https://example.com/$id-b.webp',
    afterImageUrl: after ?? 'https://example.com/$id-a.webp',
  );
}

List<CustomerChart> get _mixed {
  return [
    _chart(id: 'face-1', visit: 1, care: '스페셜 웨딩케어'),
    _chart(id: 'face-4', visit: 4, care: '스페셜 웨딩케어'),
    _chart(id: 'back-1', visit: 1, care: '테라노바 에너지 복부관리'),
    _chart(id: 'back-2', visit: 2, care: '테라노바 에너지 복부관리'),
  ];
}

void main() {
  group('서비스 메뉴 2 depth 그룹핑', () {
    test('같은 시술은 한 그룹, 다른 시술은 섞이지 않는다', () {
      final groups = groupVisitPhotoSlotsByProgram(
        buildVisitPhotoSlots(_mixed),
      );
      expect(groups.map((g) => g.label), ['스페셜 웨딩케어', '테라노바 에너지 복부관리']);
      expect(
        groups.first.slots.every((s) => s.programKey == '스페셜 웨딩케어'),
        isTrue,
      );
      expect(
        groups.last.slots.every((s) => s.programKey == '테라노바 에너지 복부관리'),
        isTrue,
      );
    });

    test('공백 차이만 있는 시술명은 같은 메뉴로 접힌다', () {
      final slots = buildVisitPhotoSlots([
        _chart(id: 'a', visit: 1, care: '스페셜  웨딩케어'),
        _chart(id: 'b', visit: 2, care: '스페셜 웨딩케어'),
      ]);
      final groups = groupVisitPhotoSlotsByProgram(slots);
      expect(groups, hasLength(1));
    });
  });

  group('피드 컨텍스트 시드', () {
    test('initialChartId 가 있으면 그 차트의 B/A가 왼쪽·오른쪽이다', () {
      final slots = buildVisitPhotoSlots(_mixed);
      final seed = resolveCompareViewerSeed(
        slots: slots,
        initialChartId: 'face-4',
        initialCareName: '스페셜 웨딩케어',
      );

      expect(seed.programKey, '스페셜 웨딩케어');
      expect(seed.left?.chartId, 'face-4');
      expect(seed.left?.kind, 'before');
      expect(seed.right?.chartId, 'face-4');
      expect(seed.right?.kind, 'after');
    });

    test('시드가 없으면 다른 시술의 1회차로 도망가지 않는다', () {
      final slots = buildVisitPhotoSlots(_mixed);
      final seed = resolveCompareViewerSeed(slots: slots);

      expect(seed.programKey, '스페셜 웨딩케어');
      expect(seed.left?.chartId, 'face-1');
      expect(seed.right?.chartId, isNot('back-2'));
      expect(seed.right?.programKey, '스페셜 웨딩케어');
    });

    test('차트 id 가 없는 프로그램 전환은 그 메뉴의 첫 B · 마지막 A', () {
      final slots = buildVisitPhotoSlots(_mixed);
      final seed = resolveCompareViewerSeed(
        slots: slots,
        initialCareName: '테라노바 에너지 복부관리',
      );

      expect(seed.programKey, '테라노바 에너지 복부관리');
      expect(seed.left?.chartId, 'back-1');
      expect(seed.left?.kind, 'before');
      expect(seed.right?.chartId, 'back-2');
      expect(seed.right?.kind, 'after');
    });

    test('스토리 라벨은 중점 없이 회차와 B/A 만 붙인다', () {
      final slot = buildVisitPhotoSlots(_mixed).first;
      expect(slot.shortLabel, '1회차 · B');
      expect(slot.storyLabel, '1회차 B');
    });
  });

  group('뷰어 위젯', () {
    Future<void> pumpViewer(
      WidgetTester tester, {
      required Size size,
      String? initialChartId,
      String? initialCareName,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: BeforeAfterComparePage(
              customerName: '하얀광부',
              charts: _mixed,
              initialChartId: initialChartId,
              initialCareName: initialCareName,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('피드에서 연 4회차가 진입 즉시 왼쪽 B · 오른쪽 A 다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
        initialCareName: '스페셜 웨딩케어',
      );

      final dock = tester.widget<BaWorkspaceDock>(find.byType(BaWorkspaceDock));
      expect(dock.left?.chartId, 'face-4');
      expect(dock.left?.kind, 'before');
      expect(dock.right?.chartId, 'face-4');
      expect(dock.right?.kind, 'after');
      expect(find.text('스페셜 웨딩케어'), findsOneWidget);
      expect(find.text('서비스 메뉴'), findsNothing);
    });

    testWidgets('헤더·독 사이 사진은 화면 너비를 꽉 채운다', (tester) async {
      for (final size in const [Size(430, 932), Size(932, 430)]) {
        await pumpViewer(
          tester,
          size: size,
          initialChartId: 'face-4',
        );

        expect(find.byKey(const Key('ba-compare-photo-stage')), findsOneWidget);
        expect(find.byKey(const Key('ba-compare-side-panel')), findsNothing);
        expect(find.byKey(const Key('ba-compare-drop-zone')), findsNothing);
        expect(find.byType(BaWorkspaceDock), findsOneWidget);
        expect(find.byType(BaSnapDial), findsOneWidget);

        final stage = tester.getRect(
          find.byKey(const Key('ba-compare-photo-stage')),
        );
        final screen = tester.getSize(find.byType(BeforeAfterComparePage));
        final dock = tester.getRect(find.byType(BaWorkspaceDock));

        expect(stage.left, closeTo(0, 1));
        expect(stage.width, closeTo(screen.width, 1));
        expect(stage.top, greaterThan(40));
        expect(dock.top, greaterThanOrEqualTo(stage.bottom - 2));
        expect(stage.height, greaterThan(size.height * 0.4));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('슬라이더는 전면 드래그이고 메인 사진은 cover 다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      final slider = tester.widget<BeforeAfterSlider>(
        find.byType(BeforeAfterSlider),
      );
      expect(slider.dragHandleOnly, isFalse);
      expect(slider.borderRadius, BorderRadius.zero);

      final stagePanes = tester.widgetList<ChartImagePane>(
        find.descendant(
          of: find.byType(BeforeAfterSlider),
          matching: find.byType(ChartImagePane),
        ),
      );
      expect(stagePanes, isNotEmpty);
      expect(stagePanes.every((p) => p.fit == BoxFit.cover), isTrue);

      final dockPanes = tester.widgetList<ChartImagePane>(
        find.descendant(
          of: find.byType(BaWorkspaceDock),
          matching: find.byType(ChartImagePane),
        ),
      );
      expect(dockPanes, isNotEmpty);
      expect(dockPanes.every((p) => p.fit == BoxFit.cover), isTrue);
    });

    testWidgets('하단은 스냅 다이얼이고 한 칸 스냅이 오른쪽 슬롯에 붙는다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      expect(find.byType(BaWorkspaceDock), findsOneWidget);
      expect(find.byType(BaSnapDial), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final dock = tester.widget<BaWorkspaceDock>(find.byType(BaWorkspaceDock));
      expect(dock.left?.key, 'face-4|before');
      expect(dock.right?.key, 'face-4|before');
    });

    testWidgets('중앙에 스냅된 썸네일은 1.5배로 커지고 활성 슬롯에 붙는다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );
      await tester.pumpAndSettle();

      final centered = find.ancestor(
        of: find.byKey(const Key('ba-story-thumb-face-4|after')),
        matching: find.byType(BaDialCell),
      );
      expect(tester.widget<BaDialCell>(centered).scale, closeTo(1.5, 0.08));

      await tester.drag(
        find.byKey(const Key('ba-story-strip-list')),
        Offset(BaSnapDial.stride, 0),
      );
      await tester.pumpAndSettle();

      final dock = tester.widget<BaWorkspaceDock>(find.byType(BaWorkspaceDock));
      expect(dock.right?.key, 'face-4|before');
      expect(dock.left?.key, 'face-4|before');
    });

    testWidgets('연결 슬롯을 왼쪽으로 바꾸면 썸네일이 왼쪽을 교체한다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.byKey(const Key('ba-well-before')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final dock = tester.widget<BaWorkspaceDock>(find.byType(BaWorkspaceDock));
      expect(dock.left?.key, 'face-4|after');
      expect(dock.right?.key, 'face-4|after');
    });

    testWidgets('돋보기 버튼은 0.5x까지 줄고 기본은 1x 다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      expect(find.text('1x'), findsOneWidget);
      expect(find.text('0.5x'), findsNothing);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-out')));
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);

      final scaled = tester.widget<AnimatedScale>(
        find.byKey(const Key('ba-compare-photo-scale')),
      );
      expect(scaled.scale, 0.5);
      expect(scaled.alignment, Alignment.center);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-out')));
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-in')));
      await tester.pump();
      expect(find.text('1x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-in')));
      await tester.pump();
      expect(find.text('1.5x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-in')));
      await tester.pump();
      expect(find.text('2x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ba-compare-zoom-in')));
      await tester.pump();
      expect(find.text('2x'), findsOneWidget);
    });

    testWidgets('줌해도 Before/After 라벨은 뷰포트 모서리에 고정된다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(932, 430),
        initialChartId: 'face-4',
      );

      final beforeKey = find.byKey(const Key('ba-compare-label-before'));
      final afterKey = find.byKey(const Key('ba-compare-label-after'));
      final stage = tester.getRect(
        find.byKey(const Key('ba-compare-photo-stage')),
      );

      Offset beforeAt() => tester.getTopLeft(beforeKey);
      Offset afterAt() => tester.getTopRight(afterKey);

      expect(beforeAt().dx, closeTo(stage.left + 16, 1));
      expect(beforeAt().dy, closeTo(stage.top + 16, 1));
      expect(afterAt().dx, closeTo(stage.right - 16, 1));
      expect(afterAt().dy, closeTo(stage.top + 16, 1));

      final pinnedBefore = beforeAt();
      final pinnedAfter = afterAt();

      await tester.tap(find.byKey(const Key('ba-compare-zoom-in')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(beforeAt().dx, closeTo(pinnedBefore.dx, 0.5));
      expect(beforeAt().dy, closeTo(pinnedBefore.dy, 0.5));
      expect(afterAt().dx, closeTo(pinnedAfter.dx, 0.5));
      expect(afterAt().dy, closeTo(pinnedAfter.dy, 0.5));

      await tester.tap(find.byKey(const Key('ba-compare-mode')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ba-compare-zoom-out')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ba-compare-zoom-out')));
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);

      expect(beforeAt().dx, closeTo(pinnedBefore.dx, 0.5));
      expect(beforeAt().dy, closeTo(pinnedBefore.dy, 0.5));
      expect(afterAt().dx, closeTo(pinnedAfter.dx, 0.5));
      expect(afterAt().dy, closeTo(pinnedAfter.dy, 0.5));
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const Key('ba-compare-photo-scale')),
            )
            .alignment,
        Alignment.center,
      );
    });

    testWidgets('더보기 시트에 저장·피드·공유·촬영·나가기가 있다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.byKey(const Key('ba-compare-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('저장하기'), findsOneWidget);
      expect(find.text('피드에 추가'), findsOneWidget);
      expect(find.text('공유하기'), findsOneWidget);
      expect(find.text('촬영하기'), findsOneWidget);
      expect(find.text('나가기'), findsOneWidget);
    });

    testWidgets('케어 필을 열면 아코디언으로 다른 시술이 보인다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.byKey(const Key('ba-compare-care-pill')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('테라노바 에너지 복부관리'), findsOneWidget);
    });

    testWidgets('나란히 모드에도 InteractiveViewer 가 없다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.byKey(const Key('ba-compare-mode')));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(BeforeAfterSlider), findsNothing);
    });
  });
}
