import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../models/chart_consent_texts.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/chart_signature_storage.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 고객 프로필에서 차트 화면 이동 없이 전자 동의서를 체결하는 모달.
Future<CustomerChart?> showQuickConsentSheet({
  required BuildContext context,
  required SoriStore store,
  required Customer customer,
}) {
  return showModalBottomSheet<CustomerChart>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _QuickConsentSheet(store: store, customer: customer),
  );
}

class _QuickConsentSheet extends StatefulWidget {
  const _QuickConsentSheet({
    required this.store,
    required this.customer,
  });

  final SoriStore store;
  final Customer customer;

  @override
  State<_QuickConsentSheet> createState() => _QuickConsentSheetState();
}

class _QuickConsentSheetState extends State<_QuickConsentSheet> {
  final _signature = SignatureController(
    penStrokeWidth: 2.8,
    penColor: const Color(0xFF2D3436),
    exportBackgroundColor: Colors.white,
  );

  bool _care = false;
  bool _reaction = false;
  bool _refund = false;
  bool _photo = false;
  bool _marketing = false;
  bool _offline = false;
  var _saving = false;

  bool get _mandatory => _care && _reaction && _refund;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_mandatory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 동의 3항목을 모두 체크해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_signature.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('자필 서명을 완료해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? signatureUrl;
      final bytes = await _signature.toPngBytes();
      if (bytes != null && bytes.isNotEmpty) {
        signatureUrl = await ChartSignatureStorage.uploadPng(
          bytes: bytes,
          shopId: widget.customer.shopId.isNotEmpty
              ? widget.customer.shopId
              : widget.store.shop.id,
          customerId: widget.customer.id,
        );
      }
      if (signatureUrl == null || signatureUrl.trim().isEmpty) {
        signatureUrl =
            'local-signature-${DateTime.now().millisecondsSinceEpoch}';
      }

      final visit = widget.store.nextVisitNumber(widget.customer.id);
      final chart = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.customer.id,
        visitNumber: visit,
        careName: '전자 동의서',
        treatmentSummary: '퀵 전자 동의서 체결',
        directorInsight: '',
        concernChips: const [],
        firstVisitFearChips: const [],
        revisitFeedbackChips: const [],
        customerName: widget.customer.name,
        customerPhone: widget.customer.phone,
        gender: widget.customer.gender,
        birthDate: widget.customer.birthDate,
        address: widget.customer.address,
        occupation: widget.customer.occupation,
        consentMandatory: true,
        consentPhoto: _photo,
        consentMarketing: _photo && _marketing,
        consentOfflineOnly: _photo && _offline,
        signatureUrl: signatureUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, chart);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동의서 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '⚡ 퀵 전자 동의서',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.customer.name}님 · 차트 이동 없이 바로 체결',
                  style: const TextStyle(
                    fontSize: 13,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _AccordionConsentCard(
                    title: ChartConsentTexts.mandatoryCareTitle,
                    summary: ChartConsentTexts.mandatoryCareSummary,
                    bullets: ChartConsentTexts.mandatoryCareBody,
                    requiredMark: true,
                    checked: _care,
                    onChanged: (v) => setState(() => _care = v),
                  ),
                  const SizedBox(height: 8),
                  _AccordionConsentCard(
                    title: ChartConsentTexts.mandatoryReactionTitle,
                    summary: ChartConsentTexts.mandatoryReactionSummary,
                    bullets: ChartConsentTexts.mandatoryReactionBody,
                    requiredMark: true,
                    checked: _reaction,
                    onChanged: (v) => setState(() => _reaction = v),
                  ),
                  const SizedBox(height: 8),
                  _AccordionConsentCard(
                    title: ChartConsentTexts.mandatoryRefundTitle,
                    summary: ChartConsentTexts.mandatoryRefundSummary,
                    bullets: ChartConsentTexts.mandatoryRefundBody,
                    requiredMark: true,
                    checked: _refund,
                    onChanged: (v) => setState(() => _refund = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ChartConsentTexts.optionalPhotoTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CheckCard(
                    title: ChartConsentTexts.optionalPhotoTitle,
                    checked: _photo,
                    onChanged: (v) => setState(() {
                      _photo = v;
                      if (!v) {
                        _marketing = false;
                        _offline = false;
                      }
                    }),
                  ),
                  if (_photo) ...[
                    const SizedBox(height: 8),
                    _CheckCard(
                      title: ChartConsentTexts.photoUseMarketing,
                      checked: _marketing,
                      onChanged: (v) => setState(() => _marketing = v),
                    ),
                    const SizedBox(height: 8),
                    _CheckCard(
                      title: ChartConsentTexts.photoUseOffline,
                      checked: _offline,
                      onChanged: (v) => setState(() => _offline = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '자필 서명',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Signature(
                      controller: _signature,
                      backgroundColor: const Color(0xFFFAFAFA),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : () => _signature.clear(),
                      child: const Text('서명 지우기'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '동의서 저장',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccordionConsentCard extends StatefulWidget {
  const _AccordionConsentCard({
    required this.title,
    required this.summary,
    required this.bullets,
    required this.checked,
    required this.onChanged,
    this.requiredMark = false,
  });

  final String title;
  final String summary;
  final List<String> bullets;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool requiredMark;

  @override
  State<_AccordionConsentCard> createState() => _AccordionConsentCardState();
}

class _AccordionConsentCardState extends State<_AccordionConsentCard> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.checked ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: widget.checked,
                  onChanged: (v) {
                    final next = v ?? false;
                    widget.onChanged(next);
                    if (next && !_expanded) {
                      setState(() => _expanded = true);
                    }
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              if (widget.requiredMark)
                                const TextSpan(
                                  text: '[필수] ',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              TextSpan(text: widget.title),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5B6B8C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? '내용 접기' : '내용 보기',
                  onPressed: _toggleExpanded,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < widget.bullets.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '· ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    height: 1.45,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.bullets[i],
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
