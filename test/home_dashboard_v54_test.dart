import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/features/operation/visit_timer_local_cache.dart';
import 'package:sori/features/operation/visit_timer_store.dart';
import 'package:sori/features/visit/models/care_timer_entry_mode.dart';
import 'package:sori/visit_kernel/models/care_program_template.dart';

void main() {
  group('VisitTimerStore Path C v5.4', () {
    test('isPathCEligible requires homeSelectedPresetSlot with preset', () {
      final store = VisitTimerStore.instance;
      store.homeSelectedPresetSlot = null;
      expect(store.isPathCEligible, isFalse);

      store.homeSelectedPresetSlot = 0;
      store.presets = [
        CareProgramTemplate.empty(shopId: 's', slotIndex: 0),
      ];
      expect(store.isPathCEligible, isFalse);

      store.presets = [
        CareProgramTemplate(
          id: 'p1',
          shopId: 's',
          slotIndex: 0,
          name: '테스트',
          steps: const [CareProgramStep(minutes: 60, label: '1')],
        ),
      ];
      expect(store.isPathCEligible, isTrue);
    });
  });

  group('VisitTimerLocalCache home slot', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists and loads homeSelectedPresetSlot', () async {
      await VisitTimerLocalCache.saveHomeSelectedPresetSlot('shop-a', 2);
      expect(
        await VisitTimerLocalCache.loadHomeSelectedPresetSlot('shop-a'),
        2,
      );
      await VisitTimerLocalCache.saveHomeSelectedPresetSlot('shop-a', null);
      expect(
        await VisitTimerLocalCache.loadHomeSelectedPresetSlot('shop-a'),
        isNull,
      );
    });
  });

  group('CareTimerEntryMode Path C', () {
    test('careStartQuick shows care end immediately', () {
      expect(
        CareTimerEntryMode.careStartQuick.showCareEndImmediately,
        isTrue,
      );
      expect(CareTimerEntryMode.careStartQuick.autoStartPipeline, isTrue);
    });
  });
}
