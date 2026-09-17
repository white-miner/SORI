import 'package:flutter/material.dart';

/// 관리 케이스 피드 — PC에서도 카드가 720px를 넘지 않도록 중앙 정렬.
class CaseFeedViewport extends StatelessWidget {
  const CaseFeedViewport({super.key, required this.child});

  static const double maxWidth = 720;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
