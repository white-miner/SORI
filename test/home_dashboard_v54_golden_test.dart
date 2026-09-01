import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/visit_kernel/models/preset_slot_tint.dart';

/// Renders v5.4 visual constitution swatches (no GoogleFonts — CI-safe).
class HomeVisualGoldenHarness extends StatelessWidget {
  const HomeVisualGoldenHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeVisualTokens.canvasBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwatchRow(
              label: 'walk-in',
              colors: const [
                HomeVisualTokens.careGreen,
                HomeVisualTokens.walkInReturningFill,
              ],
              heights: const [56, 56],
            ),
            const SizedBox(height: 12),
            _SwatchRow(
              label: 'toolbox-icons',
              colors: const [HomeVisualTokens.toolboxIconColor],
              heights: const [HomeVisualTokens.toolboxIconSize],
              showIcon: true,
            ),
            const SizedBox(height: 12),
            _SwatchRow(
              label: 'preset-chips',
              colors: PresetSlotTint.palette.map((t) => t.color).toList(),
              heights: List.filled(5, HomeVisualTokens.presetTimeChipH),
              widths: List.filled(5, 48),
              radii: List.filled(5, HomeVisualTokens.presetTimeChipRadius),
            ),
            const SizedBox(height: 12),
            _SwatchRow(
              label: 'stacked-chips',
              colors: const [
                HomeVisualTokens.careGreen,
                Color(0xFFFF9500),
              ],
              heights: const [
                HomeVisualTokens.stackedFrontH,
                HomeVisualTokens.stackedBackH,
              ],
              widths: const [
                HomeVisualTokens.stackedFrontW,
                HomeVisualTokens.stackedBackW,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.label,
    required this.colors,
    required this.heights,
    this.widths,
    this.radii,
    this.showIcon = false,
  });

  final String label;
  final List<Color> colors;
  final List<double> heights;
  final List<double>? widths;
  final List<double>? radii;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
          ),
        ),
        for (var i = 0; i < colors.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          if (showIcon)
            Icon(
              Icons.timer_outlined,
              size: heights[i],
              color: colors[i],
            )
          else
            Container(
              width: widths?[i] ?? 48,
              height: heights[i],
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(
                  radii?[i] ?? heights[i] / 2,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home dashboard golden v5.4', () {
    testWidgets('visual constitution harness matches golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 280));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeVisualGoldenHarness(),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(HomeVisualGoldenHarness),
        matchesGoldenFile('goldens/home_visual_constitution_v54.png'),
      );
    });
  });
}
