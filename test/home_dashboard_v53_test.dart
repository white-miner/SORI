import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/home_dashboard_controller.dart';
import 'package:sori/features/visit/models/care_timer_entry_mode.dart';
import 'package:sori/features/visit/widgets/memo_display_policy.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

void main() {
  group('HomeDashboardController count', () {
    test('debounce auto-starts after 5 seconds', () async {
      final ctrl = HomeDashboardController();
      ctrl.toggleCountTool();
      ctrl.onCountDigitTap(2, 1);
      ctrl.onCountDigitTap(3, 5);
      expect(ctrl.heroMode, HomeHeroMode.countSetup);
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(ctrl.heroMode, HomeHeroMode.countRunning);
      ctrl.dispose();
    });
  });

  group('CareTimerEntryMode', () {
    test('path C shows care end immediately', () {
      expect(
        CareTimerEntryMode.careStartQuick.showCareEndImmediately,
        isTrue,
      );
      expect(
        CareTimerEntryMode.standalone.showCareStartButton,
        isTrue,
      );
    });
  });

  group('MemoDisplayPolicy', () {
    test('falls back to nearest future memo', () {
      final now = DateTime(2026, 9, 1, 10);
      final entries = [
        CareScheduleEntry(
          id: '1',
          shopId: 's',
          scheduledAt: DateTime(2026, 9, 3, 12, 30),
          customerName: '김민정',
          note: '상담예약',
        ),
      ];
      final chip = MemoDisplayPolicy.collapsedChip(
        entries: entries,
        now: now,
      );
      expect(chip, isNotNull);
      expect(chip!.showDatePrefix, isTrue);
      expect(
        MemoDisplayPolicy.formatChipLabel(chip),
        contains('김민정'),
      );
    });
  });
}
