import 'package:flutter/material.dart';

import '../models/chart_interview_chips.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'customer_link_popup.dart';
import 'my_app.dart';

Future<void> openChartWriterForCustomer(
  BuildContext context, {
  required SoriStore store,
  required Customer customer,
  CustomerChart? existingChart,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminChartWriterPage(
        store: store,
        customer: customer,
        existingChart: existingChart,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// 원장용 차트 작성 (고객 식별·메디컬 이력·심리 인터뷰·방문 확인).
class AdminChartWriterPage extends StatefulWidget {
  const AdminChartWriterPage({
    super.key,
    required this.store,
    required this.customer,
    this.existingChart,
  });

  final SoriStore store;
  final Customer customer;
  final CustomerChart? existingChart;

  @override
  State<AdminChartWriterPage> createState() => _AdminChartWriterPageState();
}

class _AdminChartWriterPageState extends State<AdminChartWriterPage> {
  late int _visitNumber;
  late final TextEditingController _customNoController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _occupationController;
  late final TextEditingController _allergyController;
  late final TextEditingController _skinSensitivityController;
  late final TextEditingController _sideEffectController;
  late final TextEditingController _careNameController;
  late final TextEditingController _summaryController;
  late final TextEditingController _insightController;

  CustomerGender? _gender;
  DateTime? _birthDate;
  bool _beforeAttached = false;
  bool _afterAttached = false;
  String? _beforeLabel;
  String? _afterLabel;

  final Set<String> _fears = {};
  final Set<String> _revisit = {};
  final Set<String> _concerns = {};
  bool _saving = false;

  late final TextEditingController _membershipNameController;
  late int _membershipTotal;
  late int _membershipUsed;

  bool get _isFirstVisit => _visitNumber <= 1;

  int get _membershipRemaining =>
      (_membershipTotal - _membershipUsed).clamp(0, 999);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingChart;
    // 전화번호를 Unique Key로 기존 고객 프로필을 우선 로드 (자동 완성).
    final byPhone = widget.store.findCustomerByPhone(widget.customer.phone);
    final c = byPhone ?? widget.customer;
    _visitNumber =
        existing?.visitNumber ?? widget.store.nextVisitNumber(c.id);
    _customNoController =
        TextEditingController(text: existing?.customChartNo ?? '');
    _nameController = TextEditingController(text: c.name);
    _phoneController = TextEditingController(text: c.phone);
    _addressController = TextEditingController(text: c.address);
    _occupationController = TextEditingController(text: c.occupation);
    // 차트 메디컬 우선, 구버전 고객 마스터 값은 폴백으로만 채움
    _allergyController = TextEditingController(
      text: (existing?.allergyNotes.isNotEmpty ?? false)
          ? existing!.allergyNotes
          : c.allergyNotes,
    );
    _skinSensitivityController = TextEditingController(
      text: (existing?.skinSensitivity.isNotEmpty ?? false)
          ? existing!.skinSensitivity
          : c.medicationHistory,
    );
    _sideEffectController = TextEditingController(
      text: (existing?.sideEffectHistory.isNotEmpty ?? false)
          ? existing!.sideEffectHistory
          : c.homeCareHabits,
    );
    _gender = c.gender;
    _birthDate = c.birthDate;
    _membershipNameController = TextEditingController(
      text: c.membershipServiceName.isNotEmpty
          ? c.membershipServiceName
          : (c.treatmentType.isNotEmpty ? '${c.treatmentType} 10회권' : ''),
    );
    _membershipTotal =
        c.membershipTotalVisits > 0 ? c.membershipTotalVisits : 10;
    _membershipUsed = c.membershipUsedVisits;
    if (c.membershipTotalVisits <= 0) {
      _membershipTotal = 0;
      _membershipUsed = 0;
      _membershipNameController.text = '';
    }
    _careNameController = TextEditingController(
      text: existing?.careName.isNotEmpty == true
          ? existing!.careName
          : c.treatmentType,
    );
    _summaryController =
        TextEditingController(text: existing?.treatmentSummary ?? '');
    _insightController =
        TextEditingController(text: existing?.directorInsight ?? '');
    _beforeAttached = existing?.beforeImageUrl != null;
    _afterAttached = existing?.afterImageUrl != null;
    _beforeLabel = existing?.beforeImageUrl;
    _afterLabel = existing?.afterImageUrl;
    _fears.addAll(existing?.firstVisitFearChips ?? const []);
    _revisit.addAll(existing?.revisitFeedbackChips ?? const []);
    _concerns.addAll(existing?.concernChips ?? const []);
  }

  @override
  void dispose() {
    _customNoController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _allergyController.dispose();
    _skinSensitivityController.dispose();
    _sideEffectController.dispose();
    _membershipNameController.dispose();
    _careNameController.dispose();
    _summaryController.dispose();
    _insightController.dispose();
    super.dispose();
  }

  /// 전화번호로 기존 고객 인적·메디컬·회원권 정보를 폼에 자동 채움.
  Future<void> _autofillFromPhone() async {
    final matched =
        await widget.store.lookupCustomerByPhone(_phoneController.text);
    if (!mounted) return;
    if (widget.store.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('조회 실패: ${widget.store.lastError}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      widget.store.clearError();
    }
    if (matched == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 번호의 기존 고객을 찾지 못했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      if (matched.name.isNotEmpty) _nameController.text = matched.name;
      _gender = matched.gender ?? _gender;
      _birthDate = matched.birthDate ?? _birthDate;
      if (matched.address.isNotEmpty) {
        _addressController.text = matched.address;
      }
      if (matched.occupation.isNotEmpty) {
        _occupationController.text = matched.occupation;
      }
      // 전화 매칭 시 이전 차트 메디컬을 우선 불러오고, 없으면 레거시 고객 필드 폴백
      final prior = widget.store.latestChart(matched.id);
      if ((prior?.allergyNotes.isNotEmpty ?? false) ||
          matched.allergyNotes.isNotEmpty) {
        _allergyController.text = prior?.allergyNotes.isNotEmpty == true
            ? prior!.allergyNotes
            : matched.allergyNotes;
      }
      if ((prior?.skinSensitivity.isNotEmpty ?? false) ||
          matched.medicationHistory.isNotEmpty) {
        _skinSensitivityController.text =
            prior?.skinSensitivity.isNotEmpty == true
                ? prior!.skinSensitivity
                : matched.medicationHistory;
      }
      if ((prior?.sideEffectHistory.isNotEmpty ?? false) ||
          matched.homeCareHabits.isNotEmpty) {
        _sideEffectController.text =
            prior?.sideEffectHistory.isNotEmpty == true
                ? prior!.sideEffectHistory
                : matched.homeCareHabits;
      }
      if (matched.isMembershipCustomer) {
        _membershipNameController.text = matched.membershipServiceName;
        _membershipTotal = matched.membershipTotalVisits;
        _membershipUsed = matched.membershipUsedVisits;
      }
      if (_careNameController.text.trim().isEmpty &&
          matched.treatmentType.isNotEmpty) {
        _careNameController.text = matched.treatmentType;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${matched.name}님 기존 정보를 불러왔어요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  void _bumpTotal(int delta) {
    setState(() {
      _membershipTotal = (_membershipTotal + delta).clamp(0, 99);
      if (_membershipUsed > _membershipTotal) {
        _membershipUsed = _membershipTotal;
      }
    });
  }

  void _bumpUsed(int delta) {
    setState(() {
      _membershipUsed = (_membershipUsed + delta).clamp(0, _membershipTotal);
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: '생년월일 선택',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _attachPhoto({required bool isBefore}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진 업로드'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isBefore) {
                      _beforeAttached = true;
                      _beforeLabel =
                          'before_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    } else {
                      _afterAttached = true;
                      _afterLabel =
                          'after_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라 촬영'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isBefore) {
                      _beforeAttached = true;
                      _beforeLabel =
                          'camera_before_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    } else {
                      _afterAttached = true;
                      _afterLabel =
                          'camera_after_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    }
                  });
                },
              ),
              if ((isBefore && _beforeAttached) || (!isBefore && _afterAttached))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('첨부 삭제'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isBefore) {
                        _beforeAttached = false;
                        _beforeLabel = null;
                      } else {
                        _afterAttached = false;
                        _afterLabel = null;
                      }
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAndConfirm() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고객 성함을 입력해 주세요.')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해 주세요.')),
      );
      return;
    }
    if (SoriStore.normalizePhone(_phoneController.text).length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 올바르게 입력해 주세요.')),
      );
      return;
    }
    if (_careNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 진행된 케어 명칭을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    final wasAlreadyChecked = widget.existingChart?.visitChecked == true;
    final expectMembershipDeduct =
        !wasAlreadyChecked && _membershipTotal > 0;
    try {
      final chart = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.customer.id,
        visitNumber: _visitNumber,
        customChartNo: _customNoController.text.trim().isEmpty
            ? null
            : _customNoController.text.trim(),
        chartId: widget.existingChart?.id,
        careName: _careNameController.text.trim(),
        treatmentSummary: _summaryController.text.trim().isEmpty
            ? '$_visitNumber회차 ${_careNameController.text.trim()}'
            : _summaryController.text.trim(),
        directorInsight: _insightController.text.trim(),
        concernChips: _concerns.toList(),
        firstVisitFearChips: _fears.toList(),
        revisitFeedbackChips: _revisit.toList(),
        beforeImageUrl: _beforeAttached ? (_beforeLabel ?? 'before.jpg') : null,
        afterImageUrl: _afterAttached ? (_afterLabel ?? 'after.jpg') : null,
        customerName: _nameController.text,
        customerPhone: _phoneController.text,
        gender: _gender,
        birthDate: _birthDate,
        address: _addressController.text.trim(),
        occupation: _occupationController.text.trim(),
        allergyNotes: _allergyController.text.trim(),
        skinSensitivity: _skinSensitivityController.text.trim(),
        sideEffectHistory: _sideEffectController.text.trim(),
        membershipServiceName: _membershipNameController.text.trim(),
        membershipTotalVisits: _membershipTotal,
        membershipUsedVisits: _membershipUsed,
      );

      if (!mounted) return;
      final customer = widget.store.findCustomer(widget.customer.id);
      final remain = customer?.membershipRemainingVisits ?? 0;
      final deducted = expectMembershipDeduct &&
          (customer?.isMembershipCustomer ?? false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deducted
                ? '방문 확인 완료 · 회원권 1회 차감됐어요 (잔여 $remain회)'
                : '방문 확인 완료 · 고객 리뷰 링크가 준비됐어요',
          ),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      await showCustomerLinkPopup(context, chart: chart, store: widget.store);
      if (!mounted) return;
      Navigator.pop(context, chart);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '저장 실패: ${widget.store.lastError ?? e.toString()}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      widget.store.clearError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('차트 작성'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _SegmentCard(
                  title: '1. 고객 인적사항',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '고객 성함 *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '성별 *',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('여성')),
                              selected: _gender == CustomerGender.female,
                              onSelected: (_) =>
                                  setState(() => _gender = CustomerGender.female),
                              selectedColor: MyApp.soriPurple.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('남성')),
                              selected: _gender == CustomerGender.male,
                              onSelected: (_) =>
                                  setState(() => _gender = CustomerGender.male),
                              selectedColor: MyApp.soriPurple.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _autofillFromPhone,
                        decoration: InputDecoration(
                          labelText: '전화번호 / 연락처 *',
                          hintText: '입력 시 기존 고객 정보 자동 완성',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: '기존 정보 불러오기',
                            onPressed: _autofillFromPhone,
                            icon: const Icon(Icons.person_search_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickBirthDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '생년월일 / 년생',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(
                            _birthDate == null
                                ? '피부 재생 주기 파악용 (선택)'
                                : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')} (${_birthDate!.year}년생)',
                            style: TextStyle(
                              color: _birthDate == null
                                  ? Colors.grey.shade500
                                  : const Color(0xFF2D3436),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: '거주 지역 / 주소',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _occupationController,
                        decoration: const InputDecoration(
                          labelText: '직업 / 생활 패턴',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '🎟️ 회원권 관리',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _membershipNameController,
                        decoration: const InputDecoration(
                          labelText: '진행 중인 서비스명',
                          hintText: '예: 재생 케어 10회권',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SpinnerField(
                        label: '총 결제 횟수',
                        value: _membershipTotal,
                        onMinus: () => _bumpTotal(-1),
                        onPlus: () => _bumpTotal(1),
                        onChanged: (v) => setState(() {
                          _membershipTotal = v.clamp(0, 99);
                          if (_membershipUsed > _membershipTotal) {
                            _membershipUsed = _membershipTotal;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      _SpinnerField(
                        label: '현재 차감 횟수',
                        value: _membershipUsed,
                        onMinus: () => _bumpUsed(-1),
                        onPlus: () => _bumpUsed(1),
                        onChanged: (v) => setState(() {
                          _membershipUsed = v.clamp(0, _membershipTotal);
                        }),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _membershipRemaining <= 2 &&
                                  _membershipTotal > 0
                              ? const Color(0xFFFFF4E5)
                              : MyApp.soriPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _membershipTotal <= 0
                              ? '회원권을 등록하면 방문 확인 시 잔여 횟수가 자동 차감됩니다.'
                              : '잔여 $_membershipRemaining회 · 방문 확인 시 차감 +1 자동 반영',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _membershipRemaining <= 2 &&
                                    _membershipTotal > 0
                                ? const Color(0xFFB7791F)
                                : MyApp.soriPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '2. 이번 방문 메디컬 체크',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '알레르기·민감도·부작용은 고객 등록이 아니라 차트에 기록해요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _allergyController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '알레르기',
                          hintText: '금속, 향료, 특정 성분 등',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _skinSensitivityController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '피부 민감도',
                          hintText: '홍조, 장벽 약화, 자극 반응 등',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sideEffectController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '부작용 이력',
                          hintText: '이전 시술 후 붉어짐, 통증, 다운타임 등',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '3. 차트 번호 · 심리 인터뷰',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '자동 회차',
                                border: OutlineInputBorder(),
                              ),
                              child: Text('$_visitNumber회차'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _customNoController,
                              decoration: const InputDecoration(
                                labelText: '수동 차트 번호',
                                hintText: '기존 프로그램 번호',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isFirstVisit
                            ? '첫 방문 심리 인터뷰 (10초)'
                            : '재방문 소소한 불편함',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!_isFirstVisit) ...[
                        const SizedBox(height: 6),
                        Text(
                          '원장님께 말하기 미안해서 참았던 소소한 불편함이 있으셨나요?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_isFirstVisit
                                ? ChartInterviewChips.firstVisitFears
                                : ChartInterviewChips.revisitFeedbacks)
                            .map((label) {
                          final selected = _isFirstVisit
                              ? _fears.contains(label)
                              : _revisit.contains(label);
                          return FilterChip(
                            label:
                                Text(label, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                final set = _isFirstVisit ? _fears : _revisit;
                                if (v) {
                                  set.add(label);
                                } else {
                                  set.remove(label);
                                }
                              });
                            },
                            selectedColor:
                                MyApp.soriPurple.withValues(alpha: 0.18),
                            checkmarkColor: MyApp.soriPurple,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '4. 진단 · Before/After · 인사이트',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주요 고민',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ChartInterviewChips.skinConcerns.map((label) {
                          final selected = _concerns.contains(label);
                          return FilterChip(
                            label:
                                Text(label, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _concerns.add(label);
                                } else {
                                  _concerns.remove(label);
                                }
                              });
                            },
                            selectedColor:
                                MyApp.soriPurple.withValues(alpha: 0.18),
                            checkmarkColor: MyApp.soriPurple,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PhotoAttachBox(
                              title: 'Before',
                              attached: _beforeAttached,
                              fileLabel: _beforeLabel,
                              onTap: () => _attachPhoto(isBefore: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PhotoAttachBox(
                              title: 'After',
                              attached: _afterAttached,
                              fileLabel: _afterLabel,
                              onTap: () => _attachPhoto(isBefore: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _careNameController,
                        decoration: const InputDecoration(
                          labelText: '오늘 진행된 케어 명칭 *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _summaryController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '원장 맞춤 조치 / 시술 요약',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _insightController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'AI 답글용 한 줄 인사이트',
                          hintText: '예: 민감 장벽 케어 강조',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _saveAndConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: MyApp.soriPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving ? '저장 중…' : '차트 저장 및 방문 확인 완료',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SpinnerField extends StatelessWidget {
  const _SpinnerField({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            foregroundColor: MyApp.soriPurple,
          ),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            key: ValueKey('$label-$value'),
            controller: TextEditingController(text: '$value'),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (raw) {
              final parsed = int.tryParse(raw.trim());
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            foregroundColor: MyApp.soriPurple,
          ),
        ),
      ],
    );
  }
}

class _PhotoAttachBox extends StatelessWidget {
  const _PhotoAttachBox({
    required this.title,
    required this.attached,
    required this.onTap,
    this.fileLabel,
  });

  final String title;
  final bool attached;
  final VoidCallback onTap;
  final String? fileLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: attached
          ? MyApp.soriPurple.withValues(alpha: 0.08)
          : const Color(0xFFF3F1FB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: attached
                  ? MyApp.soriPurple.withValues(alpha: 0.35)
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: MyApp.soriPurple,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                attached ? Icons.check_circle : Icons.add_a_photo_outlined,
                color: MyApp.soriPurple,
              ),
              const SizedBox(height: 6),
              Text(
                attached ? '첨부됨' : '📷 사진 업로드 / 카메라 촬영',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
