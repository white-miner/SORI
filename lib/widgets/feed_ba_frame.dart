import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 글로벌 피드 B/A 표준 프레임 — 1:1 정방형, 높이 최대 400(또는 뷰포트 50%).
class FeedBaFrame extends StatelessWidget {
  const FeedBaFrame({super.key, required this.child});

  static const double maxSide = 400;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewportH = MediaQuery.sizeOf(context).height;
    final cap = math.min(maxSide, viewportH * 0.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final side = math.min(w, cap);
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: side,
            height: side,
            child: AspectRatio(aspectRatio: 1, child: child),
          ),
        );
      },
    );
  }
}
