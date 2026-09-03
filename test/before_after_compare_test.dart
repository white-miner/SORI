import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/widgets/ba_story_strip.dart';
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
    }

    testWidgets('피드에서 연 4회차가 진입 즉시 왼쪽 B · 오른쪽 A 다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
        initialCareName: '스페셜 웨딩케어',
      );

      expect(find.text('4회차 · B  ↔  4회차 · A'), findsOneWidget);
      expect(find.text('1회차 · B  ↔  4회차 · A'), findsNothing);
      expect(find.text('서비스 메뉴'), findsWidgets);
    });

    testWidgets('가로 모드에서는 사진 스테이지와 우측 패널이 나란히 있다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(932, 430),
        initialChartId: 'face-4',
      );

      expect(find.byKey(const Key('ba-compare-photo-stage')), findsOneWidget);
      expect(find.byKey(const Key('ba-compare-side-panel')), findsOneWidget);

      final stage = tester.getRect(
        find.byKey(const Key('ba-compare-photo-stage')),
      );
      final panel = tester.getRect(
        find.byKey(const Key('ba-compare-side-panel')),
      );
      final screen = tester.getSize(find.byType(BeforeAfterComparePage));

      expect(stage.left, closeTo(0, 1));
      expect(stage.top, closeTo(0, 1));
      expect(stage.height, closeTo(screen.height, 1));
      expect(stage.width / screen.width, inInclusiveRange(0.74, 0.82));
      expect(panel.left, greaterThan(stage.right - 1));
      expect(panel.width / screen.width, inInclusiveRange(0.18, 0.26));

      // 조작 UI는 패널 안에 있고 사진 위를 덮지 않는다.
      final toggle = tester.getRect(find.text('슬라이더').first);
      expect(toggle.left, greaterThanOrEqualTo(panel.left - 1));
    });

    testWidgets('세로 모드에서는 우측 패널이 없다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      expect(find.byKey(const Key('ba-compare-photo-stage')), findsOneWidget);
      expect(find.byKey(const Key('ba-compare-side-panel')), findsNothing);
    });

    testWidgets('가로에서 사진 스테이지가 화면 높이의 대부분을 쓴다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(932, 430),
        initialChartId: 'face-4',
      );

      final stage = tester.getSize(
        find.byKey(const Key('ba-compare-photo-stage')),
      );
      expect(stage.height, greaterThan(400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('슬라이더는 피드와 같이 전면 드래그이고 핀치 뷰어가 없다', (tester) async {
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

      final panes = tester.widgetList<ChartImagePane>(
        find.byType(ChartImagePane),
      );
      expect(panes, isNotEmpty);
      expect(panes.every((p) => p.fit == BoxFit.cover), isTrue);
    });

    testWidgets('하단은 스토리 스택이고 썸네일 탭은 오른쪽 슬롯에 붙는다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      expect(find.byType(BaStoryStrip), findsOneWidget);
      expect(find.text('1회차 B'), findsWidgets);

      await tester.tap(find.byKey(const Key('ba-story-thumb-face-1|before')));
      await tester.pump();

      expect(find.text('4회차 · B  ↔  1회차 · B'), findsOneWidget);
    });

    testWidgets('썸네일을 롱프레스 후 손을 떼면 같은 슬롯이 바인딩된다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.longPress(
        find.byKey(const Key('ba-story-thumb-face-1|after')),
      );
      await tester.pump();

      expect(find.text('4회차 · B  ↔  1회차 · A'), findsOneWidget);
    });

    testWidgets('연결 슬롯을 왼쪽으로 바꾸면 썸네일이 왼쪽을 교체한다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.byKey(const Key('ba-compare-bind-left')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ba-story-thumb-face-1|after')));
      await tester.pump();

      expect(find.text('1회차 · A  ↔  4회차 · A'), findsOneWidget);
    });

    testWidgets('돋보기 버튼은 1x → 1.5x → 2x 로만 움직인다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

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

      await tester.tap(find.byKey(const Key('ba-compare-zoom-out')));
      await tester.pump();
      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('나란히 모드에도 InteractiveViewer 가 없다', (tester) async {
      await pumpViewer(
        tester,
        size: const Size(430, 932),
        initialChartId: 'face-4',
      );

      await tester.tap(find.text('나란히'));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(BeforeAfterSlider), findsNothing);
    });
  });
}
