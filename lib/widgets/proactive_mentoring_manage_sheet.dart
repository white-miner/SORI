import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

Future<bool> showProactiveMentoringManageSheet(
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
    builder: (ctx) => _ProactiveMentoringManageBody(store: store, item: item),
  );
  return result == true;
}

class _ProactiveMentoringManageBody extends StatefulWidget {
  const _ProactiveMentoringManageBody({
    required this.store,
    required this.item,
  });

  final SoriStore store;
  final CommunityCaseItem item;

  @override
  State<_ProactiveMentoringManageBody> createState() =>
      _ProactiveMentoringManageBodyState();
}

class _ProactiveMentoringManageBodyState
    extends State<_ProactiveMentoringManageBody> {
  late final TextEditingController _teaserCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _priceCtrl;
  bool _busy = false;
  String? _mentoringPostId;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final meta = widget.item.mentoring;
    _teaserCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _priceCtrl = TextEditingController(text: '${meta?.priceEcho ?? 50}');
    _mentoringPostId = meta?.mentoringPostId;
    _status = meta?.status ?? '';
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail =
        await widget.store.loadMentoringForChart(widget.item.chart.id);
    if (!mounted || !detail.exists) return;
    _mentoringPostId = detail.id;
    _status = detail.status;
    if (_teaserCtrl.text.trim().isEmpty) {
      _teaserCtrl.text = detail.previewTeaser;
    }
    if (_bodyCtrl.text.trim().isEmpty && detail.bodyLocked != null) {
      _bodyCtrl.text = detail.bodyLocked!.trim();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _teaserCtrl.dispose();
    _bodyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool publish}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final price = int.tryParse(_priceCtrl.text.trim()) ?? 50;
      final result = await widget.store.upsertProactiveMentoring(
        chartId: widget.item.chart.id,
        teaser: _teaserCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        priceEcho: price,
      );
      _mentoringPostId = result.mentoringPostId;
      _status = result.status;
      if (publish && _mentoringPostId != null) {
        await widget.store.publishMentoringPost(_mentoringPostId!);
        _status = 'active';
      }
      await widget.store.refreshCommunityHotCases();
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish
                ? 'Premium Mentoring이 게시되었습니다.'
                : '멘토링 초안이 저장되었습니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장에 실패했습니다: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isActive = _status == 'active';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              '멘토링 작성/관리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.item.chart.careName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              const Text(
                '현재 Live — 수정 후 다시 저장하면 피드 잠금 배지에 반영됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4338CA),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _teaserCtrl,
              decoration: const InputDecoration(
                labelText: '미리보기 한 줄 (Teaser)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: '멘토링 본문 (20자 이상)',
                border: OutlineInputBorder(),
              ),
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Echo 가격',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _save(publish: false),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('초안 저장'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(publish: true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
              ),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(isActive ? 'Live 업데이트' : 'Live 게시 (🔒 Lock)'),
            ),
          ],
        ),
      ),
    );
  }
}
