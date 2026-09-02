import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/home_visual_tokens.dart';

/// Renders v7.0 My Feed visual constitution swatches (no GoogleFonts — CI-safe).
class MyFeedVisualGoldenHarness extends StatelessWidget {
  const MyFeedVisualGoldenHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeVisualTokens.canvasBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _SwatchRow(
              label: 'quick-action',
              swatches: [
                _Swatch(
                  color: HomeVisualTokens.quickNewFill,
                  width: 92,
                  height: HomeVisualTokens.quickActionHeight,
                  radius: HomeVisualTokens.quickActionRadius,
                ),
                _Swatch(
                  color: HomeVisualTokens.quickReturningFill,
                  width: 92,
                  height: HomeVisualTokens.quickActionHeight,
                  radius: HomeVisualTokens.quickActionRadius,
                  border: HomeVisualTokens.quickReturningBorder,
                ),
              ],
            ),
            SizedBox(height: 12),
            _SwatchRow(
              label: 'traffic-light',
              swatches: [
                _Swatch(
                  color: HomeVisualTokens.baDotRed,
                  width: HomeVisualTokens.baDotSize,
                  height: HomeVisualTokens.baDotSize,
                  radius: HomeVisualTokens.baDotSize / 2,
                ),
                _Swatch(
                  color: HomeVisualTokens.baDotGreen,
                  width: HomeVisualTokens.baDotSize,
                  height: HomeVisualTokens.baDotSize,
                  radius: HomeVisualTokens.baDotSize / 2,
                ),
                _Swatch(
                  color: HomeVisualTokens.memoIdleFill,
                  width: HomeVisualTokens.memoDotSize,
                  height: HomeVisualTokens.memoDotSize,
                  radius: HomeVisualTokens.memoDotSize / 2,
                ),
              ],
            ),
            SizedBox(height: 12),
            _SwatchRow(
              label: 'ba-card',
              swatches: [
                _Swatch(
                  color: HomeVisualTokens.baSlotFill,
                  width: HomeVisualTokens.baCardW,
                  height: HomeVisualTokens.baCardH,
                  radius: HomeVisualTokens.baCardRadius,
                ),
                _Swatch(
                  color: Colors.white,
                  width: HomeVisualTokens.baAddCircle,
                  height: HomeVisualTokens.baAddCircle,
                  radius: HomeVisualTokens.baAddCircle / 2,
                ),
              ],
            ),
            SizedBox(height: 12),
            _SwatchRow(
              label: 'case-card',
              swatches: [
                _Swatch(
                  color: HomeVisualTokens.caseCardFill,
                  width: 120,
                  height: 44,
                  radius: HomeVisualTokens.caseCardRadius,
                ),
                _Swatch(
                  color: HomeVisualTokens.casePillFill,
                  width: 54,
                  height: 22,
                  radius: 12,
                ),
                // 캡션 영역 — 헤어라인으로 사진과 끊고, 본문은 읽히는 회색.
                _Swatch(
                  color: HomeVisualTokens.caseCaptionDivider,
                  width: 54,
                  height: 22,
                  radius: 2,
                ),
                _Swatch(
                  color: HomeVisualTokens.caseCaptionColor,
                  width: 54,
                  height: 22,
                  radius: 2,
                ),
              ],
            ),
            SizedBox(height: 12),
            _SwatchRow(
              label: 'tab-bar',
              swatches: [
                _Swatch(
                  color: HomeVisualTokens.tabActiveColor,
                  width: 64,
                  height: 2,
                  radius: 1,
                ),
                _Swatch(
                  color: HomeVisualTokens.tabInactiveColor,
                  width: 64,
                  height: 2,
                  radius: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch {
  const _Swatch({
    required this.color,
    required this.width,
    required this.height,
    required this.radius,
    this.border,
  });

  final Color color;
  final double width;
  final double height;
  final double radius;
  final Color? border;
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.label, required this.swatches});

  final String label;
  final List<_Swatch> swatches;

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
        for (var i = 0; i < swatches.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: swatches[i].width,
            height: swatches[i].height,
            decoration: BoxDecoration(
              color: swatches[i].color,
              borderRadius: BorderRadius.circular(swatches[i].radius),
              border: swatches[i].border == null
                  ? null
                  : Border.all(color: swatches[i].border!),
            ),
          ),
        ],
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('My Feed golden v7.0', () {
    testWidgets('visual constitution harness matches golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 340));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MyFeedVisualGoldenHarness()),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(MyFeedVisualGoldenHarness),
        matchesGoldenFile('goldens/my_feed_constitution_v70.png'),
      );
    });
  });
}
