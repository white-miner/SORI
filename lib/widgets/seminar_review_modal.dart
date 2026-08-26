import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 에스크로 릴리즈용 인사이트 태그 리뷰 — 별점 UI 없음.
class SeminarReviewModal extends StatefulWidget {
  const SeminarReviewModal({
    super.key,
    required this.store,
    required this.enrollmentId,
    required this.classId,
    required this.classTitle,
  });

  final SoriStore store;
  final String enrollmentId;
  final String classId;
  final String classTitle;

  static const insightTagOptions = [
    '#이해쏙쏙',
    '#실무적용도100%',
    '#케이스분석탁월',
    '#현장감최고',
    '#원장님권위있음',
    '#재수강의사있음',
    '#동료추천각',
    '#에스크로안심',
  ];

  static Future<bool> show(
    BuildContext context, {
    required SoriStore store,
    required String enrollmentId,
    required String classId,
    required String classTitle,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SeminarReviewModal(
        store: store,
        enrollmentId: enrollmentId,
        classId: classId,
        classTitle: classTitle,
      ),
    ).then((v) => v == true);
  }

  @override
  State<SeminarReviewModal> createState() => _SeminarReviewModalState();
}

class _SeminarReviewModalState extends State<SeminarReviewModal> {
  final _commentCtrl = TextEditingController();
  final _selected = <String>{};
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('긍정 인사이트 태그를 1개 이상 선택해 주세요.'),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final reviewOk = await widget.store.submitSeminarEnrollmentReview(
      enrollmentId: widget.enrollmentId,
      insightTags: _selected.toList(growable: false),
      comment: _commentCtrl.text.trim(),
    );

    if (!mounted) return;

    if (!reviewOk) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError?.trim().isNotEmpty == true
                ? widget.store.lastError!.trim()
                : '리뷰 저장에 실패했습니다.',
          ),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }

    final net = await widget.store.settleSeminarEnrollment(widget.enrollmentId);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (net <= 0 && widget.store.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError!.trim().isNotEmpty
                ? widget.store.lastError!.trim()
                : '정산에 실패했습니다.',
          ),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }

    await widget.store.refreshSeminarFeedbackReport(widget.classId);
    await widget.store.refreshSeminarFeedbackReports();

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        '수강 인사이트 남기기',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.classTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '인사이트 태그 리뷰 제출 후 에스크로 정산이 진행됩니다.\n'
                '별점 대신 수업 경험 태그로 남겨 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '이 수업의 긍정 인사이트 (다중 선택)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in SeminarReviewModal.insightTagOptions)
                  FilterChip(
                    label: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selected.contains(tag)
                            ? SoriTokens.primary
                            : Colors.grey.shade700,
                      ),
                    ),
                    selected: _selected.contains(tag),
                    onSelected: _submitting
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selected.add(tag);
                              } else {
                                _selected.remove(tag);
                              }
                            });
                          },
                    selectedColor: SoriTokens.primarySoft,
                    checkmarkColor: SoriTokens.primary,
                    side: BorderSide(
                      color: _selected.contains(tag)
                          ? SoriTokens.primary.withValues(alpha: 0.4)
                          : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _commentCtrl,
              enabled: !_submitting,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '추가 한마디 (선택)',
                hintText: '현장에서 바로 써먹을 수 있었던 포인트 등',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting || _selected.isEmpty ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: SoriTokens.primary, foregroundColor: SoriTokens.onPrimary),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '제출하고 수강 완료',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}
