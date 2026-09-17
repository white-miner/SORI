import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/home_dashboard_controller.dart';
import 'package:sori/features/visit/widgets/home_hero_card.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeHeroCard renders flip clock inside scroll view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore.instance;
    final ctrl = HomeDashboardController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeroCard(
                  store: store,
                  controller: ctrl,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(FlipClockDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
