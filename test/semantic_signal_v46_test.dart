import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/models/clinical_trend_snapshot.dart';
import 'package:sori/features/operation/models/shop_climate_context.dart';
import 'package:sori/features/operation/models/skin_stress_index.dart';
import 'package:sori/features/operation/widgets/consultation_widget_board.dart';
import 'package:sori/features/operation/widgets/environment_widget_card.dart';
import 'package:sori/features/operation/widgets/semantic_band_theme.dart';
import 'package:sori/features/operation/widgets/semantic_signal_theme.dart';
import 'package:sori/features/operation/widgets/trend_radar_widget_card.dart';
import 'package:sori/features/operation/widgets/widget_glass_card.dart';

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

    testWidgets('ConsultationWidgetBoard renders env + trend cards', (
      tester,
    ) async {
      final climate = ShopClimateContext.fallback();
      final trends = ClinicalTrendSnapshot.fallback();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsultationWidgetBoard(
                climate: climate,
                trends: trends,
                tempoLevel: 2,
                onEnvironmentDetail: () {},
                onTrendDetail: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('ENV · CLINICAL ASSISTANT'), findsOneWidget);
      expect(find.textContaining('TREND · CLINICAL RADAR'), findsOneWidget);
      expect(find.text('详情'), findsNWidgets(2));
      expect(find.textContaining('홍조'), findsWidgets);
    });

    testWidgets('WidgetDetailChevron is tappable without card InkWell', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentWidgetCard(
              climate: ShopClimateContext.fallback(),
              tempoLevel: 3,
              onDetail: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('详情'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Environment hero score uses achromatic text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentWidgetCard(
              climate: ShopClimateContext.fallback(),
              tempoLevel: 2,
              onDetail: () {},
            ),
          ),
        ),
      );

      final scoreFinder = find.text('37');
      expect(scoreFinder, findsOneWidget);
      final text = tester.widget<Text>(scoreFinder);
      expect(text.style?.color, SemanticSignalTheme.heroTextColor);
    });
  });
}
