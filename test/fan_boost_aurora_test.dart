import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/widgets/animated_booster_avatar.dart';

void main() {
  testWidgets('AnimatedBoosterAvatar spins ring when isBoosted (AD)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedBoosterAvatar(
              key: Key('ad-boosted'),
              imageUrl: '',
              isBoosted: true,
              isFanBoost: false,
              premiumTier: '',
              radius: 18,
            ),
          ),
        ),
      ),
    );
    final avatar = find.byKey(const Key('ad-boosted'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(RotationTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: avatar, matching: find.byType(DecoratedBox)),
      findsWidgets,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('AnimatedBoosterAvatar has no ring when not boosted',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedBoosterAvatar(
              key: Key('plain'),
              imageUrl: '',
              isBoosted: false,
              radius: 18,
            ),
          ),
        ),
      ),
    );
    final avatar = find.byKey(const Key('plain'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(RotationTransition)),
      findsNothing,
    );
  });
}
