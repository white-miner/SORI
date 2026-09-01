import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home_dashboard_controller.dart';

class CountdownFlipZone extends StatelessWidget {
  const CountdownFlipZone({
    super.key,
    required this.controller,
  });

  final HomeDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final digits = controller.countDigits;
    final blink = controller.countBlinkVisible;

    return AnimatedOpacity(
      opacity: blink ? 0.35 : 1,
      duration: const Duration(milliseconds: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i == 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: GoogleFonts.nunito(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            _DigitTile(
              digit: digits[i],
              tappable: controller.heroMode == HomeHeroMode.countSetup,
              onTap: () {
                final next = (digits[i] + 1) % 10;
                controller.onCountDigitTap(i, next);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DigitTile extends StatelessWidget {
  const _DigitTile({
    required this.digit,
    required this.tappable,
    required this.onTap,
  });

  final int digit;
  final bool tappable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        width: 56,
        height: 72,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$digit',
          style: GoogleFonts.nunito(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
