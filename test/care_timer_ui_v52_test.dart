import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/widgets/care_stacked_segment_bar.dart';
import 'package:sori/features/operation/widgets/care_timer_fullscreen_page.dart';
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

      expect(find.text('05:00'), findsOneWidget);
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
        careStartedAt: DateTime(2026, 9, 1, 10, 5),
        currentStepIndex: 0,
        currentStepStartedAt: DateTime(2026, 9, 1, 10, 5),
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

      expect(find.text('케어 타이머'), findsOneWidget);
      expect(find.text('케어 종료'), findsOneWidget);
      expect(find.text('타이머 리스트'), findsOneWidget);
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
  });
}
