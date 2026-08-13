import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chart_interview_chips.dart';
import '../models/chart_medical_chips.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/home_care_prescriptions.dart';
import '../routing/app_router.dart';
import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/chart_signature_storage.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/db_map.dart';
import '../utils/sori_scroll_behavior.dart';
import 'chart_consent_tab.dart';
import 'customer_link_popup.dart';
import 'management_menu_field.dart';
import 'membership_editor_sheet.dart';
import 'my_app.dart';

Future<void> openChartWriterForCustomer(
  BuildContext context, {
  required SoriStore store,
  required Customer customer,
  CustomerChart? existingChart,
  bool forceQuickChart = false,
}) async {
  final customerId = customer.id.trim();
  if (customerId.isEmpty) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('고객 정보 유실'),
        content: const Text(
          '고객 ID가 없어 차트를 열 수 없습니다. 고객을 다시 선택한 뒤 시도해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return;
  }
  final location = AppRouter.buildChartCreateLocation(
    customerId: customerId,
    chartId: existingChart?.id,
    forceQuickChart: forceQuickChart,
  );
  // 셸 밖 루트 스택으로 열어 하단바와 분리
  await context.push(location);
}

/// 원장용 차트 작성 (고객 식별·메디컬 이력·심리 인터뷰·방문 확인).
///
/// `customerId` 는 URL(`/chart/create?customerId=`)을 최우선으로 고정한다.
class AdminChartWriterPage extends StatefulWidget {
  const AdminChartWriterPage({
    super.key,
    required this.store,
    this.customerId,
    this.customer,
    this.existingChart,
    this.forceQuickChart = false,
  });

  final SoriStore store;

  /// URL / 라우터에서 전달된 고객 ID (SSOT).
  final String? customerId;

  /// 진입 시점 시드(선택). 없어도 [customerId] 로 Store에서 복원한다.
  final Customer? customer;
  final CustomerChart? existingChart;

  /// CRM '1초 간편 차트' 진입 — 최근 차트 프리필.
  /// 동의/서명 Bypass는 365일 이내 유효 동의에만 적용된다.
  final bool forceQuickChart;

  @override
  State<AdminChartWriterPage> createState() => _AdminChartWriterPageState();
}

