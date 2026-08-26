import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seminar_application.dart';
import '../models/seminar_class_detail.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/seminar_checkout_bottom_sheet.dart';

/// 세미나 수강 신청서 — `seminar_applications` INSERT 후 에스크로 결제 연결.
class SeminarApplyPage extends StatefulWidget {
  const SeminarApplyPage({
    super.key,
    required this.store,
    required this.classId,
    this.detail,
  });

  final SoriStore store;
  final String classId;
  final SeminarClassDetail? detail;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required String classId,
    SeminarClassDetail? detail,
  }) {
    return pushRootPage<void>(
      context,
      SeminarApplyPage(store: store, classId: classId, detail: detail),
    );
  }

  @override
  State<SeminarApplyPage> createState() => _SeminarApplyPageState();
}

class _SeminarApplyPageState extends State<SeminarApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();

  String? _career;
  bool _refundAgreed = false;
  bool _submitting = false;
  SeminarClassDetail? _detail;
  bool _loadingDetail = false;

  static final _priceFmt = NumberFormat('#,###', 'ko_KR');
  static final _dateFmt = DateFormat('M월 d일 (E) HH:mm', 'ko_KR');

  InputDecoration _decoration(
    String label, {
    String? hint,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: readOnly
          ? SoriTokens.border
          : SoriTokens.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.outlinePurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.primary, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    final shop = widget.store.shop;
    final session = widget.store.session;
    _nameCtrl.text = (shop.ownerName?.trim().isNotEmpty == true)
        ? shop.ownerName!.trim()
        : (session?.name.trim() ?? '');
    _shopCtrl.text = shop.name.trim();
    _phoneCtrl.text = session?.phone.trim() ?? '';
    if (_detail == null) _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    final d = await widget.store.loadSeminarClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _detail = d;
      _loadingDetail = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shopCtrl.dispose();
    _phoneCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_refundAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환불/취소 규정에 동의해 주세요.')),
      );
      return;
    }

    final session = widget.store.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 신청할 수 있어요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final app = SeminarApplication(
      id: '',
      classId: widget.classId,
      applicantShopId: widget.store.shop.id.trim().isEmpty
          ? null
          : widget.store.shop.id.trim(),
      applicantUserId: session.id.trim().isEmpty ? null : session.id.trim(),
      applicantName: _nameCtrl.text.trim(),
      shopName: _shopCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim(),
      careerType: _career ?? '',
      question: _questionCtrl.text.trim(),
      refundAgreed: true,
    );

    final ok = await widget.store.submitSeminarApplication(app);
    if (!mounted) return;

    if (!ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError?.trim().isNotEmpty == true
                ? widget.store.lastError!
                : '신청서 제출에 실패했습니다.',
          ),
          backgroundColor: SoriTokens.primaryDark,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('신청서가 접수되었습니다. 이어서 수강료 결제를 진행해 주세요.'),
        backgroundColor: SoriTokens.primary,
      ),
    );

    final detail = _detail;
    if (detail != null && detail.seminarClass.isEnrollable) {
      final paid = await SeminarCheckoutBottomSheet.show(
        context,
        store: widget.store,
        detail: detail,
        dateFmt: _dateFmt,
        priceFmt: _priceFmt,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (paid) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _submitting = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cls = _detail?.seminarClass;
    final title = cls?.title.trim().isNotEmpty == true
        ? cls!.title
        : '세미나 수강 신청';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '세미나 신청',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: _loadingDetail && _detail == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SoriTokens.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SoriTokens.outlinePurple),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (cls != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${cls.classFormatLabel} · ${_priceFmt.format(cls.price)}원',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameCtrl,
                    readOnly: true,
                    decoration: _decoration('신청자 이름', readOnly: true),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '이름 정보가 없습니다.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shopCtrl,
                    readOnly: true,
                    decoration: _decoration('상호(샵명)', readOnly: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    readOnly: true,
                    decoration: _decoration('연락처', readOnly: true),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '연락처 정보가 없습니다.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _career,
                    decoration: _decoration('현재 운영 형태 / 경력'),
                    items: SeminarApplication.careerOptions
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _career = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '운영 형태를 선택해 주세요.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _questionCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _decoration(
                      '강사에게 남길 사전 질문',
                      hint: '배우고 싶은 포인트, 준비 상황을 적어 주세요.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _refundAgreed,
                    onChanged: (v) =>
                        setState(() => _refundAgreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '환불·취소 규정에 동의합니다',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '개강 3일 전까지 전액 환불, 이후 환불 불가(에스크로 정책).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _submitting ? '제출 중…' : '신청서 제출',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
