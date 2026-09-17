import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/models/shop_climate_context.dart';
import 'package:sori/features/operation/models/skin_stress_index.dart';
import 'package:sori/features/operation/widgets/consultation_widget_board.dart';
import 'package:sori/features/operation/widgets/environment_widget_card.dart';
import 'package:sori/features/operation/widgets/semantic_band_theme.dart';

void main() {
  group('PRD v4.4 widget board', () {
    test('SemanticBandTheme maps SSI bands to iOS colors', () {
      expect(
        SemanticBandTheme.ssiArcColor(SsiBand.low),
        const Color(0xFF34C759),
      );
      expect(
        SemanticBandTheme.ssiArcColor(SsiBand.critical),
        const Color(0xFFFF3B30),
      );
    });

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
      expect(find.text('온도'), findsOneWidget);
      expect(find.text('자외선'), findsOneWidget);
      expect(find.textContaining('최저'), findsOneWidget);
      expect(find.textContaining('최고'), findsOneWidget);
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
  });
}
