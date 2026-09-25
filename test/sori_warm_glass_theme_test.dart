import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sori/theme/app_theme.dart';
import 'package:sori/theme/sori_glass_theme.dart';
import 'package:sori/theme/sori_tokens.dart';

/// 2026-09-26 — warm canvas #FBF9F6 as app default + no-blur glass controls.
void main() {
  late ThemeData theme;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Font files are not bundled for tests and google_fonts reports that
    // asynchronously. Only colours/styles are asserted here, so swallow it.
    theme = runZonedGuarded(() => AppTheme.theme, (error, stack) {})!;
  });

  const warm = Color(0xFFFBF9F6);

  test('warm-white canvas is the app default; surfaces stay white', () {
    expect(SoriTokens.canvas, warm);
    expect(SoriTokens.background, warm);
    expect(theme.scaffoldBackgroundColor, warm);
    expect(theme.canvasColor, warm);
    expect(theme.appBarTheme.backgroundColor, warm);

    expect(theme.colorScheme.surface, SoriTokens.surface);
    expect(theme.cardTheme.color, SoriTokens.surface);
    expect(theme.dialogTheme.backgroundColor, SoriTokens.surface);
    expect(theme.inputDecorationTheme.fillColor, SoriTokens.surface);

    // fillMuted must read against both white cards and the canvas.
    expect(SoriTokens.fillMuted, isNot(SoriTokens.surface));
    expect(SoriTokens.fillMuted, isNot(SoriTokens.canvas));
    expect(
      SoriTokens.fillMuted.computeLuminance(),
      lessThan(SoriTokens.canvas.computeLuminance()),
    );
  });

  test('SoriGlassTheme extension is registered', () {
    final glass = theme.extension<SoriGlassTheme>();
    expect(glass, isNotNull);
    expect(glass, same(SoriGlassTheme.standard));
    expect(glass!.fill.a, inInclusiveRange(0.6, 0.95));
    expect(glass.fillPressed.a, greaterThan(glass.fill.a));
    expect(glass.border.a, inInclusiveRange(0.05, 0.15));
    expect(glass.shadows, isNotEmpty);
    expect(glass.blurSigma, greaterThan(0));
    expect(glass.onMediaForeground, Colors.white);
    expect(glass.lerp(glass, 0.5).fill, glass.fill);
  });

  test('outlined buttons: translucent glass fill, hairline, shadow', () {
    final glass = SoriGlassTheme.standard;
    final style = theme.outlinedButtonTheme.style!;
    final idle = style.backgroundColor!.resolve(<WidgetState>{})!;
    expect(idle.a, lessThan(1));
    expect(idle.a, greaterThan(0.5));
    expect(idle, glass.fill);
    expect(
      style.backgroundColor!.resolve({WidgetState.pressed}),
      glass.fillPressed,
    );
    expect(style.side!.resolve(<WidgetState>{})!.color, glass.border);
    expect(style.elevation!.resolve(<WidgetState>{}), glass.elevation);
    expect(style.elevation!.resolve({WidgetState.pressed}), glass.elevation);
    expect(style.elevation!.resolve({WidgetState.disabled}), 0);
    expect(style.backgroundBuilder, isNotNull);
    expect(
      style.foregroundColor!.resolve(<WidgetState>{}),
      SoriTokens.textPrimary,
    );
  });

  test('chips + segments: glass idle, charcoal selected', () {
    final glass = SoriGlassTheme.standard;
    final chip = theme.chipTheme;
    expect(chip.backgroundColor, glass.fill);
    expect(chip.backgroundColor!.a, lessThan(1));
    expect(chip.selectedColor, SoriTokens.primary);
    final side = chip.side! as WidgetStateBorderSide;
    expect(side.resolve(<WidgetState>{})!.color, glass.border);
    expect(side.resolve({WidgetState.selected}), BorderSide.none);

    final seg = theme.segmentedButtonTheme.style!;
    expect(seg.backgroundColor!.resolve(<WidgetState>{}), glass.fill);
    expect(
      seg.backgroundColor!.resolve({WidgetState.selected}),
      SoriTokens.primary,
    );
  });

  test('filled buttons stay solid charcoal; icon buttons stay transparent',
      () {
    final filled = theme.filledButtonTheme.style!;
    final bg = filled.backgroundColor!.resolve(<WidgetState>{})!;
    expect(bg, SoriTokens.primary);
    expect(bg.a, 1);
    expect(
      theme.iconButtonTheme.style!.backgroundColor!.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(theme.floatingActionButtonTheme.backgroundColor,
        SoriGlassTheme.standard.fill);
  });

  testWidgets('themed controls render glass without any BackdropFilter',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          body: ListView(
            children: [
              OutlinedButton(
                key: const Key('glass-outlined'),
                onPressed: () {},
                child: const Text('Outlined'),
              ),
              TextButton(onPressed: () {}, child: const Text('Text')),
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              ChoiceChip(
                label: const Text('idle'),
                selected: false,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('on'),
                selected: true,
                onSelected: (_) {},
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('A')),
                  ButtonSegment(value: 1, label: Text('B')),
                ],
                selected: const {0},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);

    final scaffold = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(scaffold.color, warm);

    final outlinedMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('glass-outlined')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(outlinedMaterial.color!.a, lessThan(1));
    expect(outlinedMaterial.clipBehavior, isNot(Clip.none));
    expect(tester.takeException(), isNull);
  });
}
