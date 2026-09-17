import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/home_dashboard_controller.dart';
import 'package:sori/features/visit/widgets/home_hero_card.dart';
import 'package:sori/features/visit/widgets/home_wall_clock.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1초 틱마다 벽시계 초가 바뀐다', (tester) async {
    var now = DateTime(2026, 9, 3, 11, 30, 4);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeWallClock(now: () => now),
      ),
    );
    await tester.pump();

    final first = tester.widget<FlipClockDisplay>(find.byType(FlipClockDisplay));
    expect(first.totalSeconds, 11 * 3600 + 30 * 60 + 4);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final next = tester.widget<FlipClockDisplay>(find.byType(FlipClockDisplay));
    expect(next.totalSeconds, 11 * 3600 + 30 * 60 + 5);
  });

  testWidgets('틱은 형제 위젯을 다시 그리지 않는다', (tester) async {
    var now = DateTime(2026, 9, 3, 11, 30, 0);
    var siblingBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            HomeWallClock(now: () => now),
            Builder(
              builder: (_) {
                siblingBuilds++;
                return const Text('sibling');
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(siblingBuilds, 1);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(siblingBuilds, 1);
    expect(
      tester.widget<FlipClockDisplay>(find.byType(FlipClockDisplay)).totalSeconds,
      11 * 3600 + 30 * 60 + 1,
    );
  });

  testWidgets('트리에서 빠지면 틱이 멈춘다', (tester) async {
    var now = DateTime(2026, 9, 3, 11, 30, 0);
    await tester.pumpWidget(
      MaterialApp(home: HomeWallClock(now: () => now)),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(HomeWallClock), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeHeroCard 는 격리된 벽시계를 쓴다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ctrl = HomeDashboardController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHeroCard(
            store: SoriStore(),
            controller: ctrl,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HomeWallClock), findsOneWidget);
    expect(find.byType(FlipClockDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
