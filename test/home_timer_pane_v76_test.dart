import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/features/operation/widgets/care_timer_floating_bar.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/widgets/home_timer_customer_bind.dart';
import 'package:sori/features/visit/widgets/home_timer_stage.dart';
import 'package:sori/services/sori_store.dart';

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
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-timer-stage')), findsOneWidget);
    expect(find.byType(FlipClockDisplay), findsOneWidget);
    expect(find.byType(CareTimerFloatingBar), findsOneWidget);
    expect(find.text('케어 시작'), findsOneWidget);
  });

  testWidgets('HomeTimerCustomerBind shows mini form when enabled', (
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
    expect(find.text('고객 차트 연결'), findsOneWidget);
    expect(find.text('고객을 선택해 차트에 연결하세요'), findsOneWidget);
  });
}
