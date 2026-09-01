import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/widgets/preset_expand_panel.dart';
import 'package:sori/visit_kernel/models/care_program_template.dart';
import 'package:sori/visit_kernel/models/preset_slot_tint.dart';

void main() {
  group('PresetSlotTint stepColor', () {
    test('varies opacity across steps', () {
      const tint = PresetSlotTint.blue;
      final first = tint.stepColor(0, 4);
      final last = tint.stepColor(3, 4);
      expect(first.a, greaterThan(last.a));
    });
  });

  group('PresetExpandPanel', () {
    testWidgets('expands preset list on tap', (tester) async {
      const presets = [
        CareProgramTemplate(
          id: 'p1',
          shopId: 's1',
          slotIndex: 0,
          name: '기본 50+10 케어',
          slotTint: PresetSlotTint.green,
          steps: [
            CareProgramStep(label: '클렌징', minutes: 10),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetExpandPanel(
              presets: presets,
              tintAt: (i) => PresetSlotTint.defaultForSlot(i),
              selectedSlot: 0,
              onPresetSelected: (_) {},
              onConfigureSlot: (_) {},
              onOpenEditor: () {},
            ),
          ),
        ),
      );

      expect(find.text('타이머 프리셋 설정 및 선택'), findsOneWidget);
      expect(find.text('기본 50+10 케어'), findsNothing);

      await tester.tap(find.text('타이머 프리셋 설정 및 선택'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('기본 50+10 케어'), findsOneWidget);
      expect(find.text('1구간'), findsOneWidget);
    });
  });
}
