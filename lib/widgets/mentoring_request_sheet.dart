import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Director → case author Premium Mentoring request composer.
Future<bool> showMentoringRequestSheet(
  BuildContext context, {
  required SoriStore store,
  required CommunityCaseItem item,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MentoringRequestSheetBody(store: store, item: item),
  );
  return result == true;
}

class _MentoringRequestSheetBody extends StatefulWidget {
  const _MentoringRequestSheetBody({
    required this.store,
    required this.item,
  });

  final SoriStore store;
  final CommunityCaseItem item;

  @override
  State<_MentoringRequestSheetBody> createState() =>
      _MentoringRequestSheetBodyState();
}

class _MentoringRequestSheetBodyState extends State<_MentoringRequestSheetBody> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.length < 20 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.store.submitMentoringRequest(
        chartId: widget.item.chart.id,
        questionBody: text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('멘토링 요청 전송에 실패했습니다: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final care = widget.item.chart.careName.trim();
    final len = _controller.text.trim().length;
    final canSubmit = len >= 20 && !_submitting;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mentoring Request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            care.isEmpty
                ? '이 B/A 케이스에 대해 원장님께 질문을 남겨 주세요.'
                : '$care — 원장님께 멘토링 질문을 남겨 주세요.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(color: SoriTokens.textPrimary),
            decoration: InputDecoration(
              hintText: '임상 포인트, 장비 세팅, 홈케어 연계 등 (20자 이상)',
              hintStyle: const TextStyle(color: SoriTokens.textSecondary),
              filled: true,
              fillColor: SoriTokens.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$len / 20자 이상',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: len >= 20
                  ? SoriTokens.primary
                  : SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '요청 보내기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Feed chip — active Premium Mentoring lock badge.
class PremiumMentoringFeedChip extends StatelessWidget {
  const PremiumMentoringFeedChip({
    super.key,
    required this.priceEcho,
    this.compact = false,
    this.onTap,
  });

  final int priceEcho;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = compact
        ? '🔒 $priceEcho E'
        : '🔒 Premium Mentoring ($priceEcho E)';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0x1A6366F1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x666366F1)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
              color: Color(0xFF4338CA),
            ),
          ),
        ),
      ),
    );
  }
}
