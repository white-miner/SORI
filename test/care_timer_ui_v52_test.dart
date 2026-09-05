import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/widgets/care_stacked_segment_bar.dart';
import 'package:sori/features/operation/widgets/care_timer_fullscreen_page.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/models/care_timer_entry_mode.dart';
import 'package:sori/features/operation/visit_timer_store.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/care_program_template.dart';
import 'package:sori/visit_kernel/models/preset_slot_tint.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

void main() {
  group('CareStackedSegmentBar', () {
    const steps = [
      CareProgramStep(label: '클렌징', minutes: 10),
      CareProgramStep(label: '마사지', minutes: 5),
      CareProgramStep(label: '마무리', minutes: 3),
    ];

    testWidgets('renders front chip with countdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareStackedSegmentBar(
              steps: steps,
              tint: PresetSlotTint.orange,
              currentIndex: 0,
              isArmed: false,
              isRunning: true,
              isPaused: false,
              stepRemainingSeconds: 9 * 60 + 42,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('09:42'), findsOneWidget);
      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
      expect(find.byKey(const Key('care-segment-layers')), findsOneWidget);
    });

    testWidgets('칩을 탭하면 onStepTap이 해당 인덱스로 호출된다', (tester) async {
      var jumped = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareStackedSegmentBar(
              steps: steps,
              tint: PresetSlotTint.orange,
              currentIndex: 0,
              isArmed: false,
              isRunning: true,
              isPaused: false,
              stepRemainingSeconds: 9 * 60,
              onStepTap: (i) => jumped = i,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chip-1')));
      await tester.pump();
      expect(jumped, 1);
    });

    testWidgets('updates label when current index advances', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareStackedSegmentBar(
              steps: steps,
              tint: PresetSlotTint.orange,
              currentIndex: 1,
              isArmed: false,
              isRunning: true,
              isPaused: false,
              stepRemainingSeconds: 5 * 60,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('05:00'), findsWidgets);
    });

    testWidgets('가로 Row로 칩이 겹치지 않고 모두 보인다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareStackedSegmentBar(
              steps: steps,
              tint: PresetSlotTint.orange,
              currentIndex: 0,
              isArmed: false,
              isRunning: true,
              isPaused: false,
              stepRemainingSeconds: 9 * 60,
              expandList: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('care-segment-list')), findsOneWidget);
      expect(find.byKey(const Key('care-segment-h-list')), findsOneWidget);
      expect(find.byKey(const Key('care-segment-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-2')), findsOneWidget);

      final first = tester.getRect(find.byKey(const ValueKey('chip-0')));
      final second = tester.getRect(find.byKey(const ValueKey('chip-1')));
      expect(second.left, greaterThan(first.right - 1));
    });

    testWidgets('레이어 아이콘 탭이면 아코디언이 접히고 다시 펼쳐진다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareStackedSegmentBar(
              steps: steps,
              tint: PresetSlotTint.orange,
              currentIndex: 0,
              isArmed: false,
              isRunning: true,
              isPaused: false,
              stepRemainingSeconds: 9 * 60,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('타임라인'), findsOneWidget);
      expect(find.text('클렌징'), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('care-segment-layers')));
      await tester.tap(find.byKey(const Key('care-segment-layers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.byKey(const Key('care-segment-accordion')), findsNothing);

      await tester.tap(find.byKey(const Key('care-segment-layers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.byKey(const Key('care-segment-accordion')), findsOneWidget);
      expect(find.text('타임라인'), findsOneWidget);
    });
  });

  group('CareTimerFullscreenPage', () {
    late SoriStore store;
    late VisitSession session;
    late VisitTimerStore timer;

    setUp(() {
      store = SoriStore.instance;
      timer = VisitTimerStore.instance;
      session = VisitSession(
        id: 'vs-care-ui',
        shopId: 'shop-test',
        customerId: 'cust-1',
        customerName: '테스트',
        startedAt: DateTime(2026, 9, 1, 10),
      );
      timer.presets = const [
        CareProgramTemplate(
          id: 'preset-1',
          shopId: 'shop-test',
          slotIndex: 0,
          name: '기본 케어',
          slotTint: PresetSlotTint.orange,
          steps: [
            CareProgramStep(label: '클렌징', minutes: 10),
            CareProgramStep(label: '마사지', minutes: 5),
          ],
        ),
      ];
      timer.active = VisitOperationTimer(
        id: 'timer-1',
        visitSessionId: session.id,
        shopId: 'shop-test',
        careStartedAt: DateTime.now(),
        currentStepIndex: 0,
        currentStepStartedAt: DateTime.now(),
        templateSnapshot: timer.presets.first.steps,
        status: VisitTimerStatus.care,
      );
      timer.selectedPresetSlot = 0;
      timer.carePaused = false;
    });

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CareTimerFullscreenPage(
            store: store,
            session: session,
            presetSlot: 0,
            entryMode: CareTimerEntryMode.careStartManual,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows stacked bar, flip clock, and care end button', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('기본 케어'), findsOneWidget);
      expect(find.text('케어 종료'), findsOneWidget);
      expect(find.text('타임라인'), findsOneWidget);
      expect(find.byType(CareStackedSegmentBar), findsOneWidget);
    });

    testWidgets('care end button is enabled mid-care', (tester) async {
      await pumpPage(tester);

      final endBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '케어 종료'),
      );
      expect(endBtn.onPressed, isNotNull);
    });

    testWidgets('immersive toggle hides chrome', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip('몰입 모드'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('타이머 리스트'), findsNothing);
      expect(find.text('케어 종료'), findsOneWidget);
    });

    testWidgets('shows remaining banner and skip next control', (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('care-remaining-label')), findsOneWidget);
      expect(find.text('종료까지 남은 시간'), findsWidgets);
      expect(find.byKey(const Key('care-skip-next')), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-skip-next')));
      await tester.pump();

      expect(timer.active?.currentStepIndex, 1);
    });

    testWidgets('overtime banner switches to extra time', (tester) async {
      timer.active = timer.active!.copyWith(
        status: VisitTimerStatus.careOvertime,
        currentStepIndex: 2,
      );
      await pumpPage(tester);

      expect(find.text('추가 시간'), findsWidgets);
    });

    testWidgets('넓은 가로에서도 중앙 스테이지로 붙고 세로 레일이 없다', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CareTimerFullscreenPage(
            store: store,
            session: session,
            presetSlot: 0,
            entryMode: CareTimerEntryMode.careStartManual,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 웹 가로는 세로 떠다니는 컨트롤이 아니라 시계 아래 Row.
      expect(find.byTooltip('바 숨기기'), findsNothing);
      expect(find.byKey(const Key('care-skip-next')), findsOneWidget);
      expect(find.byType(CareStackedSegmentBar), findsOneWidget);

      final skip = tester.getCenter(find.byKey(const Key('care-skip-next')));
      final clock = tester.getCenter(find.byType(FlipClockDisplay));
      expect(skip.dy, greaterThan(clock.dy));
      expect((skip.dx - clock.dx).abs(), lessThan(220));
    });
  });
}