class _AdminChartWriterPageState extends State<AdminChartWriterPage>
    with TickerProviderStateMixin {
  /// URL → widget 순으로 고정된 고객 ID (저장 시 SSOT).
  late String _boundCustomerId;

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
  Uint8List? _beforePreviewBytes;
  Uint8List? _afterPreviewBytes;
  String? _beforeUrl;
  String? _afterUrl;
  bool _beforeUploading = false;
  bool _afterUploading = false;

  final Set<String> _allergyChips = {};
  final Set<String> _skinChips = {};
  final Set<String> _sideEffectChips = {};
  final Set<String> _fears = {};
  final Set<String> _revisit = {};
  final Set<String> _concerns = {};
  final Set<String> _homeCarePrescriptions = {};
  bool _saving = false;
  /// 서명 패드 포인터 활성 중 PageView 스와이프 잠금.
  bool _signaturePointerActive = false;

  bool _consentCareNotice = false;
  bool _consentAbnormalReaction = false;
  bool _consentRefundPolicy = false;
  bool _consentPhoto = false;
  bool _consentMarketing = false;
  bool _consentOfflineOnly = false;
  String? _existingSignatureUrl;
  bool _infoViewConsent = false;

  /// 365일 이내 포괄 동의 재사용 차트.
  CustomerChart? _annualConsentSource;
  DateTime? _consentValidUntil;
  /// 원장이 [동의서 갱신/재작성]을 누른 경우 신규 폼 강제.
  bool _forceConsentRenewal = false;

  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _genderFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();
  final GlobalKey _careNameFieldKey = GlobalKey();
  final GlobalKey _consentSectionKey = GlobalKey();
  final GlobalKey _signatureFieldKey = GlobalKey();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;
  Timer? _highlightClearTimer;
  _ChartRequiredField? _inlineErrorField;
  _ChartRequiredField? _highlightField;

  bool get _consentMandatory =>
      _consentCareNotice &&
      _consentAbnormalReaction &&
      _consentRefundPolicy;

  /// 365일 이내 포괄 동의만 간편 모드(검증 Bypass). 갱신 강제 시 Bypass 불가.
  bool get _quickChartMode =>
      !_forceConsentRenewal &&
      _annualConsentSource != null &&
      _consentValidUntil != null;

  /// 이번 작성 세션에서 필수 동의+서명을 완료했는지.
  bool get _hasSessionConsentComplete {
    final hasPad = _signatureController.isNotEmpty;
    final hasSaved =
        (_existingSignatureUrl?.trim().isNotEmpty ?? false);
    return _consentMandatory && (hasPad || hasSaved);
  }

  /// DB 유효 동의 이력 또는 방금 작성 완료한 동의.
  bool get _hasValidConsent =>
      _quickChartMode || _hasSessionConsentComplete;

  _ChartRequiredField? _firstMissingRequiredField() {
    if (_nameController.text.trim().isEmpty) {
      return _ChartRequiredField.name;
    }
    if (_gender == null) return _ChartRequiredField.gender;
    if (SoriStore.normalizePhone(_phoneController.text).length < 10) {
      return _ChartRequiredField.phone;
    }
    if (_careNameController.text.trim().isEmpty) {
      return _ChartRequiredField.careName;
    }
    if (!_hasValidConsent) {
      if (!_consentMandatory) return _ChartRequiredField.consent;
      return _ChartRequiredField.signature;
    }
    return null;
  }

  bool _isRequiredFieldFilled(_ChartRequiredField field) {
    switch (field) {
      case _ChartRequiredField.name:
        return _nameController.text.trim().isNotEmpty;
      case _ChartRequiredField.gender:
        return _gender != null;
      case _ChartRequiredField.phone:
        return SoriStore.normalizePhone(_phoneController.text).length >= 10;
      case _ChartRequiredField.careName:
        return _careNameController.text.trim().isNotEmpty;
      case _ChartRequiredField.consent:
        return _hasValidConsent;
      case _ChartRequiredField.signature:
        return _hasValidConsent;
    }
  }

  GlobalKey _keyForRequiredField(_ChartRequiredField field) {
    switch (field) {
      case _ChartRequiredField.name:
        return _nameFieldKey;
      case _ChartRequiredField.gender:
        return _genderFieldKey;
      case _ChartRequiredField.phone:
        return _phoneFieldKey;
      case _ChartRequiredField.careName:
        return _careNameFieldKey;
      case _ChartRequiredField.consent:
        return _consentSectionKey;
      case _ChartRequiredField.signature:
        return _signatureFieldKey;
    }
  }

  void _pruneResolvedValidationErrors() {
    final inline = _inlineErrorField;
    final highlight = _highlightField;
    if (inline == null && highlight == null) return;
    final clearInline =
        inline != null && _isRequiredFieldFilled(inline);
    final clearHighlight =
        highlight != null && _isRequiredFieldFilled(highlight);
    if (!clearInline && !clearHighlight) return;
    setState(() {
      if (clearInline) _inlineErrorField = null;
      if (clearHighlight) _highlightField = null;
    });
  }

  Future<bool> _focusFirstMissingRequiredField() async {
    final field = _firstMissingRequiredField();
    if (field == null) return true;

    HapticFeedback.lightImpact();
    setState(() {
      _inlineErrorField = field;
      _highlightField = field;
    });

    final targetPage = field.isConsentTab ? 1 : 0;
    final currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? _tabController.index)
        : _tabController.index;
    if (currentPage != targetPage) {
      _tabController.animateTo(targetPage);
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    final targetContext = _keyForRequiredField(field).currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.35,
      );
    }

    if (!mounted) return false;
    _shakeController.forward(from: 0);
    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightField == field) {
        setState(() => _highlightField = null);
      }
    });
    return false;
  }

  /// 회차와 별도로 원장이 선택하는 첫 방문/재방문 인터뷰 모드.
  late bool _isFirstVisitMode;

  late List<CustomerMembership> _memberships;

  bool get _isFirstVisit => _isFirstVisitMode;

  List<String> get _serviceOptions => widget.store.shop.serviceNames;

  Customer _seedCustomer() {
    final id = _boundCustomerId;
    final found = widget.store.findCustomer(id) ?? widget.customer;
    if (found != null) return found;
    return Customer(
      id: id,
      name: '',
      phone: '',
      lastTreatmentDate: DateTime.now(),
      treatmentType: '',
      shopId: widget.store.shop.id,
    );
  }

  /// URL을 최우선으로 customerId를 잠근다.
  String _lockCustomerIdFromSources({RouteSettings? settings}) {
    final fromBrowser = AppRouter.chartCustomerIdFromBrowser()?.trim() ?? '';
    final fromRoute =
        AppRouter.chartCustomerIdFromSettings(settings)?.trim() ?? '';
    final fromWidget =
        (widget.customerId ?? widget.customer?.id ?? '').trim();
    if (fromBrowser.isNotEmpty) return fromBrowser;
    if (fromRoute.isNotEmpty) return fromRoute;
    return fromWidget;
  }

  Future<bool> _ensureCustomerIdForSave() async {
    final refreshed = _lockCustomerIdFromSources(
      settings: ModalRoute.of(context)?.settings,
    );
    if (refreshed.isNotEmpty) {
      _boundCustomerId = refreshed;
    }
    if (_boundCustomerId.trim().isNotEmpty) {
      return true;
    }
    if (!mounted) return false;
    await _showCustomerIdLostDialog();
    return false;
  }

  Future<void> _showCustomerIdLostDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('고객 정보 유실'),
        content: const Text(
          '고객 정보가 유실되었습니다. 고객 관리 화면에서 다시 진입해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _isCustomerIdPayloadError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('customer not found')) return true;
    return msg.contains('customer_id') &&
        (msg.contains('null') ||
            msg.contains('required') ||
            msg.contains('empty') ||
            msg.contains('유실') ||
            msg.contains('not found') ||
            msg.contains('missing required'));
  }

  @override
  void initState() {
    super.initState();
    _boundCustomerId = _lockCustomerIdFromSources();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _pageController = PageController();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: -3), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1.5),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
    _signatureController = SignatureController(
      penStrokeWidth: 2.8,
      penColor: const Color(0xFF2D3436),
      exportBackgroundColor: Colors.white,
    );
    _signatureController.addListener(_onSignatureChanged);
    widget.store.addListener(_onStoreMembershipSync);
    final existing = widget.existingChart;
    // 전화번호를 Unique Key로 기존 고객 프로필을 우선 로드 (자동 완성).
    final seedCustomer = _seedCustomer();
    final byPhone =
        widget.store.findCustomerByPhone(seedCustomer.phone);
    final c = byPhone ?? seedCustomer;
    if (c.id.trim().isNotEmpty && _boundCustomerId.isEmpty) {
      _boundCustomerId = c.id.trim();
    }
    // 간편 차트: 최근 차트에서 고정 정보 프리필 (신규 회차용 시드).
    final seed = existing ??
        (widget.forceQuickChart
            ? widget.store.latestChart(_boundCustomerId.isNotEmpty
                ? _boundCustomerId
                : c.id)
            : null);
    _visitNumber = existing?.visitNumber ??
        widget.store.nextVisitNumber(
          _boundCustomerId.isNotEmpty ? _boundCustomerId : c.id,
        );
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
    _phoneController.addListener(_onPhoneChanged);
    _addressController = TextEditingController(text: c.address);
    _occupationController = TextEditingController(text: c.occupation);
    // 차트 메디컬 우선, 구버전 고객 마스터 값은 폴백으로만 채움
    final allergyRaw = (seed?.allergyNotes.isNotEmpty ?? false)
        ? seed!.allergyNotes
        : c.allergyNotes;
    final skinRaw = (seed?.skinSensitivity.isNotEmpty ?? false)
        ? seed!.skinSensitivity
        : c.medicationHistory;
    final sideRaw = (seed?.sideEffectHistory.isNotEmpty ?? false)
        ? seed!.sideEffectHistory
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
    // 오늘 관리 메뉴는 신규 회차에서 항상 빈 칸 (기존 차트 수정 시에만 복원)
    _careNameController = TextEditingController(
      text: existing?.careName ?? '',
    );
    _careNameController.addListener(_onFormBasicsChanged);
    _nameController.addListener(_onFormBasicsChanged);
    _requestsController = TextEditingController(
      text: existing?.customerRequests ?? seed?.customerRequests ?? '',
    );
    _summaryController = TextEditingController(
      text: existing?.treatmentSummary ?? '',
    );
    _insightController = TextEditingController(
      text: existing?.directorInsight ?? '',
    );
    _guardianPhoneController = TextEditingController(
      text: existing?.guardianPhone ?? seed?.guardianPhone ?? '',
    );
    // 사진은 해당 회차 차트에만 귀속 — 신규 작성 시 이전 회차 사진을 끌어오지 않음
    _beforeUrl = existing?.beforeImageUrl;
    _afterUrl = existing?.afterImageUrl;
    _beforePreviewBytes = null;
    _afterPreviewBytes = null;
    _fears.addAll(existing?.firstVisitFearChips ?? const []);
    _revisit.addAll(existing?.revisitFeedbackChips ?? const []);
    _concerns.addAll(
      existing?.concernChips ??
          (widget.forceQuickChart ? seed?.concernChips ?? const [] : const []),
    );
    for (final tag in existing?.homeCarePrescriptions ??
        (widget.forceQuickChart
            ? seed?.homeCarePrescriptions ?? const <String>[]
            : const <String>[])) {
      final id = HomecareDictionary.canonicalize(tag);
      if (id != null) _homeCarePrescriptions.add(id);
    }
    _consentCareNotice = existing?.consentMandatory ?? false;
    _consentAbnormalReaction = existing?.consentMandatory ?? false;
    _consentRefundPolicy = existing?.consentMandatory ?? false;
    _consentPhoto = existing?.consentPhoto ?? seed?.consentPhoto ?? false;
    _consentMarketing =
        existing?.consentMarketing ?? seed?.consentMarketing ?? false;
    _consentOfflineOnly =
        existing?.consentOfflineOnly ?? seed?.consentOfflineOnly ?? false;
    _existingSignatureUrl = existing?.signatureUrl;
    _infoViewConsent =
        existing?.infoViewConsent ?? seed?.infoViewConsent ?? false;
    _refreshAnnualConsent(notify: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locked = _lockCustomerIdFromSources(
      settings: ModalRoute.of(context)?.settings,
    );
    if (locked.isNotEmpty && locked != _boundCustomerId) {
      _boundCustomerId = locked;
    }
  }

  void _onSignatureChanged() {
    if (!mounted) return;
    setState(() {});
    _pruneResolvedValidationErrors();
  }

  void _onFormBasicsChanged() {
    if (!mounted) return;
    setState(() {});
    _pruneResolvedValidationErrors();
  }

  void _onPhoneChanged() {
    _refreshAnnualConsent();
    _pruneResolvedValidationErrors();
  }

  void _onStoreMembershipSync() {
    if (!mounted) return;
    final live = widget.store.findCustomer(_boundCustomerId) ??
        widget.store.findCustomerByPhone(_phoneController.text);
    if (live == null) return;
    final next = List<CustomerMembership>.from(
      live.withSyncedMembershipMirrors().memberships,
    );
    if (_membershipListsEqual(_memberships, next)) return;
    setState(() => _memberships = next);
  }

  bool _membershipListsEqual(
    List<CustomerMembership> a,
    List<CustomerMembership> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].serviceName != b[i].serviceName ||
          a[i].totalVisits != b[i].totalVisits ||
          a[i].usedVisits != b[i].usedVisits) {
        return false;
      }
    }
    return true;
  }

  void _refreshAnnualConsent({bool notify = true}) {
    final covered = widget.store
        .latestConsentWithinYearForPhone(_phoneController.text);
    final until = SoriStore.consentValidUntil(covered);
    void apply() {
      _annualConsentSource = covered;
      _consentValidUntil = until;
      if (!_forceConsentRenewal && covered != null && until != null) {
        // 간편 모드: 기존 포괄 동의 플래그 재사용
        _consentCareNotice = true;
        _consentAbnormalReaction = true;
        _consentRefundPolicy = true;
        _consentPhoto = covered.consentPhoto;
        _consentMarketing = covered.consentMarketing;
        _consentOfflineOnly = covered.consentOfflineOnly;
        if (_existingSignatureUrl == null ||
            _existingSignatureUrl!.trim().isEmpty) {
          _existingSignatureUrl = covered.signatureUrl;
        }
      }
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _requestConsentRenewal() {
    setState(() {
      _forceConsentRenewal = true;
      _consentCareNotice = false;
      _consentAbnormalReaction = false;
      _consentRefundPolicy = false;
      _consentPhoto = false;
      _consentMarketing = false;
      _consentOfflineOnly = false;
      _signatureController.clear();
    });
    _tabController.animateTo(1);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _downloadConsentPdf() async {
    final url = (_annualConsentSource?.consentPdfUrl ??
            widget.existingChart?.consentPdfUrl)
        ?.trim();
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장된 동의서 PDF가 없습니다. 차트 저장 후 자동 생성됩니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _highlightClearTimer?.cancel();
    widget.store.removeListener(_onStoreMembershipSync);
    _shakeController.dispose();
    _tabController.dispose();
    _pageController.dispose();
    _signatureController.removeListener(_onSignatureChanged);
    _signatureController.dispose();
    _customNoController.dispose();
    _birthTextController.dispose();
    _nameController.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _allergyOtherController.dispose();
    _skinOtherController.dispose();
    _sideEffectOtherController.dispose();
    _careNameController.removeListener(_onFormBasicsChanged);
    _nameController.removeListener(_onFormBasicsChanged);
    _careNameController.dispose();
    _requestsController.dispose();
    _summaryController.dispose();
    _insightController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _openMembershipSheet() async {
    final live = widget.store.findCustomer(_boundCustomerId) ??
        widget.store.findCustomerByPhone(_phoneController.text) ??
        widget.customer;
    if (live == null) {
      final ok = await _ensureCustomerIdForSave();
      if (!ok) return;
      return;
    }
    final result = await showMembershipEditorSheet(
      context: context,
      store: widget.store,
      customer: live,
      initialMemberships: _memberships,
      persistImmediately: true,
    );
    if (!mounted || result == null) return;
    final refreshed = widget.store.findCustomer(live.id) ?? live;
    setState(() {
      _memberships = List<CustomerMembership>.from(
        refreshed.withSyncedMembershipMirrors().memberships,
      );
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
    _refreshAnnualConsent();
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

  Future<void> _attachPhoto({required bool isBefore}) async {
    final hasPhoto = isBefore
        ? ((_beforeUrl?.trim().isNotEmpty ?? false) ||
            _beforePreviewBytes != null)
        : ((_afterUrl?.trim().isNotEmpty ?? false) ||
            _afterPreviewBytes != null);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isBefore ? 'Before 사진' : 'After 사진',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: MyApp.soriPurple,
                    ),
                  ),
                  title: const Text(
                    '카메라로 직접 촬영',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('시술 전후 모습을 바로 촬영합니다'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(
                      isBefore: isBefore,
                      source: ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: MyApp.soriPurple,
                    ),
                  ),
                  title: const Text(
                    '디바이스 갤러리에서 선택',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('저장된 사진을 불러옵니다'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(
                      isBefore: isBefore,
                      source: ImageSource.gallery,
                    );
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: const Text(
                      '사진 삭제',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _clearPhoto(isBefore: isBefore);
                    },
                  ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(Icons.close, color: Colors.grey.shade700),
                  ),
                  title: const Text(
                    '취소',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearPhoto({required bool isBefore}) {
    setState(() {
      if (isBefore) {
        _beforePreviewBytes = null;
        _beforeUrl = null;
        _beforeUploading = false;
      } else {
        _afterPreviewBytes = null;
        _afterUrl = null;
        _afterUploading = false;
      }
    });
  }

  Future<void> _pickAndUploadPhoto({
    required bool isBefore,
    required ImageSource source,
  }) async {
    try {
      final picker = ImagePicker();
      // 1차: picker 단 리사이즈 (원본 메모리 폭주 방지)
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;

      final rawBytes = await file.readAsBytes();
      if (!mounted || rawBytes.isEmpty) return;

      setState(() {
        if (isBefore) {
          _beforePreviewBytes = rawBytes;
          _beforeUploading = true;
        } else {
          _afterPreviewBytes = rawBytes;
          _afterUploading = true;
        }
      });

      // 2차: WebP 강제 변환 + 긴 축 ≤1200 + quality≈80 (≤500KB 유도)
      final compressed = await ChartPhotoCompressor.toWebp(rawBytes);
      if (!mounted) return;
      if (compressed == null || compressed.isEmpty) {
        setState(() {
          if (isBefore) {
            _beforeUploading = false;
          } else {
            _afterUploading = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 압축(WebP)에 실패했어요. 다른 사진으로 다시 시도해 주세요.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        if (isBefore) {
          _beforePreviewBytes = compressed;
        } else {
          _afterPreviewBytes = compressed;
        }
      });

      final url = await ChartPhotoStorage.uploadWebp(
        bytes: compressed,
        shopId: widget.store.shop.id,
        customerId: _boundCustomerId,
        kind: isBefore ? 'before' : 'after',
      );

      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        setState(() {
          if (isBefore) {
            _beforeUploading = false;
          } else {
            _afterUploading = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 업로드에 실패했어요. 네트워크·Storage 버킷을 확인해 주세요.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        if (isBefore) {
          _beforeUrl = url;
          _beforeUploading = false;
        } else {
          _afterUrl = url;
          _afterUploading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isBefore) {
          _beforeUploading = false;
        } else {
          _afterUploading = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진 선택 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final ok = await _focusFirstMissingRequiredField();
    if (!ok) return;
    if (!mounted) return;
    // 이중 검사: URL/바인딩 customerId 필수 — 없으면 Request 자체를 보내지 않음
    final hasCustomer = await _ensureCustomerIdForSave();
    if (!hasCustomer) return;
    final customerIdForSave = _boundCustomerId.trim();
    if (customerIdForSave.isEmpty) {
      await _showCustomerIdLostDialog();
      return;
    }
    if (!mounted) return;
    if (_beforeUploading || _afterUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 업로드가 끝날 때까지 잠시만 기다려 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 서명 패드에 획이 있을 때만 업로드. 간편 모드는 기존 포괄 서명 재사용.
      String? signatureUrl = _quickChartMode
          ? (_annualConsentSource?.signatureUrl ?? _existingSignatureUrl)
          : _existingSignatureUrl;
      if (!_quickChartMode && _signatureController.isNotEmpty) {
        final bytes = await _signatureController.toPngBytes();
        if (bytes != null && bytes.isNotEmpty) {
          final uploaded = await ChartSignatureStorage.uploadPng(
            bytes: bytes,
            shopId: widget.store.shop.id,
            customerId: customerIdForSave,
          );
          if (uploaded != null) {
            signatureUrl = uploaded;
          }
        }
      }

      // 신규 동의 저장 시 signature_url 필수 — 빈 값이면 중단
      final resolvedSignature = (signatureUrl ?? '').trim();
      if (!_quickChartMode && resolvedSignature.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서명이 저장되지 않았습니다. 전자 동의서 탭에서 다시 서명해 주세요.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
        _tabController.animateTo(1);
        return;
      }

      final chart = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: customerIdForSave,
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
        beforeImageUrl: DbMap.asTextOrNull(_beforeUrl),
        afterImageUrl: DbMap.asTextOrNull(_afterUrl),
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
        consentMandatory: true,
        consentPhoto: _consentPhoto,
        consentMarketing: _consentPhoto && _consentMarketing,
        consentOfflineOnly: _consentPhoto && _consentOfflineOnly,
        signatureUrl: _quickChartMode
            ? (resolvedSignature.isNotEmpty
                ? resolvedSignature
                : (_annualConsentSource?.signatureUrl ??
                    _existingSignatureUrl))
            : resolvedSignature,
        homeCarePrescriptions:
            HomecareDictionary.sanitizeTagIds(_homeCarePrescriptions),
        guardianPhone: () {
          final d =
              SoriStore.normalizePhone(_guardianPhoneController.text);
          return d.isEmpty ? null : d;
        }(),
        infoViewConsent: _infoViewConsent,
      );

      if (!mounted) return;
      // 저장 직후 로컬 동의 상태 동기화 (탭 복귀/재진입 시 노란 바 방지)
      setState(() {
        _forceConsentRenewal = false;
        _existingSignatureUrl =
            chart.signatureUrl ?? resolvedSignature;
        _annualConsentSource = chart;
        _consentValidUntil = SoriStore.consentValidUntil(chart) ??
            DateTime.now().add(const Duration(days: 365));
        _consentCareNotice = true;
        _consentAbnormalReaction = true;
        _consentRefundPolicy = true;
      });

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
      widget.store.clearError();
      if (_isCustomerIdPayloadError(e)) {
        await _showCustomerIdLostDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: ${e.toString()}'),
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
    if (_boundCustomerId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('차트 작성'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2D3436),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '고객 정보가 유실되었습니다. 고객 관리 화면에서 다시 진입해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const SoriMouseWheelScrollBehavior(),
      child: Scaffold(
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
              physics: _signaturePointerActive
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
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
                  consentCareNotice: _consentCareNotice,
                  consentAbnormalReaction: _consentAbnormalReaction,
                  consentRefundPolicy: _consentRefundPolicy,
                  consentPhoto: _consentPhoto,
                  consentMarketing: _consentMarketing,
                  consentOfflineOnly: _consentOfflineOnly,
                  signatureController: _signatureController,
                  existingSignatureUrl: _quickChartMode
                      ? (_annualConsentSource?.signatureUrl ??
                          _existingSignatureUrl)
                      : _existingSignatureUrl,
                  consentPdfUrl: _annualConsentSource?.consentPdfUrl ??
                      widget.existingChart?.consentPdfUrl,
                  consentSignedAt: _annualConsentSource?.consentSignedAt ??
                      widget.existingChart?.consentSignedAt,
                  quickChartMode: _quickChartMode,
                  consentValidUntil: _consentValidUntil,
                  onRequestRenewal: _requestConsentRenewal,
                  onDownloadPdf: _downloadConsentPdf,
                  consentSectionKey: _consentSectionKey,
                  signatureFieldKey: _signatureFieldKey,
                  shakeAnimation: _shakeOffset,
                  highlightConsent:
                      _highlightField == _ChartRequiredField.consent,
                  highlightSignature:
                      _highlightField == _ChartRequiredField.signature,
                  showConsentError:
                      _inlineErrorField == _ChartRequiredField.consent,
                  showSignatureError:
                      _inlineErrorField == _ChartRequiredField.signature,
                  consentErrorText: _ChartRequiredField.consent.errorCopy,
                  signatureErrorText: _ChartRequiredField.signature.errorCopy,
                  onSignaturePointerActive: (active) {
                    if (_signaturePointerActive == active) return;
                    setState(() => _signaturePointerActive = active);
                  },
                  onCareNoticeChanged: (v) {
                    setState(() => _consentCareNotice = v);
                    _pruneResolvedValidationErrors();
                  },
                  onAbnormalReactionChanged: (v) {
                    setState(() => _consentAbnormalReaction = v);
                    _pruneResolvedValidationErrors();
                  },
                  onRefundPolicyChanged: (v) {
                    setState(() => _consentRefundPolicy = v);
                    _pruneResolvedValidationErrors();
                  },
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
                    backgroundColor: _hasValidConsent
                        ? const Color(0xFF2E7D32)
                        : MyApp.soriPurple,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving
                        ? '저장 중…'
                        : (_quickChartMode
                            ? '1초 간편 차트 저장 및 방문 확인'
                            : '차트 저장 및 방문 확인 완료'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  List<Widget> _buildChartFormChildren() {
    return [
                if (_quickChartMode) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Text(
                      '✅ 1년 포괄적 동의 완료 (유효기간: ${_consentValidUntil!.year}.${_consentValidUntil!.month.toString().padLeft(2, '0')}.${_consentValidUntil!.day.toString().padLeft(2, '0')} 까지) · 서명 없이 저장 가능',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ] else if (_hasSessionConsentComplete) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: const Text(
                      '✅ 전자 동의서 작성 완료 — 차트 저장 및 방문 확인을 진행할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Text(
                      widget.forceQuickChart
                          ? '⚠️ 동의서 갱신 필요 — 서명일로부터 1년이 지났거나 이력이 없습니다. 전자 동의서 탭에서 필수 동의·자필 서명을 완료해야 저장됩니다.'
                          : '⚠️ 전자 동의서 미완료 — 전자 동의서 탭에서 필수 동의·자필 서명을 완료해 주세요.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  ),
                ],
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
                      _SmartFocusTarget(
                        anchorKey: _nameFieldKey,
                        highlighted:
                            _highlightField == _ChartRequiredField.name,
                        showError: _inlineErrorField == _ChartRequiredField.name,
                        errorText: _ChartRequiredField.name.errorCopy,
                        shake: _shakeOffset,
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '고객 성함 *',
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _inlineErrorField ==
                                        _ChartRequiredField.name
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _inlineErrorField ==
                                        _ChartRequiredField.name
                                    ? const Color(0xFFE53935)
                                    : MyApp.soriPurple,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SmartFocusTarget(
                        anchorKey: _genderFieldKey,
                        highlighted:
                            _highlightField == _ChartRequiredField.gender,
                        showError:
                            _inlineErrorField == _ChartRequiredField.gender,
                        errorText: _ChartRequiredField.gender.errorCopy,
                        shake: _shakeOffset,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '성별 *',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('여성')),
                                    selected:
                                        _gender == CustomerGender.female,
                                    onSelected: (_) {
                                      setState(
                                        () =>
                                            _gender = CustomerGender.female,
                                      );
                                      _pruneResolvedValidationErrors();
                                    },
                                    selectedColor: MyApp.soriPurple
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('남성')),
                                    selected: _gender == CustomerGender.male,
                                    onSelected: (_) {
                                      setState(
                                        () => _gender = CustomerGender.male,
                                      );
                                      _pruneResolvedValidationErrors();
                                    },
                                    selectedColor: MyApp.soriPurple
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SmartFocusTarget(
                        anchorKey: _phoneFieldKey,
                        highlighted:
                            _highlightField == _ChartRequiredField.phone,
                        showError:
                            _inlineErrorField == _ChartRequiredField.phone,
                        errorText: _ChartRequiredField.phone.errorCopy,
                        shake: _shakeOffset,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _autofillFromPhone,
                          decoration: InputDecoration(
                            labelText: '전화번호 / 연락처 *',
                            hintText: '입력 시 기존 고객 정보 자동 완성',
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _inlineErrorField ==
                                        _ChartRequiredField.phone
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _inlineErrorField ==
                                        _ChartRequiredField.phone
                                    ? const Color(0xFFE53935)
                                    : MyApp.soriPurple,
                                width: 1.6,
                              ),
                            ),
                            suffixIcon: IconButton(
                              tooltip: '기존 정보 불러오기',
                              onPressed: _autofillFromPhone,
                              icon: const Icon(Icons.person_search_outlined),
                            ),
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
                  title: '관리 메뉴 목록 & 고객 요청사항',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SmartFocusTarget(
                        anchorKey: _careNameFieldKey,
                        highlighted:
                            _highlightField == _ChartRequiredField.careName,
                        showError:
                            _inlineErrorField == _ChartRequiredField.careName,
                        errorText: _ChartRequiredField.careName.errorCopy,
                        shake: _shakeOffset,
                        child: ManagementMenuField(
                          label: '관리 메뉴 목록 *',
                          value: _careNameController.text,
                          options: _serviceOptions,
                          onChanged: (v) {
                            setState(() => _careNameController.text = v);
                            _pruneResolvedValidationErrors();
                          },
                          hasError: _inlineErrorField ==
                              _ChartRequiredField.careName,
                        ),
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
                  title: '회원권',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _memberships.isEmpty
                            ? '등록된 회원권이 없습니다. 필요 시 아래에서 등록하세요.'
                            : '등록 ${_memberships.length}종 · 잔여 ${_memberships.fold<int>(0, (s, m) => s + m.remainingVisits)}회',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SoriTokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (_memberships.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._memberships.take(3).map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '· ${m.serviceName.isEmpty ? '(메뉴 미선택)' : m.serviceName} · 잔여 ${m.remainingVisits}회',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openMembershipSheet,
                          icon: const Icon(Icons.card_membership_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(color: SoriTokens.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          label: const Text(
                            '+ 회원권 등록 / 관리',
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
                              previewBytes: _beforePreviewBytes,
                              networkUrl: _beforeUrl,
                              uploading: _beforeUploading,
                              onTap: () => _attachPhoto(isBefore: true),
                              onClear: () => _clearPhoto(isBefore: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PhotoAttachBox(
                              title: 'After',
                              previewBytes: _afterPreviewBytes,
                              networkUrl: _afterUrl,
                              uploading: _afterUploading,
                              onTap: () => _attachPhoto(isBefore: false),
                              onClear: () => _clearPhoto(isBefore: false),
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
                        children: HomecareDictionary.allTagIds.map((id) {
                          final selected =
                              _homeCarePrescriptions.contains(id);
                          final label =
                              HomecareDictionary.chipLabelOf(id) ?? id;
                          return FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _homeCarePrescriptions.add(id);
                                } else {
                                  _homeCarePrescriptions.remove(id);
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

class _PhotoAttachBox extends StatelessWidget {
  const _PhotoAttachBox({
    required this.title,
    required this.onTap,
    required this.onClear,
    this.previewBytes,
    this.networkUrl,
    this.uploading = false,
  });

  final String title;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final Uint8List? previewBytes;
  final String? networkUrl;
  final bool uploading;

  bool get _hasImage =>
      previewBytes != null ||
      (networkUrl != null && networkUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F1FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: uploading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasImage
                  ? MyApp.soriPurple.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(previewBytes!, fit: BoxFit.cover)
                else if (networkUrl != null && networkUrl!.trim().isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: networkUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    fadeInDuration: const Duration(milliseconds: 160),
                    placeholder: (_, _) => _EmptyPhotoPlaceholder(title: title),
                    errorWidget: (_, _, _) =>
                        _EmptyPhotoPlaceholder(title: title),
                  )
                else
                  _EmptyPhotoPlaceholder(title: title),
                if (uploading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (_hasImage && !uploading)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClear,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hasImage && !uploading)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '다시 선택',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPhotoPlaceholder extends StatelessWidget {
  const _EmptyPhotoPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F1FB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          const Icon(Icons.add_a_photo_outlined, color: MyApp.soriPurple),
          const SizedBox(height: 8),
          Text(
            '📷 $title 촬영 / 선택',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartRequiredField {
  name,
  gender,
  phone,
  careName,
  consent,
  signature,
}

extension on _ChartRequiredField {
  bool get isConsentTab =>
      this == _ChartRequiredField.consent ||
      this == _ChartRequiredField.signature;

  String get errorCopy {
    switch (this) {
      case _ChartRequiredField.name:
      case _ChartRequiredField.careName:
        return '관리 메뉴를 선택해 주세요';
      case _ChartRequiredField.gender:
        return '성별을 선택해 주세요';
      case _ChartRequiredField.phone:
        return '연락처를 입력해 주세요';
      case _ChartRequiredField.consent:
        return '필수 동의 항목을 체크해 주세요';
      case _ChartRequiredField.signature:
        return '서명이 누락되었습니다';
    }
  }
}

/// 스마트 포커싱: 스크롤 앵커 + 흔들림 + 붉은 테두리 + 인라인 에러.
class _SmartFocusTarget extends StatelessWidget {
  const _SmartFocusTarget({
    required this.anchorKey,
    required this.highlighted,
    required this.showError,
    required this.errorText,
    required this.shake,
    required this.child,
  });

  final GlobalKey anchorKey;
  final bool highlighted;
  final bool showError;
  final String errorText;
  final Animation<double> shake;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: shake,
            builder: (context, child) {
              final dx = highlighted ? shake.value : 0.0;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(highlighted ? 3 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlighted
                      ? const Color(0xFFE53935)
                      : Colors.transparent,
                  width: highlighted ? 1.5 : 0,
                ),
              ),
              child: child,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: showError
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) => Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                      child: Text(
                        '* $errorText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
