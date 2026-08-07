import 'package:flutter/material.dart';

class MessageHistoryPage extends StatelessWidget {
  const MessageHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '메시지 이력',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '발송 완료된 메시지 기록을 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Color(0xFFB2BEC3),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '아직 발송 이력이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF636E72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
