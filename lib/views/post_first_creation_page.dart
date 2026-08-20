import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// 포스트 퍼스트 — B/A 사진 우선 업로드 진입 화면 (플레이스홀더).
class PostFirstCreationPage extends StatelessWidget {
  const PostFirstCreationPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PostFirstCreationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          '새 게시물',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_box_outlined,
                size: 56,
                color: SoriTokens.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 16),
              const Text(
                '포스트 퍼스트',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'B/A 사진을 먼저 올리고 차트를 나중에 연결하는\n빠른 게시 플로우가 여기에 이어집니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
