import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';

import '../models/chart_interview_chips.dart';
import '../models/chart_medical_chips.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/home_care_prescriptions.dart';
import '../services/chart_signature_storage.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/db_map.dart';
import 'chart_consent_tab.dart';
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

class _AdminChartWriterPageState extends State<AdminChartWriterPage>
    with TickerProviderStateMixin {
  late int _visitNumber;
  late final TabController _tabController;
  late final PageController _pageController;
  late final SignatureController _signatureController;
  late final TextEditingController _customNoController;
  late final TextEditingController _birthTextController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _occupationController;
  late final TextEditingController _allergyOtherController;
  late final TextEditingController _skinOtherController;
  late final TextEditingController _sideEffectOtherController;
  late final TextEditingController _careNameController;
  late final TextEditingController _requestsController;
  late final TextEditingController _summaryController;
  late final TextEditingController _insightController;
  late final TextEditingController _guardianPhoneController;

  CustomerGender? _gender;
  DateTime? _birthDate;
  bool _beforeAttached = false;
  bool _afterAttached = false;
  String? _beforeLabel;
  String? _afterLabel;

  final Set<String> _allergyChips = {};
  final Set<String> _skinChips = {};
  final Set<String> _sideEffectChips = {};
  final Set<String> _fears = {};
  final Set<String> _revisit = {};
  final Set<String> _concerns = {};
  final Set<String> _homeCarePrescriptions = {};
  bool _saving = false;

  bool _consentMandatory = false;
  bool _consentPhoto = false;
  bool _consentMarketing = false;
  bool _consentOfflineOnly = false;
  String? _existingSignatureUrl;
  bool _infoViewConsent = false;

  /// 회차와 별도로 원장이 선택하는 첫 방문/재방문 인터뷰 모드.
  late bool _isFirstVisitMode;

  late List<CustomerMembership> _memberships;

  bool get _isFirstVisit => _isFirstVisitMode;

  List<String> get _serviceOptions => widget.store.shop.serviceNames;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();
    _signatureController = SignatureController(
      penStrokeWidth: 2.8,
      penColor: const Color(0xFF2D3436),
      exportBackgroundColor: Colors.white,
    );
    final existing = widget.existingChart;
    // 전화번호를 Unique Key로 기존 고객 프로필을 우선 로드 (자동 완성).
    final byPhone = widget.store.findCustomerByPhone(widget.customer.phone);
    final c = byPhone ?? widget.customer;
    _visitNumber =
        existing?.visitNumber ?? widget.store.nextVisitNumber(c.id);
    if (existing != null) {
      if (existing.revisitFeedbackChips.isNotEmpty &&
          existing.firstVisitFearChips.isEmpty) {
        _isFirstVisitMode = false;
      } else if (existing.firstVisitFearChips.isNotEmpty) {
        _isFirstVisitMode = true;
      } else {
        _isFirstVisitMode = existing.visitNumber <= 1;
      }
    } else {
      _isFirstVisitMode = _visitNumber <= 1;
    }
    final initialChartNo = existing?.customChartNo?.trim().isNotEmpty == true
        ? existing!.customChartNo!.trim()
        : widget.store.suggestNextChartNumber();
    _customNoController = TextEditingController(text: initialChartNo);
    _nameController = TextEditingController(text: c.name);
    _phoneController = TextEditingController(text: c.phone);
    _addressController = TextEditingController(text: c.address);
    _occupationController = TextEditingController(text: c.occupation);
    // 차트 메디컬 우선, 구버전 고객 마스터 값은 폴백으로만 채움
    final allergyRaw = (existing?.allergyNotes.isNotEmpty ?? false)
        ? existing!.allergyNotes
        : c.allergyNotes;
    final skinRaw = (existing?.skinSensitivity.isNotEmpty ?? false)
        ? existing!.skinSensitivity
        : c.medicationHistory;
    final sideRaw = (existing?.sideEffectHistory.isNotEmpty ?? false)
        ? existing!.sideEffectHistory
        : c.homeCareHabits;
    final allergyParsed = ChartMedicalChips.parseStored(
      allergyRaw,
      options: ChartMedicalChips.allergies,
      noneLabel: ChartMedicalChips.allergyNone,
    );
    final skinParsed = ChartMedicalChips.parseStored(
      skinRaw,
      options: ChartMedicalChips.skinSensitivities,
      noneLabel: ChartMedicalChips.skinNone,
    );
    final sideParsed = ChartMedicalChips.parseStored(
      sideRaw,
      options: ChartMedicalChips.sideEffectHistories,
      noneLabel: ChartMedicalChips.sideEffectNone,
    );
    _allergyChips.addAll(allergyParsed.selected);
    _skinChips.addAll(skinParsed.selected);
    _sideEffectChips.addAll(sideParsed.selected);
    _allergyOtherController =
        TextEditingController(text: allergyParsed.otherText);
    _skinOtherController = TextEditingController(text: skinParsed.otherText);
    _sideEffectOtherController =
        TextEditingController(text: sideParsed.otherText);
    _gender = c.gender;
    _birthDate = c.birthDate;
    _birthTextController = TextEditingController(
      text: _formatBirthDigits(_birthDate),
    );
    final synced = c.withSyncedMembershipMirrors();
    _memberships = List<CustomerMembership>.from(synced.memberships);
    // 오늘 진행 서비스는 진입 시 항상 빈 칸 (기존 차트 수정 시에만 복원)
    _careNameController = TextEditingController(
      text: existing?.careName ?? '',
    );
    _requestsController = TextEditingController(
      text: existing?.customerRequests ?? '',
    );
    _summaryController =
        TextEditingController(text: existing?.treatmentSummary ?? '');
    _insightController =
        TextEditingController(text: existing?.directorInsight ?? '');
    _guardianPhoneController = TextEditingController(
      text: existing?.guardianPhone ?? '',
    );
    _beforeAttached = existing?.beforeImageUrl != null;
    _afterAttached = existing?.afterImageUrl != null;
    _beforeLabel = existing?.beforeImageUrl;
    _afterLabel = existing?.afterImageUrl;
    _fears.addAll(existing?.firstVisitFearChips ?? const []);
    _revisit.addAll(existing?.revisitFeedbackChips ?? const []);
    _concerns.addAll(existing?.concernChips ?? const []);
    for (final tag in existing?.homeCarePrescriptions ?? const <String>[]) {
      final p = HomeCarePrescriptionCatalog.byId(tag) ??
          HomeCarePrescriptionCatalog.byChipLabel(tag);
      _homeCarePrescriptions.add(p?.id ?? tag);
    }
    _consentMandatory = existing?.consentMandatory ?? false;
    _consentPhoto = existing?.consentPhoto ?? false;
    _consentMarketing = existing?.consentMarketing ?? false;
    _consentOfflineOnly = existing?.consentOfflineOnly ?? false;
    _existingSignatureUrl = existing?.signatureUrl;
    _infoViewConsent = existing?.infoViewConsent ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _signatureController.dispose();
    _customNoController.dispose();
    _birthTextController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _allergyOtherController.dispose();
    _skinOtherController.dispose();
    _sideEffectOtherController.dispose();
    _careNameController.dispose();
    _requestsController.dispose();
    _summaryController.dispose();
    _insightController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  void _addMembership() {
    setState(() {
      _memberships = [
        ..._memberships,
        CustomerMembership(
          id: 'm-${DateTime.now().millisecondsSinceEpoch}',
          serviceName: '',
          totalVisits: 10,
          usedVisits: 0,
        ),
      ];
    });
  }

  void _removeMembership(String id) {
    setState(() {
      _memberships = _memberships.where((m) => m.id != id).toList();
    });
  }

  void _updateMembership(int index, CustomerMembership next) {
    setState(() {
      final list = List<CustomerMembership>.from(_memberships);
      list[index] = next;
      _memberships = list;
    });
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
      _birthTextController.text = _formatBirthDigits(_birthDate);
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
        _applyMedicalStored(
          prior?.allergyNotes.isNotEmpty == true
              ? prior!.allergyNotes
              : matched.allergyNotes,
          selected: _allergyChips,
          otherController: _allergyOtherController,
          options: ChartMedicalChips.allergies,
          noneLabel: ChartMedicalChips.allergyNone,
        );
      }
      if ((prior?.skinSensitivity.isNotEmpty ?? false) ||
          matched.medicationHistory.isNotEmpty) {
        _applyMedicalStored(
          prior?.skinSensitivity.isNotEmpty == true
              ? prior!.skinSensitivity
              : matched.medicationHistory,
          selected: _skinChips,
          otherController: _skinOtherController,
          options: ChartMedicalChips.skinSensitivities,
          noneLabel: ChartMedicalChips.skinNone,
        );
      }
      if ((prior?.sideEffectHistory.isNotEmpty ?? false) ||
          matched.homeCareHabits.isNotEmpty) {
        _applyMedicalStored(
          prior?.sideEffectHistory.isNotEmpty == true
              ? prior!.sideEffectHistory
              : matched.homeCareHabits,
          selected: _sideEffectChips,
          otherController: _sideEffectOtherController,
          options: ChartMedicalChips.sideEffectHistories,
          noneLabel: ChartMedicalChips.sideEffectNone,
        );
      }
      _memberships =
          List<CustomerMembership>.from(matched.withSyncedMembershipMirrors().memberships);
      if (prior?.customerRequests.isNotEmpty == true) {
        _requestsController.text = prior!.customerRequests;
      }
      // 오늘 진행 서비스는 자동완성으로 채우지 않음 (빈 칸 유지)
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${matched.name}님 기존 정보를 불러왔어요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  static String _formatBirthDigits(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void _onBirthDigitsChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits != raw) {
      _birthTextController.value = TextEditingValue(
        text: digits.length > 8 ? digits.substring(0, 8) : digits,
        selection: TextSelection.collapsed(
          offset: (digits.length > 8 ? 8 : digits.length),
        ),
      );
    } else if (digits.length > 8) {
      _birthTextController.value = TextEditingValue(
        text: digits.substring(0, 8),
        selection: const TextSelection.collapsed(offset: 8),
      );
    }

    final d = digits.length > 8 ? digits.substring(0, 8) : digits;
    if (d.length == 8) {
      final y = int.tryParse(d.substring(0, 4));
      final m = int.tryParse(d.substring(4, 6));
      final day = int.tryParse(d.substring(6, 8));
      if (y != null && m != null && day != null) {
        final parsed = DateTime(y, m, day);
        if (parsed.year == y &&
            parsed.month == m &&
            parsed.day == day &&
            !parsed.isAfter(DateTime.now()) &&
            y >= 1940) {
          setState(() => _birthDate = parsed);
          return;
        }
      }
    }
    if (_birthDate != null && d.length < 8) {
      setState(() => _birthDate = null);
    }
  }

  Future<void> _pickBirthDateWheel() async {
    var temp = _birthDate ?? DateTime(DateTime.now().year - 30, 1, 1);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                      ),
                      const Expanded(
                        child: Text(
                          '생년월일',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, temp),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: MyApp.soriPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Localizations.override(
                    context: ctx,
                    locale: const Locale('ko', 'KR'),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      dateOrder: DatePickerDateOrder.ymd,
                      initialDateTime: temp,
                      minimumDate: DateTime(1940),
                      maximumDate: DateTime.now(),
                      onDateTimeChanged: (value) => temp = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthTextController.text = _formatBirthDigits(picked);
    });
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

  /// 사진 미첨부 → null. 첨부됐지만 라벨이 비면 fallback, 그것도 없으면 null.
  static String? _chartImageUrlOrNull({
    required bool attached,
    required String? label,
    required String fallback,
  }) {
    if (!attached) return null;
    final trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final fb = fallback.trim();
    return fb.isEmpty ? null : fb;
  }

  void _applyMedicalStored(
    String raw, {
    required Set<String> selected,
    required TextEditingController otherController,
    required List<String> options,
    required String noneLabel,
  }) {
    final parsed = ChartMedicalChips.parseStored(
      raw,
      options: options,
      noneLabel: noneLabel,
    );
    selected
      ..clear()
      ..addAll(parsed.selected);
    otherController.text = parsed.otherText;
  }

  void _toggleMedicalChip({
    required Set<String> selected,
    required String label,
    required String noneLabel,
  }) {
    setState(() {
      if (label == noneLabel) {
        selected
          ..clear()
          ..add(noneLabel);
        return;
      }
      selected.remove(noneLabel);
      if (selected.contains(label)) {
        selected.remove(label);
      } else {
        selected.add(label);
      }
    });
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
        const SnackBar(content: Text('오늘 진행 서비스를 선택하거나 입력해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 서명 패드에 획이 있을 때만 업로드. 실패해도 차트 저장은 진행.
      String? signatureUrl = _existingSignatureUrl;
      if (_signatureController.isNotEmpty) {
        final bytes = await _signatureController.toPngBytes();
        if (bytes != null && bytes.isNotEmpty) {
          final uploaded = await ChartSignatureStorage.uploadPng(
            bytes: bytes,
            shopId: widget.store.shop.id,
            customerId: widget.customer.id,
          );
          if (uploaded != null) {
            signatureUrl = uploaded;
          }
        }
      }

      final chart = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.customer.id,
        visitNumber: _visitNumber,
        customChartNo: _customNoController.text.trim().isEmpty
            ? null
            : _customNoController.text.trim(),
        chartId: widget.existingChart?.id,
        careName: _careNameController.text.trim(),
        customerRequests: _requestsController.text.trim(),
        treatmentSummary: _summaryController.text.trim().isEmpty
            ? '$_visitNumber회차 ${_careNameController.text.trim()}'
            : _summaryController.text.trim(),
        directorInsight: _insightController.text.trim(),
        concernChips: DbMap.sanitizeStringList(_concerns),
        firstVisitFearChips: DbMap.sanitizeStringList(
          _isFirstVisit ? _fears : const <String>{},
        ),
        revisitFeedbackChips: DbMap.sanitizeStringList(
          _isFirstVisit ? const <String>{} : _revisit,
        ),
        beforeImageUrl: _chartImageUrlOrNull(
          attached: _beforeAttached,
          label: _beforeLabel,
          fallback: 'before.jpg',
        ),
        afterImageUrl: _chartImageUrlOrNull(
          attached: _afterAttached,
          label: _afterLabel,
          fallback: 'after.jpg',
        ),
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        address: _addressController.text.trim(),
        occupation: _occupationController.text.trim(),
        allergyNotes: ChartMedicalChips.joinSelection(
          selected: _allergyChips,
          noneLabel: ChartMedicalChips.allergyNone,
          otherText: _allergyOtherController.text,
        ),
        skinSensitivity: ChartMedicalChips.joinSelection(
          selected: _skinChips,
          noneLabel: ChartMedicalChips.skinNone,
          otherText: _skinOtherController.text,
        ),
        sideEffectHistory: ChartMedicalChips.joinSelection(
          selected: _sideEffectChips,
          noneLabel: ChartMedicalChips.sideEffectNone,
          otherText: _sideEffectOtherController.text,
        ),
        memberships: _memberships
            .where((m) => m.serviceName.trim().isNotEmpty && m.totalVisits > 0)
            .toList(),
        consentMandatory: _consentMandatory,
        consentPhoto: _consentPhoto,
        consentMarketing: _consentPhoto && _consentMarketing,
        consentOfflineOnly: _consentPhoto && _consentOfflineOnly,
        signatureUrl: signatureUrl,
        homeCarePrescriptions:
            DbMap.sanitizeStringList(_homeCarePrescriptions),
        guardianPhone: _guardianPhoneController.text.trim().isEmpty
            ? null
            : _guardianPhoneController.text.trim(),
        infoViewConsent: _infoViewConsent,
      );

      if (!mounted) return;
      final feedback = widget.store.lastVisitFeedback?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (feedback != null && feedback.isNotEmpty)
                ? '✅ 차트가 안전하게 저장되었습니다.\n$feedback'
                : '✅ 차트가 안전하게 저장되었습니다.',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: MyApp.soriPurple,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: MyApp.soriPurple,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          },
          tabs: const [
            Tab(text: '차트 작성'),
            Tab(text: '전자 동의서'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_tabController.index != index) {
                  _tabController.animateTo(index);
                }
              },
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: _buildChartFormChildren(),
                ),
                ChartConsentTab(
                  consentMandatory: _consentMandatory,
                  consentPhoto: _consentPhoto,
                  consentMarketing: _consentMarketing,
                  consentOfflineOnly: _consentOfflineOnly,
                  signatureController: _signatureController,
                  existingSignatureUrl: _existingSignatureUrl,
                  onMandatoryChanged: (v) =>
                      setState(() => _consentMandatory = v),
                  onPhotoChanged: (v) {
                    setState(() {
                      _consentPhoto = v;
                      if (!v) {
                        _consentMarketing = false;
                        _consentOfflineOnly = false;
                      } else if (!_consentMarketing && !_consentOfflineOnly) {
                        _consentOfflineOnly = true;
                      }
                    });
                  },
                  onMarketingSelected: () => setState(() {
                    _consentMarketing = true;
                    _consentOfflineOnly = false;
                  }),
                  onOfflineOnlySelected: () => setState(() {
                    _consentMarketing = false;
                    _consentOfflineOnly = true;
                  }),
                  onClearSignature: () => _signatureController.clear(),
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

  List<Widget> _buildChartFormChildren() {
    return [
                _SegmentCard(
                  title: '차트 번호',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _customNoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '차트 번호',
                          hintText: '종이 차트와 맞출 번호 (예: 21)',
                          helperText: '기본값은 마지막 번호+1이며 직접 수정할 수 있어요',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '회차 (자동)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '$_visitNumber회차',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                      TextField(
                        controller: _birthTextController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        onChanged: _onBirthDigitsChanged,
                        decoration: InputDecoration(
                          labelText: '생년월일 / 년생',
                          hintText: '19871204',
                          helperText:
                              '주민등록번호 앞자리 방식처럼 8자리 숫자로 입력해 주세요 (예: 19871204)',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: '캘린더로 선택',
                            onPressed: _pickBirthDateWheel,
                            icon: const Icon(Icons.calendar_month_outlined),
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
                  title: '방문 유형',
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('첫 방문'),
                          icon: Icon(Icons.person_add_alt_1_outlined, size: 18),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('재방문'),
                          icon: Icon(Icons.replay_outlined, size: 18),
                        ),
                      ],
                      selected: {_isFirstVisitMode},
                      onSelectionChanged: (selected) {
                        setState(() => _isFirstVisitMode = selected.first);
                      },
                      style: ButtonStyle(
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return MyApp.soriPurple;
                          }
                          return const Color(0xFF6B7280);
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '오늘 진행 서비스 & 고객 요청사항',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ServiceNameField(
                        label: '오늘 진행 서비스 *',
                        value: _careNameController.text,
                        options: _serviceOptions,
                        onChanged: (v) =>
                            setState(() => _careNameController.text = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _requestsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '고객 특별 요청사항',
                          hintText: '예: 기기 강도 약하게, 예민 피부 주의',
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
                      const Text(
                        '방문 확인 시 오늘 진행 서비스와 같은 회원권만 1회 차감됩니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_memberships.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '등록된 회원권이 없습니다. 1회성 시술로 저장할 수 있어요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                      ...List.generate(_memberships.length, (index) {
                        final m = _memberships[index];
                        final remain = m.remainingVisits;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: SoriTokens.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '회원권 ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    onPressed: () => _removeMembership(m.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              _ServiceNameField(
                                label: '서비스명',
                                value: m.serviceName,
                                options: _serviceOptions,
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(serviceName: v),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _SpinnerField(
                                label: '총 횟수',
                                value: m.totalVisits,
                                onMinus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits:
                                        (m.totalVisits - 1).clamp(0, 99),
                                    usedVisits: m.usedVisits.clamp(
                                      0,
                                      (m.totalVisits - 1).clamp(0, 99),
                                    ),
                                  ),
                                ),
                                onPlus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits:
                                        (m.totalVisits + 1).clamp(0, 99),
                                  ),
                                ),
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits: v.clamp(0, 99),
                                    usedVisits:
                                        m.usedVisits.clamp(0, v.clamp(0, 99)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SpinnerField(
                                label: '사용 횟수',
                                value: m.usedVisits,
                                onMinus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits:
                                        (m.usedVisits - 1).clamp(0, m.totalVisits),
                                  ),
                                ),
                                onPlus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits:
                                        (m.usedVisits + 1).clamp(0, m.totalVisits),
                                  ),
                                ),
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits: v.clamp(0, m.totalVisits),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '잔여 $remain회',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: remain <= 2 && m.totalVisits > 0
                                      ? const Color(0xFFB7791F)
                                      : MyApp.soriPurple,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _addMembership,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(color: SoriTokens.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            '+ 회원권 추가',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '메디컬 체크',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MedicalChipGroup(
                        title: '알레르기',
                        options: ChartMedicalChips.allergies,
                        selected: _allergyChips,
                        noneLabel: ChartMedicalChips.allergyNone,
                        otherController: _allergyOtherController,
                        otherHint: '예: 강아지 털, 특정 시술 성분',
                        onToggle: (label) => _toggleMedicalChip(
                          selected: _allergyChips,
                          label: label,
                          noneLabel: ChartMedicalChips.allergyNone,
                        ),
                        onOtherChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      _MedicalChipGroup(
                        title: '피부 민감도',
                        options: ChartMedicalChips.skinSensitivities,
                        selected: _skinChips,
                        noneLabel: ChartMedicalChips.skinNone,
                        otherController: _skinOtherController,
                        otherHint: '예: 장벽 손상, 특정 시즌 민감',
                        onToggle: (label) => _toggleMedicalChip(
                          selected: _skinChips,
                          label: label,
                          noneLabel: ChartMedicalChips.skinNone,
                        ),
                        onOtherChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      _MedicalChipGroup(
                        title: '부작용 이력',
                        options: ChartMedicalChips.sideEffectHistories,
                        selected: _sideEffectChips,
                        noneLabel: ChartMedicalChips.sideEffectNone,
                        otherController: _sideEffectOtherController,
                        otherHint: '예: 특정 기기 후 지속 홍반',
                        onToggle: (label) => _toggleMedicalChip(
                          selected: _sideEffectChips,
                          label: label,
                          noneLabel: ChartMedicalChips.sideEffectNone,
                        ),
                        onOtherChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentCard(
                  title: '3. 심리 인터뷰',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 18),
                      const Text(
                        '💊 오늘 고객을 위한 홈케어 처방',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '다중 선택 가능 · 고객 앱에 Why/How 문장으로 변환됩니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HomeCarePrescriptionCatalog.all.map((p) {
                          final selected =
                              _homeCarePrescriptions.contains(p.id);
                          return FilterChip(
                            label: Text(p.chipLabel),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _homeCarePrescriptions.add(p.id);
                                } else {
                                  _homeCarePrescriptions.remove(p.id);
                                }
                              });
                            },
                            selectedColor:
                                MyApp.soriPurple.withValues(alpha: 0.18),
                            checkmarkColor: MyApp.soriPurple,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '가족 연동 (보호자)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _guardianPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '보호자 연락처',
                          hintText: '예: 010-1234-5678',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '정보 열람 동의',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          '보호자 번호로 로그인한 가족이 이 고객의 케어 탭을 열람할 수 있어요',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _infoViewConsent,
                        activeThumbColor: MyApp.soriPurple,
                        onChanged: (v) =>
                            setState(() => _infoViewConsent = v),
                      ),
                    ],
                  ),
                ),
    ];
  }
}

