import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/models/shop_climate_context.dart';
import 'package:sori/features/operation/models/skin_stress_index.dart';
import 'package:sori/features/operation/widgets/consultation_widget_board.dart';
import 'package:sori/features/operation/widgets/environment_widget_card.dart';
import 'package:sori/features/operation/widgets/semantic_band_theme.dart';
import 'package:sori/features/operation/widgets/semantic_signal_theme.dart';

void main() {
  group('PRD v4.6 semantic signal', () {
    test('moderate SSI maps to Yellow not Orange', () {
      expect(
        SemanticSignalTheme.bandForSsiBand(SsiBand.moderate),
        SemanticBand.yellow,
      );
      expect(
        SemanticSignalTheme.bandColor(
          SemanticSignalTheme.bandForSsiBand(SsiBand.moderate),
        ),
        const Color(0xFFFFCC00),
      );
    });

    test('surge red threshold is 40%', () {
      expect(
        SemanticSignalTheme.bandForSurge(39),
        SemanticBand.orange,
      );
      expect(
        SemanticSignalTheme.bandForSurge(40),
        SemanticBand.red,
      );
    });

    test('headline band follows UV alert key', () {
      expect(
        SemanticSignalTheme.headlineBand(
          headline: '자외선 주의',
          alertKeys: const ['uv_high'],
          ssiScore: 37,
          uvIndex: 7,
        ),
        SemanticSignalTheme.bandForUv(7),
      );
    });

    test('legacy SemanticBandTheme delegates to signal theme', () {
      expect(
        SemanticBandTheme.ssiArcColor(SsiBand.low),
        SemanticSignalTheme.green,
      );
    });
  });

  group('PRD v4.4/v4.6 widget board', () {
    test('computeTempoLevel scales with schedule load', () {
      expect(
        computeTempoLevel(scheduledCount: 8, inProgressCount: 1),
        4,
      );
      expect(
        computeTempoLevel(scheduledCount: 1, inProgressCount: 0),
        1,
      );
    });

    testWidgets('ConsultationWidgetBoard renders ENV weather card only', (
      tester,
    ) async {
      final climate = ShopClimateContext.fallback();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsultationWidgetBoard(
                climate: climate,
                onEnvironmentDetail: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('ENV · CLINICAL ASSISTANT'), findsNothing);
      expect(find.textContaining('TREND · CLINICAL RADAR'), findsNothing);
      expect(find.text('详情'), findsNothing);
      expect(find.text('습도'), findsOneWidget);
      expect(find.text('미세먼지'), findsOneWidget);
    });

    testWidgets('EnvironmentWidgetCard tap opens detail', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentWidgetCard(
              climate: ShopClimateContext.fallback(),
              onDetail: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EnvironmentWidgetCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Environment hero temp uses achromatic text', (tester) async {
      final climate = ShopClimateContext.fallback();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentWidgetCard(
              climate: climate,
              onDetail: () {},
            ),
          ),
        ),
      );

      final tempFinder = find.text('${climate.tempC.round()}°');
      expect(tempFinder, findsWidgets);
      final text = tester.widget<Text>(tempFinder.first);
      expect(text.style?.color, SemanticSignalTheme.heroTextColor);
    });
  });
}
