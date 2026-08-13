import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 고객 상세 정보 / 수정 — `/customer/:id/profile`
class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _occupation;
  late final TextEditingController _memo;
  CustomerGender? _gender;
  DateTime? _birthDate;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.store.findCustomer(widget.customerId);
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _occupation = TextEditingController(text: c?.occupation ?? '');
    _memo = TextEditingController(text: c?.memo ?? '');
    _gender = c?.gender;
    _birthDate = c?.birthDate;
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _occupation.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  CustomerChart? get _latestChart =>
      widget.store.latestChart(widget.customerId);

  CustomerChart? get _consentChart =>
      widget.store.latestSignedConsentChart(widget.customerId);

  int? get _koreanAge {
    final b = _birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month ||
        (now.month == b.month && now.day < b.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '미입력';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: now,
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _call() async {
    final digits = SoriStore.normalizePhone(_phone.text);
    if (digits.length < 10) return;
    await launchUrl(Uri.parse('tel:$digits'));
  }

  Future<void> _sms() async {
    final digits = SoriStore.normalizePhone(_phone.text);
    if (digits.length < 10) return;
    await launchUrl(Uri.parse('sms:$digits'));
  }

  Future<void> _openPdf() async {
    final url = _consentChart?.consentPdfUrl?.trim() ?? '';
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장된 동의서 PDF가 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    final base = _customer;
    if (base == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('성함을 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.saveCustomerProfile(
        base.copyWith(
          name: name,
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          occupation: _occupation.text.trim(),
          memo: _memo.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          clearGender: _gender == null,
          clearBirthDate: _birthDate == null,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객 정보가 저장되었습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
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
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('고객 상세')),
        body: const Center(child: Text('고객을 찾을 수 없습니다.')),
      );
    }

    final chart = _latestChart;
    final consent = _consentChart;
    final until = SoriStore.consentValidUntil(consent);
    final allergy = (chart?.allergyNotes.trim().isNotEmpty == true)
        ? chart!.allergyNotes
        : customer.allergyNotes;
    final skin = (chart?.skinSensitivity.trim().isNotEmpty == true)
        ? chart!.skinSensitivity
        : customer.medicationHistory;
    final side = (chart?.sideEffectHistory.trim().isNotEmpty == true)
        ? chart!.sideEffectHistory
        : customer.homeCareHabits;
    final age = _koreanAge;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('고객 상세 정보'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppPaths.customerDetail(customer.id));
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _SectionCard(
            title: '기본 인적사항',
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '성명',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CustomerGender?>(
                        // ignore: deprecated_member_use
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: '성별',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('미선택')),
                          DropdownMenuItem(
                            value: CustomerGender.female,
                            child: Text('여성'),
                          ),
                          DropdownMenuItem(
                            value: CustomerGender.male,
                            child: Text('남성'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickBirth,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '생년월일',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            age == null
                                ? _fmtDate(_birthDate)
                                : '${_fmtDate(_birthDate)} · 만 $age세',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: '연락처',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '전화',
                          onPressed: _call,
                          icon: const Icon(Icons.phone_rounded),
                        ),
                        IconButton(
                          tooltip: '문자',
                          onPressed: _sms,
                          icon: const Icon(Icons.sms_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: '주소',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _occupation,
                  decoration: const InputDecoration(
                    labelText: '직업 / 라이프스타일',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (customer.isMembershipCustomer) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      customer.membershipBadgeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '메디컬 / 피부 스펙',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpecRow(label: '피부 타입 / 민감도', value: skin),
                const SizedBox(height: 10),
                _SpecRow(label: '알레르기', value: allergy, danger: true),
                const SizedBox(height: 10),
                _SpecRow(label: '부작용 주의', value: side, danger: true),
                const SizedBox(height: 8),
                Text(
                  '※ 메디컬 항목은 최근 차트 기록을 우선 표시합니다.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '원장 전용 메모',
            child: TextField(
              controller: _memo,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '고객 성향·취향·대화 선호도·특이사항을 자유롭게 남겨 주세요.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '동의서 상태',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (consent != null && until != null && !until.isBefore(DateTime.now()))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✅ 전자 동의서 체결 완료\n동의일시: ${_fmtDate(consent.consentSignedAt)} · 유효: ${_fmtDate(until)}까지',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  )
                else if (consent != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⚠️ 동의서 만료 또는 갱신 필요\n마지막 동의: ${_fmtDate(consent.consentSignedAt)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '미체결 — 차트 작성 시 전자 동의서가 필요합니다.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('동의서 PDF 다운로드'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? '기록 없음' : value.trim();
    final empty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        if (danger && !empty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFC62828),
                height: 1.35,
              ),
            ),
          )
        else
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: empty ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
              height: 1.35,
            ),
          ),
      ],
    );
  }
}
