import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/message_service.dart';
import '../theme/sori_tokens.dart';
import '../widgets/message_card.dart';

class MyHomePage extends StatefulWidget {
  final List<Customer> customers;

  const MyHomePage({super.key, required this.customers});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const Color soriPurple = Color(0xFF6C5CE7);
  late List<PendingMessage> _pendingMessages;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadMessages();
  }

  void _loadMessages() {
    _pendingMessages = MessageService.generatePendingMessages(widget.customers);
  }

  void _sendAllMessages() {
    if (_pendingMessages.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('1-Click 전체 발송 승인'),
        content: Text('총 ${_pendingMessages.length}명의 고객에게 맞춤 케어 메시지를 일괄 발송하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: soriPurple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingMessages.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('모든 케어 알림 메시지가 성공적으로 발송되었습니다.'),
                  backgroundColor: soriPurple,
                ),
              );
            },
            child: const Text('발송 승인'),
          ),
        ],
      ),
    );
  }

  void _showMessageDetail(PendingMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${message.customerName}님 케어 메시지'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: soriPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                message.careType,
                style: const TextStyle(fontSize: 12, color: soriPurple, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.messagePreview,
                style: const TextStyle(
                  height: 1.4,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: soriPurple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingMessages.removeWhere((m) => m.customerId == message.customerId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${message.customerName}님에게 메시지를 발송했습니다.'),
                  backgroundColor: soriPurple,
                ),
              );
            },
            child: const Text('개별 발송'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingMessages.length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(pendingCount),
                  const SizedBox(height: 24),
                  _buildOneClickApprovalCard(context),
                  const SizedBox(height: 28),
                  _buildSectionTitle(pendingCount),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_pendingMessages.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Center(
                  child: Text(
                    '모든 케어 메시지 발송이 완료되었습니다. 🎉',
                    style: const TextStyle(
                      fontSize: 14,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.separated(
                itemCount: _pendingMessages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final message = _pendingMessages[index];
                  return MessageCard(
                    customerName: message.customerName,
                    careType: message.careType,
                    messagePreview: message.messagePreview,
                    scheduledTime: message.scheduledTime,
                    onTap: () => _showMessageDetail(message),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int pendingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: soriPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'SORI',
                style: TextStyle(
                  color: soriPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              height: 1.4,
              color: SoriTokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: '원장님, 오늘 '),
              TextSpan(
                text: '소리',
                style: const TextStyle(
                  color: soriPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '가 준비한\n고객 케어 알림 '),
              TextSpan(
                text: '$pendingCount건',
                style: const TextStyle(
                  color: soriPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '이 있습니다'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOneClickApprovalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            soriPurple,
            soriPurple.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: soriPurple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1-Click 전체 발송 승인하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '검토 완료된 메시지를 한 번에 발송합니다',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _pendingMessages.isEmpty ? null : _sendAllMessages,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: soriPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _pendingMessages.isEmpty ? '발송할 메시지 없음' : '전체 발송 승인',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(int pendingCount) {
    return Row(
      children: [
        const Text(
          '발송 대기 메시지',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: soriPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$pendingCount',
            style: const TextStyle(
              color: soriPurple,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
