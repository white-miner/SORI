import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../visit_kernel/messaging/sori_platform_alimtalk.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';

/// 고객 희망 일정 리드 — SORI 링크 공개 페이지 (Phase CRM-1).
class CareScheduleLeadPage extends StatefulWidget {
  const CareScheduleLeadPage({
    super.key,
    required this.store,
    required this.shopId,
  });

  final SoriStore store;
  final String shopId;

  @override
  State<CareScheduleLeadPage> createState() => _CareScheduleLeadPageState();
}

class _CareScheduleLeadPageState extends State<CareScheduleLeadPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _careCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _preferredDay = DateTime.now();
  TimeOfDay _preferredTime = const TimeOfDay(hour: 14, minute: 0);
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _careCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 연락처를 입력해 주세요.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final preferredAt = DateTime(
        _preferredDay.year,
        _preferredDay.month,
        _preferredDay.day,
        _preferredTime.hour,
        _preferredTime.minute,
      );
      await widget.store.submitCareScheduleLead(
        shopId: widget.shopId,
        customerName: name,
        customerPhone: phone,
        preferredAt: preferredAt,
        careLabel: _careCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      );
      await widget.store.sendPlatformAlimtalk(
        SoriPlatformAlimtalkMessage(
          templateCode: SoriPlatformAlimtalk.templates.scheduleLeadAck,
          recipientPhone: phone,
          shopId: widget.shopId,
          shopName: widget.store.shop.name,
          variables: {
            'customer': name,
            'date': '${preferredAt.month}/${preferredAt.day}',
          },
        ),
      );
      if (!mounted) return;
      setState(() => _done = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: SoriTokens.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: VisitGlassTokens.sage,
                ),
                const SizedBox(height: 16),
                const Text(
                  '희망 일정이 전달되었어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '원장님이 확인 후 연락드릴 예정이에요.',
                  textAlign: TextAlign.center,
                  style: VisitGlassTokens.bodyCalm.copyWith(
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(onPressed: () => context.pop(), child: const Text('닫기')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('희망 일정 요청'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: VisitGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.store.shop.name.trim().isEmpty
                    ? 'SORI 샵'
                    : widget.store.shop.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '원하시는 방문 일정을 남겨 주세요. 확정 예약이 아닌 상담 리드입니다.',
                style: VisitGlassTokens.captionCalm.copyWith(
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '연락처'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _careCtrl,
                decoration: const InputDecoration(
                  labelText: '희망 케어 (선택)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: VisitGlassTokens.care,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_submitting ? '전송 중…' : '희망 일정 보내기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
