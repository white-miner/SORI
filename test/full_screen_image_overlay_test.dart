import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/widgets/before_after_slider.dart';
import 'package:sori/widgets/feed_media_carousel.dart';
import 'package:sori/widgets/post/full_screen_image_overlay.dart';

void main() {
  testWidgets('FullScreenImageOverlay centers media with symmetric inset', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    FullScreenImageOverlay.show(
                      context,
                      slides: const [
                        FeedMediaSlide.baPair(
                          beforeUrl: 'https://example.com/before.jpg',
                          afterUrl: 'https://example.com/after.jpg',
                        ),
                      ],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Stack), findsWidgets);
    expect(find.byType(Center), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    final closeFinder = find.byIcon(Icons.close_rounded);
    final closeBox = tester.renderObject<RenderBox>(closeFinder);
    expect(closeBox.localToGlobal(Offset.zero).dy, greaterThan(0));

    final sliderFinder = find.byType(BeforeAfterSlider);
    expect(sliderFinder, findsOneWidget);
    final sliderBox = tester.renderObject<RenderBox>(sliderFinder);
    final screenHeight = 844.0;
    final sliderCenterY =
        sliderBox.localToGlobal(Offset.zero).dy + sliderBox.size.height / 2;
    expect(sliderCenterY, closeTo(screenHeight / 2, 48));
  });
}