class _ServiceNameField extends StatefulWidget {
  const _ServiceNameField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  State<_ServiceNameField> createState() => _ServiceNameFieldState();
}

class _ServiceNameFieldState extends State<_ServiceNameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ServiceNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _filtered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _openPickerSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ServicePickerSheet(
          title: widget.label,
          options: widget.options,
          // 빈 칸이면 전체 목록, 입력 중이면 해당 쿼리로 필터
          initialQuery: _controller.text.trim(),
        );
      },
    );
    if (!mounted || selected == null) return;
    _controller.text = selected;
    widget.onChanged(selected);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        if (widget.options.isEmpty) {
          return const Iterable<String>.empty();
        }
        // 빈 문자열이면 전체 목록 즉시 노출
        return _filtered(textEditingValue.text);
      },
      onSelected: (selection) {
        _controller.text = selection;
        widget.onChanged(selection);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final box =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final width = box?.size.width ??
            (MediaQuery.sizeOf(context).width - 64).clamp(240.0, 800.0);

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.white,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 280,
                minWidth: width,
                maxWidth: width,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          key: _fieldKey,
          controller: controller,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
          onTap: () {
            // 빈 칸 터치 시 전체 서비스 목록을 바로 펼침
            if (widget.options.isNotEmpty && controller.text.trim().isEmpty) {
              _openPickerSheet();
            }
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.options.isEmpty
                ? '서비스명을 직접 입력하세요'
                : '탭하여 전체 목록 보기 · 검색 또는 직접 입력',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
            suffixIcon: IconButton(
              tooltip: '서비스 목록 열기',
              onPressed: widget.options.isEmpty ? null : _openPickerSheet,
              iconSize: 28,
              icon: Icon(
                Icons.search_rounded,
                color: widget.options.isEmpty ? Colors.grey : MyApp.soriPurple,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServicePickerSheet extends StatefulWidget {
  const _ServicePickerSheet({
    required this.title,
    required this.options,
    required this.initialQuery,
  });

  final String title;
  final List<String> options;
  final String initialQuery;

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  late final TextEditingController _searchController;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _filtered = _apply(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _apply(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '샵 서비스 메뉴에서 선택하거나 검색하세요',
            style: TextStyle(
              fontSize: 13,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (v) => setState(() => _filtered = _apply(v)),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '서비스명 검색',
              prefixIcon: const Icon(Icons.search_rounded, size: 26),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '일치하는 서비스가 없어요',
                          style: TextStyle(
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_searchController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              _searchController.text.trim(),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: MyApp.soriPurple,
                            ),
                            child: Text(
                              '"${_searchController.text.trim()}" 직접 사용',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final name = _filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MedicalChipGroup extends StatelessWidget {
  const _MedicalChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.noneLabel,
    required this.otherController,
    required this.otherHint,
    required this.onToggle,
    required this.onOtherChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final String noneLabel;
  final TextEditingController otherController;
  final String otherHint;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOtherChanged;

  @override
  Widget build(BuildContext context) {
    final showOther =
        selected.contains(ChartMedicalChips.otherLabel) &&
        !selected.contains(noneLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((label) {
            final isSelected = selected.contains(label);
            return FilterChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => onToggle(label),
              selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
              checkmarkColor: MyApp.soriPurple,
              side: BorderSide(
                color: isSelected
                    ? MyApp.soriPurple.withValues(alpha: 0.45)
                    : Colors.grey.shade300,
              ),
            );
          }).toList(),
        ),
        if (showOther) ...[
          const SizedBox(height: 10),
          TextField(
            controller: otherController,
            onChanged: onOtherChanged,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '기타 직접 입력',
              hintText: otherHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
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
