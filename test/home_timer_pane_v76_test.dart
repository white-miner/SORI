import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/features/operation/widgets/care_timer_floating_bar.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/widgets/home_timer_customer_bind.dart';
import 'package:sori/features/visit/widgets/home_timer_stage.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/preset_slot_tint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('HomeTimerStage embeds flip clock + control bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTimerStage(
            onExpandFullscreen: () {},
            onCareStart: () {},
            onCareEnd: () {},
            onOpenPresetEditor: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-timer-stage')), findsOneWidget);
    expect(find.byType(FlipClockDisplay), findsOneWidget);
    expect(find.byKey(const Key('home-timer-step-clock')), findsOneWidget);
    expect(find.byType(CareTimerFloatingBar), findsOneWidget);
    expect(find.text('케어 시작'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
    expect(find.byKey(const Key('home-timer-title-bar')), findsOneWidget);
    final clock = tester.widget<FlipClockDisplay>(
      find.byKey(const Key('home-timer-step-clock')),
    );
    expect(clock.style, FlipClockStyle.darkGlass);
    expect(clock.showSeconds, isTrue);
  });

  testWidgets('케어 종료 버튼은 System Red다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('home-timer-care-end'),
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: PresetSlotTint.iosRed,
                  ),
                  child: const Text('케어 종료'),
                ),
              );
            },
          ),
        ),
      ),
    );
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('home-timer-care-end')),
    );
    expect(btn.style?.backgroundColor?.resolve({}), PresetSlotTint.iosRed);
  });

  testWidgets('HomeTimerCustomerBind On 시 (+)와 프로필 폼이 펼쳐진다', (
    tester,
  ) async {
    final store = SoriStore();
    var enabled = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return HomeTimerCustomerBind(
                store: store,
                enabled: enabled,
                customer: null,
                onEnabledChanged: (v) => setState(() => enabled = v),
                onPickCustomer: () {},
                onClear: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-timer-customer-bind')), findsOneWidget);
    expect(find.byKey(const Key('home-timer-customer-add')), findsOneWidget);
    expect(find.text('차트 / 이름'), findsOneWidget);
    expect(find.text('연락처'), findsOneWidget);
  });
}
