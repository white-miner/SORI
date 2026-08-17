import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../data/memory_sori_repository.dart';
import '../data/repository_factory.dart';
import '../data/sori_repository.dart';
import '../models/ai_reply.dart';
import '../models/care_diary_note.dart';
import '../models/case_timeline_entry.dart';
import '../models/community_case_item.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/home_care_prescriptions.dart';
import '../models/kakao_alimtalk.dart';
import '../models/membership_ticket.dart';
import '../models/review_reply.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/seminar_class.dart';
import '../models/seminar_education_insight.dart';
import '../models/shop_highlight.dart';
import '../models/shop_tier_badge.dart';
import '../models/shop_service_item.dart';
import '../utils/db_map.dart';
import '../utils/korean_choseong.dart';
import 'consent_pdf_generator.dart';
import 'consent_pdf_storage.dart';
import 'shop_profile_storage.dart';
import 'sori_auth_service.dart';
import 'visit_trigger_service.dart';

/// 앱 Facade — UI는 Store, 데이터는 Repository (Memory | Supabase).
class SoriStore implements Listenable {
  SoriStore({
    VisitTriggerService? visitTrigger,
    SoriRepository? repository,
  })  : _visitTrigger = visitTrigger ?? VisitTriggerService(),
        _repository = repository ?? MemorySoriRepository() {
    _applySnapshot(MemorySoriRepository.createSeedSnapshot());
  }

  static final SoriStore instance = SoriStore();

  final VisitTriggerService _visitTrigger;
  SoriRepository _repository;

  bool isLoading = false;
  bool bootstrapComplete = false;
  bool bootstrapFailed = false;
  String? lastError;

  bool get isRemoteEnabled => _repository.isRemote;
  bool get hasError => lastError != null && lastError!.isNotEmpty;

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    _notify();
  }

  /// 스키마 드리프트/백그라운드 실패 — UI 전역 빨간 배너에 올리지 않음.
  static bool isNonFatalRemoteNoise(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst204') ||
        (msg.contains('could not find the') && msg.contains('column')) ||
        msg.contains('schema cache') ||
        (msg.contains('customer_reviews') && msg.contains('customer_id')) ||
        msg.contains('postgrestexception');
  }

  void _logQuiet(Object error, [String label = 'background']) {
    debugPrint('SoriStore quiet[$label]: $error');
  }

  void _setError(Object error, {bool userFacing = true}) {
    if (!userFacing || isNonFatalRemoteNoise(error)) {
      _logQuiet(error, userFacing ? 'schema' : 'background');
      return;
    }
    lastError = error.toString().replaceFirst('Exception: ', '');
    debugPrint('SoriStore error: $lastError');
  }

  late Shop shop;
  SessionUser? session;
  bool shopRegisteredByUser = false;
  final List<Customer> customers = [];
  final List<CustomerChart> charts = [];
  final List<CustomerReview> reviews = [];
  final List<AiReply> aiReplies = [];
  final List<CareDiaryNote> diaryNotes = [];
  final List<MembershipTicket> membershipTickets = [];
  final List<String> skinJournalEntries = [];
  final List<ShopGallerySlide> gallerySlides = [];
  final Set<String> reviewRequestedCustomerIds = {};
  final Set<String> followedShopIds = {};
  final List<ShopHighlight> shopHighlights = [];
  int shopFollowerCount = 0;
  bool shopFandomMetaLoading = false;
  final List<CommunityCaseItem> communityHotCases = [];
  bool communityHotCasesLoading = false;
  SeminarEducationInsight? seminarEducationInsight;
  bool seminarEducationLoading = false;
  String todayHomecareTip =
      '미지근한 물로 가볍게 클렌징하고, 보습 세럼을 손바닥 온기로 펴 발라 주세요.';

  /// 직전 방문 확인 시 회원권 차감 피드백 (Async 경로).
  String? lastVisitFeedback;
  bool? lastMembershipDeducted;

  static const List<String> puzzlePool = [
    '피부 톤이 밝아졌어요',
    '시술 후 자극이 적었어요',
    '보습감이 오래가요',
    '관리 설명이 친절했어요',
    '다음에도 방문하고 싶어요',
  ];

  final List<void Function()> _listeners = [];

  /// 미션 체크 디바운스 (차트별 마지막 터치 후 1.5초).
  final Map<String, Timer> _missionDebounceTimers = {};
  final Map<String, List<bool>> _pendingMissionChecks = {};

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void bindRepository(SoriRepository repository) {
    _repository = repository;
  }

  void _applySnapshot(SoriSnapshot snapshot) {
    shop = snapshot.shop;
    customers
      ..clear()
      ..addAll(snapshot.customers);
    charts
      ..clear()
      ..addAll(snapshot.charts);
    reviews
      ..clear()
      ..addAll(snapshot.reviews);
    aiReplies
      ..clear()
      ..addAll(snapshot.aiReplies);
    diaryNotes
      ..clear()
      ..addAll(snapshot.diaryNotes);
    gallerySlides
      ..clear()
      ..addAll(snapshot.gallerySlides);
    reviewRequestedCustomerIds
      ..clear()
      ..addAll(snapshot.reviewRequestedCustomerIds);
    todayHomecareTip = snapshot.todayHomecareTip;
  }

  /// 비동기 초기 로드 (Supabase 또는 Memory).
  Future<void> bootstrap({SoriRepository? repository}) async {
    if (repository != null) {
      _repository = repository;
    }
    isLoading = true;
    lastError = null;
    bootstrapFailed = false;
    _notify();
    try {
      final snapshot = await _repository.loadInitialData();
      _applySnapshot(snapshot);
      bootstrapComplete = true;
      bootstrapFailed = false;
    } catch (e, st) {
      debugPrint('bootstrap failed: $e\n$st');
      _setError(e, userFacing: false);
      bootstrapFailed = true;
      // UI가 죽지 않도록 시드 유지하되, Retry로 원격 재연결 가능
      if (customers.isEmpty) {
        _applySnapshot(MemorySoriRepository.createSeedSnapshot());
      }
      bootstrapComplete = true;
    } finally {
      isLoading = false;
      _notify();
      unawaited(refreshMembershipWallet());
    }
  }

  /// 네트워크 장애 후 원격 Repository로 재시도.
  Future<void> retryBootstrap() async {
    lastError = null;
    bootstrapFailed = false;
    _notify();
    bindRepository(createSoriRepository());
    await bootstrap();
  }

  /// 전화번호로 고객 조회 (원격 우선 → 로컬 캐시).
  Future<Customer?> lookupCustomerByPhone(String phone) async {
    final local = findCustomerByPhone(phone);
    if (!_repository.isRemote) return local;

    isLoading = true;
    lastError = null;
    _notify();
    try {
      final remote = await _repository.findCustomerByPhone(
        phone,
        shopId: shop.id,
      );
      if (remote != null) {
        final idx = customers.indexWhere((c) => c.id == remote.id);
        if (idx >= 0) {
          customers[idx] = remote;
        } else {
          customers.insert(0, remote);
        }
        _notify();
        return remote;
      }
      return local;
    } catch (e, st) {
      debugPrint('lookupCustomerByPhone failed: $e\n$st');
      _setError(e);
      return local;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void _mergeCustomer(Customer customer) {
    final idx = customers.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) {
      customers[idx] = customer;
    } else {
      customers.insert(0, customer);
    }
  }

  void _mergeChart(CustomerChart chart) {
    final idx = charts.indexWhere((c) => c.id == chart.id);
    if (idx >= 0) {
      charts[idx] = chart;
    } else {
      charts.insert(0, chart);
    }
  }

  void _mergeReview(CustomerReview review) {
    final idx = reviews.indexWhere((r) => r.id == review.id);
    if (idx >= 0) {
      reviews[idx] = review;
    } else {
      reviews.insert(0, review);
    }
  }

  /// 차트 저장 + 방문 확인 (원격 연동 시 Supabase CRUD).
  Future<CustomerChart> saveChartAndConfirmVisitAsync({
    required String customerId,
    required int visitNumber,
    String? customChartNo,
    String? chartId,
    required String careName,
    required String treatmentSummary,
    required String directorInsight,
    required List<String> concernChips,
    required List<String> firstVisitFearChips,
    required List<String> revisitFeedbackChips,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? customerName,
    String? customerPhone,
    CustomerGender? gender,
    DateTime? birthDate,
    String? address,
    String? occupation,
    String? allergyNotes,
    String? skinSensitivity,
    String? sideEffectHistory,
    List<CustomerMembership>? memberships,
    String? customerRequests,
    String? membershipServiceName,
    int? membershipTotalVisits,
    int? membershipUsedVisits,
    bool consentMandatory = false,
    bool consentPhoto = false,
    bool consentMarketing = false,
    bool consentOfflineOnly = false,
    String? signatureUrl,
    Uint8List? signaturePngBytes,
    List<String> homeCarePrescriptions = const [],
    String? guardianPhone,
    bool infoViewConsent = false,
  }) async {
    final boundCustomerId = customerId.trim();
    if (boundCustomerId.isEmpty) {
      throw StateError('customer_id is required for chart save');
    }
    if (blocksDirectorChartWrites) {
      throw StateError('고객 모드에서는 원장 차트를 저장할 수 없습니다.');
    }
    if (!_repository.isRemote) {
      final chart = saveChartAndConfirmVisit(
        customerId: boundCustomerId,
        visitNumber: visitNumber,
        customChartNo: customChartNo,
        chartId: chartId,
        careName: careName,
        treatmentSummary: treatmentSummary,
        directorInsight: directorInsight,
        concernChips: concernChips,
        firstVisitFearChips: firstVisitFearChips,
        revisitFeedbackChips: revisitFeedbackChips,
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
        customerName: customerName,
        customerPhone: customerPhone,
        gender: gender,
        birthDate: birthDate,
        address: address,
        occupation: occupation,
        allergyNotes: allergyNotes,
        skinSensitivity: skinSensitivity,
        sideEffectHistory: sideEffectHistory,
        memberships: memberships,
        customerRequests: customerRequests,
        membershipServiceName: membershipServiceName,
        membershipTotalVisits: membershipTotalVisits,
        membershipUsedVisits: membershipUsedVisits,
        consentMandatory: consentMandatory,
        consentPhoto: consentPhoto,
        consentMarketing: consentMarketing,
        consentOfflineOnly: consentOfflineOnly,
        signatureUrl: signatureUrl,
        homeCarePrescriptions: homeCarePrescriptions,
        guardianPhone: guardianPhone,
        infoViewConsent: infoViewConsent,
      );
      unawaited(
        _generateConsentPdfInBackground(
          chart,
          signaturePng: signaturePngBytes,
        ),
      );
      return chart;
    }

    isLoading = true;
    lastError = null;
    _notify();
    try {
      final wasAlreadyChecked = chartId != null &&
          charts.any((c) => c.id == chartId && c.visitChecked);
      final result = await _repository
          .saveChartAndConfirmVisit(
            SaveChartRequest(
              customerId: boundCustomerId,
              visitNumber: visitNumber,
              customChartNo: customChartNo,
              chartId: chartId,
              careName: careName,
              treatmentSummary: treatmentSummary,
              directorInsight: directorInsight,
              concernChips: concernChips,
              firstVisitFearChips: firstVisitFearChips,
              revisitFeedbackChips: revisitFeedbackChips,
              beforeImageUrl: beforeImageUrl,
              afterImageUrl: afterImageUrl,
              customerName: customerName,
              customerPhone: customerPhone == null
                  ? null
                  : normalizePhone(customerPhone),
              gender: gender,
              birthDate: birthDate,
              address: address,
              occupation: occupation,
              allergyNotes: allergyNotes,
              skinSensitivity: skinSensitivity,
              sideEffectHistory: sideEffectHistory,
              memberships: memberships,
              customerRequests: customerRequests,
              membershipServiceName: membershipServiceName,
              membershipTotalVisits: membershipTotalVisits,
              membershipUsedVisits: membershipUsedVisits,
              deductMembership: !wasAlreadyChecked,
              consentMandatory: consentMandatory,
              consentPhoto: consentPhoto,
              consentMarketing: consentMarketing,
              consentOfflineOnly: consentOfflineOnly,
              signatureUrl: signatureUrl,
              homeCarePrescriptions:
                  HomecareDictionary.sanitizeTagIds(homeCarePrescriptions),
              guardianPhone: () {
                final d = normalizePhone(guardianPhone ?? '');
                return d.isEmpty ? null : d;
              }(),
              infoViewConsent: infoViewConsent,
            ),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw TimeoutException(
              '차트 저장 응답이 지연되고 있습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
            ),
          );
      _mergeCustomer(result.customer);
      _mergeChart(result.chart);
      if (result.review != null) _mergeReview(result.review!);
      lastVisitFeedback = result.feedbackMessage.isNotEmpty
          ? result.feedbackMessage
          : null;
      lastMembershipDeducted = result.membershipDeducted;
      unawaited(refreshMembershipWallet());
      unawaited(
        _generateConsentPdfInBackground(
          result.chart,
          signaturePng: signaturePngBytes,
        ),
      );
      return result.chart;
    } catch (e, st) {
      debugPrint('saveChartAndConfirmVisitAsync failed: $e\n$st');
      _setError(e);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// 고객 모드에서는 원장 차트 본문 저장을 호출할 수 없다.
  bool get blocksDirectorChartWrites =>
      session != null && session!.activeMode == UserRole.customer;

  static String phoneLast4(String phone) {
    final d = normalizePhone(phone);
    if (d.length < 4) return d;
    return d.substring(d.length - 4);
  }

  // —— Auth / matching ——

  Customer? findCustomerByPhone(String phone) {
    final key = normalizePhone(phone);
    if (key.isEmpty) return null;
    try {
      return customers.firstWhere((c) => normalizePhone(c.phone) == key);
    } catch (_) {
      return null;
    }
  }

  /// 소셜/이메일 로그인 — 이름·전화 수집 후 온보딩으로 연결.
  SessionUser beginSocialLogin({
    required SocialProvider provider,
    required String name,
    required String phone,
    String? authUserId,
    String? providerId,
    String email = '',
    String avatarUrl = '',
  }) {
    session = SessionUser(
      role: UserRole.guest,
      name: name.trim().isEmpty ? '소리 회원' : name.trim(),
      phone: phone.trim(),
      provider: provider,
      authUserId: authUserId,
      providerId: providerId,
      email: email.trim(), // 카카오는 빈 문자열 허용
      avatarUrl: avatarUrl.trim(),
      onboardingComplete: false,
      shopSetupComplete: false,
      activeMode: UserRole.customer,
    );
    _notify();
    return session!;
  }

  /// Supabase Auth 세션 → 앱 SessionUser 동기화.
  /// 이메일 null(카카오)이어도 provider_id 기준으로 세션을 유지합니다.
  SessionUser syncFromAuthUser(User user) {
    final authId = user.id;
    final providerId = SoriAuthService.providerIdFromUser(user);
    final avatarUrl = SoriAuthService.avatarUrlFromUser(user);
    final displayName = SoriAuthService.displayNameFromUser(user);
    final existing = session;

    if (existing != null && existing.onboardingComplete) {
      final sameAuth = existing.authUserId == authId;
      final sameProvider = existing.providerId != null &&
          existing.providerId == providerId;
      if (sameAuth || sameProvider) {
        session = existing.copyWith(
          authUserId: authId,
          providerId: providerId,
          email: SoriAuthService.emailFromUser(user).isNotEmpty
              ? SoriAuthService.emailFromUser(user)
              : existing.email,
          name: existing.name.trim().isNotEmpty
              ? existing.name
              : displayName,
          avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : existing.avatarUrl,
        );
        _notify();
        return session!;
      }
    }

    if (existing != null &&
        existing.onboardingComplete &&
        existing.authUserId == null) {
      session = existing.copyWith(
        authUserId: authId,
        providerId: providerId,
        avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : existing.avatarUrl,
      );
      _notify();
      return session!;
    }

    final provider = SoriAuthService.providerFromUser(user);
    final phone = SoriAuthService.phoneFromUser(user);
    final email = SoriAuthService.emailFromUser(user);

    return beginSocialLogin(
      provider: provider,
      name: displayName,
      phone: phone,
      authUserId: authId,
      providerId: providerId,
      email: email,
      avatarUrl: avatarUrl,
    );
  }

  /// 로그인 성공 후 shops/customers 판별로 원장·고객 홈 세션을 구성.
  Future<SessionUser> hydrateSessionFromAuth(User user) async {
    syncFromAuthUser(user);
    if (session == null) {
      throw StateError('No session after syncFromAuthUser');
    }

    // Auth metadata → public.profiles upsert (이름/아바타)
    try {
      await _repository.upsertAuthProfile(
        userId: user.id,
        name: SoriAuthService.displayNameFromUser(user),
        avatarUrl: SoriAuthService.avatarUrlFromUser(user),
        phone: SoriAuthService.phoneFromUser(user),
      );
    } catch (e) {
      debugPrint('upsertAuthProfile skipped: $e');
    }

    if (session!.onboardingComplete) {
      return session!;
    }

    try {
      final resolved = await _repository.resolveAuthRole(user.id);
      if (resolved.isDirector && resolved.shop != null) {
        shop = resolved.shop!;
        shopRegisteredByUser = true;
        // 소유 샵 기준으로 데이터 재로드
        if (_repository.isRemote) {
          try {
            final snapshot = await _repository.loadInitialData();
            _applySnapshot(snapshot);
            shop = resolved.shop!;
          } catch (e) {
            debugPrint('hydrate reload after director resolve: $e');
          }
        }
        final ownerName = shop.ownerName?.trim();
        session = session!.copyWith(
          role: UserRole.director,
          name: session!.name.trim().isNotEmpty
              ? session!.name
              : (ownerName != null && ownerName.isNotEmpty
                  ? ownerName
                  : '원장'),
          onboardingComplete: true,
          shopSetupComplete: true,
          activeMode: UserRole.director,
          showFirstChartTutorial: false,
        );
        _notify();
        return session!;
      }

      if (resolved.isCustomer && resolved.customer != null) {
        final c = resolved.customer!;
        final idx = customers.indexWhere((e) => e.id == c.id);
        if (idx >= 0) {
          customers[idx] = c;
        } else {
          customers.insert(0, c);
        }
        session = session!.copyWith(
          role: UserRole.customer,
          customerId: c.id,
          name: c.name.trim().isNotEmpty ? c.name : session!.name,
          phone: c.phone.trim().isNotEmpty ? c.phone : session!.phone,
          onboardingComplete: true,
          shopSetupComplete: false,
          activeMode: UserRole.customer,
          showFirstChartTutorial: false,
        );
        _notify();
        return session!;
      }
    } catch (e, st) {
      debugPrint('hydrateSessionFromAuth resolve failed: $e\n$st');
    }

    _notify();
    return session!;
  }

  void updateSessionProfile({
    required String name,
    required String phone,
  }) {
    if (session == null) return;
    session = session!.copyWith(
      name: name.trim(),
      phone: phone.trim(),
    );
    _notify();
  }

  /// 프로필 관리 — 세션 + 연결된 고객 주소/이름 동기화.
  void updateMyProfile({
    required String name,
    required String phone,
    String? address,
  }) {
    updateSessionProfile(name: name, phone: phone);
    final customerId = session?.customerId;
    if (customerId == null) return;
    final idx = customers.indexWhere((c) => c.id == customerId);
    if (idx < 0) return;
    customers[idx] = customers[idx].copyWith(
      name: name.trim(),
      phone: phone.trim(),
      address: address?.trim(),
    );
    _notify();
    if (_repository.isRemote) {
      () async {
        try {
          final saved = await _repository.upsertCustomer(customers[idx]);
          final i = customers.indexWhere((c) => c.id == saved.id);
          if (i >= 0) customers[i] = saved;
          _notify();
        } catch (e) {
          debugPrint('updateMyProfile upsert failed: $e');
        }
      }();
    }
  }

  /// 역할 선택 완료. 고객이면 전화 매칭 후 바로 홈, 원장이면 샵 설정 필요.
  SessionUser completeRoleSelection(UserRole role) {
    if (session == null) throw StateError('No session');
    if (role == UserRole.customer) {
      var customer = findCustomerByPhone(session!.phone);
      if (customer == null) {
        customer = Customer(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          shopId: shop.id,
          name: session!.name,
          phone: session!.phone,
          lastTreatmentDate: DateTime.now(),
          treatmentType: '상담',
          membershipTotalVisits: 0,
        );
        customers.insert(0, customer);
      } else {
        final idx = customers.indexWhere((c) => c.id == customer!.id);
        customers[idx] = customer.copyWith(name: session!.name);
        customer = customers[idx];
      }
      session = session!.copyWith(
        role: UserRole.customer,
        customerId: customer.id,
        onboardingComplete: true,
        shopSetupComplete: false,
        activeMode: UserRole.customer,
        showFirstChartTutorial: false,
      );
      final authId = session!.authUserId;
      if (authId != null && authId.isNotEmpty) {
        unawaited(
          _repository.linkCustomerUser(
            customerId: customer.id,
            userId: authId,
          ),
        );
      }
    } else {
      session = session!.copyWith(
        role: UserRole.director,
        onboardingComplete: false,
        shopSetupComplete: false,
        activeMode: UserRole.director,
      );
    }
    _notify();
    return session!;
  }

  /// 고객 온보딩: 이름/연락처 저장 후 customers에 등록·Auth 연결.
  Future<SessionUser> completeCustomerOnboarding({
    required String name,
    required String phone,
  }) async {
    if (session == null) throw StateError('No session');
    updateSessionProfile(name: name, phone: phone);

    Customer saved;
    var customer = findCustomerByPhone(phone);
    if (customer == null) {
      if (_repository.isRemote) {
        try {
          saved = await _repository.registerCustomer(
            shopId: shop.id,
            name: name.trim(),
            phone: phone.trim(),
          );
        } catch (e) {
          debugPrint('registerCustomer failed, local fallback: $e');
          saved = Customer(
            id: 'c-${DateTime.now().millisecondsSinceEpoch}',
            shopId: shop.id,
            name: name.trim(),
            phone: phone.trim(),
            lastTreatmentDate: DateTime.now(),
            treatmentType: '상담',
            membershipTotalVisits: 0,
          );
        }
      } else {
        saved = Customer(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          shopId: shop.id,
          name: name.trim(),
          phone: phone.trim(),
          lastTreatmentDate: DateTime.now(),
          treatmentType: '상담',
          membershipTotalVisits: 0,
        );
      }
      customers.insert(0, saved);
    } else {
      final existing = customer;
      final updated = existing.copyWith(name: name.trim(), phone: phone.trim());
      final idx = customers.indexWhere((c) => c.id == existing.id);
      if (idx >= 0) customers[idx] = updated;
      saved = updated;
      if (_repository.isRemote) {
        try {
          saved = await _repository.upsertCustomer(updated);
          final i = customers.indexWhere((c) => c.id == saved.id);
          if (i >= 0) customers[i] = saved;
        } catch (e) {
          debugPrint('upsertCustomer onboarding failed: $e');
        }
      }
    }

    session = session!.copyWith(
      role: UserRole.customer,
      customerId: saved.id,
      name: name.trim(),
      phone: phone.trim(),
      onboardingComplete: true,
      shopSetupComplete: false,
      activeMode: UserRole.customer,
      showFirstChartTutorial: false,
    );

    final authId = session!.authUserId;
    if (authId != null && authId.isNotEmpty) {
      unawaited(
        _repository.linkCustomerUser(
          customerId: saved.id,
          userId: authId,
        ),
      );
    }
    _notify();
    return session!;
  }

  /// 원장 샵 프로필 등록 → 튜토리얼 카드 활성화 + 모드 토글 가능.
  SessionUser completeShopSetup({
    required String shopName,
    required String shopPhone,
    required String naverPlaceUrl,
  }) {
    if (session == null) throw StateError('No session');
    updateShopProfile(
      name: shopName,
      naverPlaceUrl: naverPlaceUrl,
      phone: shopPhone,
    );
    shop = shop.copyWith(ownerName: session!.name);
    shopRegisteredByUser = true;
    session = session!.copyWith(
      role: UserRole.director,
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
      showFirstChartTutorial: true,
    );
    final authId = session!.authUserId;
    if (authId != null && authId.isNotEmpty && shop.id.isNotEmpty) {
      unawaited(
        _repository.linkShopOwner(shopId: shop.id, userId: authId),
      );
    }
    _notify();
    return session!;
  }

  void toggleActiveMode() {
    if (session == null || !session!.canToggleMode) return;
    final next = session!.activeMode == UserRole.director
        ? UserRole.customer
        : UserRole.director;

    if (next == UserRole.customer) {
      var customer = findCustomerByPhone(session!.phone);
      if (customer == null) {
        customer = Customer(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          shopId: shop.id,
          name: session!.name,
          phone: session!.phone,
          lastTreatmentDate: DateTime.now(),
          treatmentType: '상담',
          membershipTotalVisits: 0,
        );
        customers.insert(0, customer);
      }
      session = session!.copyWith(
        activeMode: UserRole.customer,
        customerId: customer.id,
      );
    } else {
      session = session!.copyWith(activeMode: UserRole.director);
    }
    _notify();
  }

  void dismissFirstChartTutorial() {
    if (session == null) return;
    session = session!.copyWith(showFirstChartTutorial: false);
    _notify();
  }

  /// @deprecated — 소셜+온보딩 플로우 사용. 호환용 유지.
  SessionUser loginDirector({
    required String name,
    required String phone,
  }) {
    beginSocialLogin(
      provider: SocialProvider.kakao,
      name: name,
      phone: phone,
    );
    completeRoleSelection(UserRole.director);
    return completeShopSetup(
      shopName: shop.name,
      shopPhone: phone,
      naverPlaceUrl: shop.naverPlaceUrl,
    );
  }

  /// @deprecated — 소셜+온보딩 플로우 사용. 호환용 유지.
  SessionUser loginCustomer({
    required String name,
    required String phone,
  }) {
    beginSocialLogin(
      provider: SocialProvider.kakao,
      name: name,
      phone: phone,
    );
    return completeRoleSelection(UserRole.customer);
  }

  void logout() {
    session = null;
    _notify();
    if (SoriAuthService.instance.isAvailable) {
      unawaited(SoriAuthService.instance.signOut());
    }
  }

  bool verifyPhoneLast4({
    required String expectedPhone,
    required String inputLast4,
  }) {
    return phoneLast4(expectedPhone) == inputLast4.trim();
  }

  void updateShopProfile({
    required String name,
    required String naverPlaceUrl,
    String? naverBookingUrl,
    String? naverReviewWriteUrl,
    String? ownerName,
    String? address,
    String? phone,
    String? operatingHours,
    String? snsBlogUrl,
    String? snsInstagramUrl,
    String? bio,
    String? profileImageUrl,
    List<ShopServiceItem>? serviceMenu,
    int? monthlyCapa,
  }) {
    shop = shop.copyWith(
      name: name.trim(),
      naverPlaceUrl: naverPlaceUrl.trim(),
      naverBookingUrl: naverBookingUrl?.trim(),
      naverReviewWriteUrl: naverReviewWriteUrl?.trim(),
      ownerName: ownerName?.trim(),
      address: address?.trim(),
      phone: phone?.trim(),
      operatingHours: operatingHours?.trim(),
      snsBlogUrl: snsBlogUrl?.trim(),
      snsInstagramUrl: snsInstagramUrl?.trim(),
      bio: bio?.trim(),
      profileImageUrl: profileImageUrl?.trim(),
      serviceMenu: serviceMenu,
      monthlyCapa: monthlyCapa,
    );
    _notify();
    if (_repository.isRemote) {
      () async {
        try {
          shop = await _repository.upsertShop(shop);
          _notify();
        } catch (e) {
          _setError(e, userFacing: false);
          _notify();
        }
      }();
    }
  }

  /// 샵 프로필 아바타 업로드 → Storage → shops.profile_image_url.
  Future<bool> uploadShopProfileImage(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    final shopId = shop.id.trim().isEmpty ? 'local-shop' : shop.id.trim();
    final url = await ShopProfileStorage.uploadAvatar(
      bytes: bytes,
      shopId: shopId,
    );
    if (url == null || url.trim().isEmpty) {
      // 로컬/스토리지 미연결 시 data URL로 즉시 미리보기
      if (!_repository.isRemote) {
        final b64 = base64Encode(bytes);
        shop = shop.copyWith(profileImageUrl: 'data:image/jpeg;base64,$b64');
        _notify();
        return true;
      }
      return false;
    }
    shop = shop.copyWith(profileImageUrl: url.trim());
    _notify();
    if (_repository.isRemote) {
      try {
        shop = await _repository.upsertShop(shop);
        _notify();
      } catch (e) {
        debugPrint('uploadShopProfileImage upsert failed: $e');
      }
    }
    return true;
  }

  /// 서명 완료 차트 → A4 동의서 PDF 생성·업로드 (비차단).
  Future<void> _generateConsentPdfInBackground(
    CustomerChart chart, {
    Uint8List? signaturePng,
  }) async {
    if (!chart.isConsentSigned &&
        (signaturePng == null || signaturePng.isEmpty)) {
      return;
    }
    try {
      final customer = findCustomer(chart.customerId);
      final careFallback = () {
        final t = customer?.treatmentType.trim() ?? '';
        if (t.isNotEmpty) return t;
        final m = customer?.primaryMembership?.serviceName.trim() ?? '';
        if (m.isNotEmpty) return m;
        return null;
      }();
      final pdfBytes = await ConsentPdfGenerator.buildBytes(
        shopName: shop.name,
        customerName: customer?.name ?? '고객',
        customerPhone: customer?.phone ?? '',
        chart: chart,
        signaturePng: signaturePng,
        signatureUrl: chart.signatureUrl,
        shopOwnerName: shop.ownerName,
        careMenuName: careFallback,
      );
      final url = await ConsentPdfStorage.uploadPdf(
        bytes: pdfBytes,
        shopId: chart.shopId,
        customerId: chart.customerId,
        chartId: chart.id,
      );
      if (url == null || url.isEmpty) return;

      final updated = chart.copyWith(consentPdfUrl: url);
      _mergeChart(updated);
      _notify();

      if (_repository.isRemote && !_isTempId(chart.id)) {
        try {
          await _repository.updateChartConsentPdfUrl(
            chartId: chart.id,
            consentPdfUrl: url,
          );
        } catch (e) {
          debugPrint('updateChartConsentPdfUrl failed: $e');
        }
      }
    } catch (e, st) {
      debugPrint('consent pdf background failed: $e\n$st');
    }
  }

  bool _isTempId(String id) =>
      id.isEmpty || id.startsWith('local-') || id.startsWith('temp-');

  /// 장기 미방문 부채 소거 — 회원권 사용요청 MOCK 발송.
  Future<KakaoAlimtalkSendResult> sendMembershipUsageRequest({
    required String customerId,
  }) async {
    final customer = findCustomer(customerId);
    if (customer == null) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'customer_not_found',
        message: '고객을 찾을 수 없습니다.',
      );
    }
    final content =
        '${customer.name} 고객님, 남겨 두신 회원권 잔여 ${customer.membershipRemainingVisits}회가 있어요. '
        '일정 잡아 주시면 우선 안내드릴게요.';
    final result = await sendKakaoAlimtalk(
      customerPhone: customer.phone,
      content: content,
      templateCode: KakaoAlimtalkPricing.membershipUsageTemplate,
    );
    if (result.ok) {
      final now = DateTime.now();
      final updated = customer.copyWith(lastPromotionSentAt: now);
      _mergeCustomer(updated);
      _notify();
      if (_repository.isRemote) {
        try {
          await _repository.upsertCustomer(updated);
        } catch (e) {
          debugPrint('last_promotion_sent_at upsert failed: $e');
        }
      }
    }
    return result;
  }

  List<Customer> searchCustomers(String query) {
    if (query.trim().isEmpty) return List.of(customers);
    final q = query.trim();
    final digits = normalizePhone(query);
    return customers.where((c) {
      if (KoreanChoseong.matchesName(c.name, q)) return true;
      if (digits.isNotEmpty && normalizePhone(c.phone).contains(digits)) {
        return true;
      }
      return false;
    }).toList();
  }

  List<CustomerChart> openFeedbackChartsForCustomer(String customerId) {
    return chartsForCustomer(customerId).where((c) => c.hasFeedbackLine).toList();
  }

  // —— Lookups ——

  Customer? findCustomer(String id) {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CustomerChart? findChartById(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    try {
      return charts.firstWhere((c) => c.id == normalized);
    } catch (_) {
      return null;
    }
  }

  CustomerChart? findChartByToken(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) return null;
    try {
      return charts.firstWhere((c) => c.feedbackToken == normalized);
    } catch (_) {
      return null;
    }
  }

  List<CustomerChart> chartsForCustomer(String customerId) {
    return charts.where((c) => c.customerId == customerId).toList()
      ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
  }

  /// 전화번호 기준, 서명 완료 + 365일 이내 가장 최근 차트.
  CustomerChart? latestConsentWithinYearForPhone(String phone) {
    final digits = normalizePhone(phone);
    if (digits.length < 10) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    CustomerChart? best;
    DateTime? bestAt;
    for (final customer in customers) {
      if (normalizePhone(customer.phone) != digits) continue;
      for (final chart in charts.where((c) => c.customerId == customer.id)) {
        if (!chart.isConsentSigned) continue;
        final signedAt = chart.consentSignedAt;
        if (signedAt == null || signedAt.isBefore(cutoff)) continue;
        if (bestAt == null || signedAt.isAfter(bestAt)) {
          best = chart;
          bestAt = signedAt;
        }
      }
    }
    return best;
  }

  /// 포괄 동의 유효 만료일 (서명일 + 365일).
  static DateTime? consentValidUntil(CustomerChart? chart) {
    if (chart == null || !chart.isConsentSigned) return null;
    final signedAt = chart.consentSignedAt;
    if (signedAt == null) return null;
    return signedAt.add(const Duration(days: 365));
  }

  /// 고객 프로필(인적·메모) 저장.
  Future<Customer> saveCustomerProfile(Customer customer) async {
    final synced = customer.withSyncedMembershipMirrors();
    if (!_repository.isRemote) {
      _mergeCustomer(synced);
      _notify();
      return synced;
    }
    isLoading = true;
    lastError = null;
    _notify();
    try {
      final saved = await _repository.upsertCustomer(synced);
      _mergeCustomer(saved);
      return saved;
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// 고객의 가장 유효 동의 차트 (서명/PDF).
  CustomerChart? latestSignedConsentChart(String customerId) {
    final list = chartsForCustomer(customerId);
    for (final c in list) {
      if (c.isConsentSigned && consentValidUntil(c) != null) {
        final until = consentValidUntil(c)!;
        if (!until.isBefore(DateTime.now())) return c;
      }
    }
    for (final c in list) {
      if (c.isConsentSigned) return c;
    }
    return null;
  }

  CustomerChart? latestChart(String customerId) {
    final list = chartsForCustomer(customerId);
    return list.isEmpty ? null : list.first;
  }

  int nextVisitNumber(String customerId) {
    final list = chartsForCustomer(customerId);
    if (list.isEmpty) return 1;
    return list.first.visitNumber + 1;
  }

  /// 종이 차트와 맞출 수동 차트 번호 제안값 (기존 숫자 최대 + 1).
  String suggestNextChartNumber() {
    var maxNo = 0;
    for (final chart in charts) {
      final raw = chart.customChartNo?.trim() ?? '';
      if (raw.isEmpty) continue;
      final n = int.tryParse(raw.replaceAll(RegExp(r'\D'), ''));
      if (n != null && n > maxNo) maxNo = n;
    }
    return '${maxNo + 1}';
  }

  CustomerReview? reviewForChart(String chartId) {
    try {
      return reviews.firstWhere((r) => r.chartId == chartId);
    } catch (_) {
      return null;
    }
  }

  CustomerReview? reviewById(String reviewId) {
    try {
      return reviews.firstWhere((r) => r.id == reviewId);
    } catch (_) {
      return null;
    }
  }

  /// 원장 리뷰 인박스용 조인 행 (리뷰 + 고객 + 차트).
  List<DirectorReviewInboxItem> directorReviewInboxItems() {
    final items = <DirectorReviewInboxItem>[];
    for (final review in reviews) {
      if (!review.isInboxVisible) continue;
      final customer = findCustomer(review.customerId);
      CustomerChart? chart;
      try {
        chart = charts.firstWhere((c) => c.id == review.chartId);
      } catch (_) {
        chart = null;
      }
      items.add(
        DirectorReviewInboxItem(
          review: review,
          customer: customer,
          chart: chart,
        ),
      );
    }
    return items;
  }

  /// 원장 답글 저장 (DB 반영 + 로컬 미러).
  Future<CustomerReview> saveDirectorReviewReply({
    required String reviewId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('답글 내용을 입력해 주세요.');
    }
    final local = reviewById(reviewId);
    if (local == null) {
      throw StateError('리뷰를 찾을 수 없습니다.');
    }
    final optimistic = local.copyWith(
      directorReply: trimmed,
      directorRepliedAt: DateTime.now(),
    );
    _mergeReview(optimistic);
    _notify();

    try {
      final remote = await _repository.saveDirectorReviewReply(
        reviewId: reviewId,
        shopId: local.shopId.isNotEmpty ? local.shopId : shop.id,
        body: trimmed,
      );
      // 원격이 최소 필드만 돌려줄 수 있어 로컬과 병합
      _mergeReview(
        local.copyWith(
          directorReply: remote.directorReply ?? trimmed,
          directorRepliedAt: remote.directorRepliedAt ?? DateTime.now(),
          rating: remote.rating ?? local.rating,
          status: remote.status,
        ),
      );
      lastError = null;
      _notify();
      return reviewById(reviewId)!;
    } catch (e, st) {
      debugPrint('saveDirectorReviewReply failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      rethrow;
    }
  }

  /// 특정 리뷰의 원장 답글 히스토리 (chart → review → replies 스레드).
  Future<List<ReviewReply>> loadReviewReplies(String reviewId) {
    return _repository.loadReviewReplies(reviewId);
  }

  /// 네이버 플레이스 리뷰 등록 트래킹 (clipboard CTA 후).
  /// 원격 동기화 실패 시 1회 재시도 후 예외를 다시 던져 UI가 상태를 구분하게 한다.
  Future<CustomerReview?> markNaverRegistered({
    required String chartId,
    String? composedText,
  }) async {
    // 로컬 캐시 선반영
    final local = reviewForChart(chartId);
    if (local != null) {
      _mergeReview(
        local.copyWith(
          naverRegistered: true,
          naverRegisteredAt: DateTime.now(),
          editedText: composedText ?? local.editedText,
          status: ReviewStatus.published,
        ),
      );
      _notify();
    }

    Object? lastFailure;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final remote = await _repository.markNaverRegistered(
          chartId: chartId,
          composedText: composedText,
        );
        if (remote != null) {
          _mergeReview(remote);
          lastError = null;
          _notify();
          return remote;
        }
        if (!_repository.isRemote) {
          return reviewForChart(chartId);
        }
        lastFailure = StateError('naver_registered sync returned empty');
      } catch (e, st) {
        lastFailure = e;
        debugPrint('markNaverRegistered attempt ${attempt + 1} failed: $e\n$st');
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }

    _setError(
      lastFailure ?? StateError('naver_registered sync failed'),
      userFacing: false,
    );
    _notify();
    throw lastFailure ?? StateError('naver_registered sync failed');
  }

  AiReply? aiReplyForReview(String reviewId) {
    try {
      return aiReplies.firstWhere((r) => r.reviewId == reviewId);
    } catch (_) {
      return null;
    }
  }

  /// Hash routing용 고객 딥링크: `/#/review?token=...` (GitHub Pages 404 방지)
  static String buildCustomerReviewUrl(String token) {
    final encoded = Uri.encodeQueryComponent(token);
    return '${_pagesBaseUrl()}#/review?token=$encoded';
  }

  /// 카카오 알림톡 랜딩: `/#/care-report/:chartId`
  static String buildCareReportUrl(String chartId) {
    final id = Uri.encodeComponent(chartId.trim());
    return '${_pagesBaseUrl()}#/care-report/$id';
  }

  /// 알림톡 MOCK 발송 — 잔여 포인트 65 이상일 때만 차감·로그.
  Future<KakaoAlimtalkSendResult> sendKakaoAlimtalk({
    required String customerPhone,
    required String content,
    String templateCode = KakaoAlimtalkPricing.careReportTemplate,
    int cost = KakaoAlimtalkPricing.sendCostPoint,
  }) async {
    final shopId = shop.id.trim();
    if (shopId.isEmpty) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'shop_not_found',
        message: '샵 정보가 없습니다.',
      );
    }

    if (shop.kakaoPoint < cost) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'insufficient_kakao_point',
        message: '알림톡 포인트가 부족합니다. 충전 후 이용해 주세요.',
        remainingPoints: shop.kakaoPoint,
      );
    }

    try {
      if (!_repository.isRemote) {
        final next = shop.kakaoPoint - cost;
        shop = shop.copyWith(kakaoPoint: next);
        _notify();
        return KakaoAlimtalkSendResult.success(
          logId: 'local-${DateTime.now().millisecondsSinceEpoch}',
          remainingPoints: next,
        );
      }

      final result = await _repository.sendKakaoAlimtalkMock(
        shopId: shopId,
        customerPhone: normalizePhone(customerPhone),
        templateCode: templateCode,
        content: content,
        cost: cost,
      );

      if (result.ok) {
        final next = (result.remainingPoints != null &&
                result.remainingPoints! >= 0)
            ? result.remainingPoints!
            : shop.kakaoPoint - cost;
        shop = shop.copyWith(kakaoPoint: next);
        _notify();
        return KakaoAlimtalkSendResult.success(
          logId: result.logId ?? 'ok',
          remainingPoints: next,
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('sendKakaoAlimtalk failed: $e\n$st');
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'send_failed',
        message: e.toString(),
        remainingPoints: shop.kakaoPoint,
      );
    }
  }

  Future<PublicCareReport?> loadPublicCareReport(String chartId) async {
    final local = findChartById(chartId);
    if (local != null) {
      final customer = findCustomer(local.customerId);
      // 로컬 샵이 다르면 최소 정보로 구성
      final localShop =
          local.shopId == shop.id ? shop : shop.copyWith(id: local.shopId);
      return PublicCareReport(
        chart: local,
        shop: localShop,
        customerDisplayName: customer?.name,
      );
    }
    try {
      return await _repository.loadPublicCareReport(chartId);
    } catch (e, st) {
      debugPrint('loadPublicCareReport failed: $e\n$st');
      return null;
    }
  }

  /// 샵 공용 진입 URL (고객 로그인/리뷰 탭).
  static String buildAppEntryUrl() => '${_pagesBaseUrl()}#/';

  static String _pagesBaseUrl() {
    final base = Uri.base;
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    var path = base.path;
    final hashIndex = path.indexOf('#');
    if (hashIndex >= 0) {
      path = path.substring(0, hashIndex);
    }
    if (path.endsWith('index.html')) {
      path = path.substring(0, path.length - 'index.html'.length);
    }
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    return '$origin$path';
  }

  void markReviewRequested(String customerId) {
    reviewRequestedCustomerIds.add(customerId);
    _notify();
  }

  bool isReviewRequested(String customerId) =>
      reviewRequestedCustomerIds.contains(customerId);

  bool isFollowingShop([String? shopId]) {
    final id = (shopId ?? shop.id).trim();
    return id.isNotEmpty && followedShopIds.contains(id);
  }

  bool toggleFollowShop([String? shopId]) {
    final id = (shopId ?? shop.id).trim();
    if (id.isEmpty) return false;
    final wasFollowing = followedShopIds.contains(id);
    if (wasFollowing) {
      followedShopIds.remove(id);
      shopFollowerCount = (shopFollowerCount - 1).clamp(0, 999999);
    } else {
      followedShopIds.add(id);
      shopFollowerCount += 1;
    }
    _notify();

    final customerId = session?.customerId?.trim() ?? '';
    if (customerId.isNotEmpty) {
      unawaited(() async {
        try {
          await _repository.setShopFollow(
            shopId: id,
            customerId: customerId,
            following: !wasFollowing,
          );
          final count = await _repository.countShopFollowers(id);
          if (count > 0 || _repository.isRemote) {
            shopFollowerCount = count;
            _notify();
          }
        } catch (e) {
          debugPrint('toggleFollowShop remote failed: $e');
        }
      }());
    }
    return followedShopIds.contains(id);
  }

  /// 하이라이트 · 팔로워 수 · 내 팔로우 상태 동기화.
  Future<void> refreshShopFandomMeta() async {
    if (shopFandomMetaLoading) return;
    shopFandomMetaLoading = true;
    _notify();
    final shopId = shop.id.trim();
    try {
      if (shopId.isNotEmpty) {
        final highlights = await _repository.loadShopHighlights(shopId);
        shopHighlights
          ..clear()
          ..addAll(highlights);
        shopFollowerCount = await _repository.countShopFollowers(shopId);
        final customerId = session?.customerId?.trim() ?? '';
        if (customerId.isNotEmpty) {
          final following = await _repository.isShopFollowed(
            shopId: shopId,
            customerId: customerId,
          );
          if (following) {
            followedShopIds.add(shopId);
          } else {
            followedShopIds.remove(shopId);
          }
        }
      }
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshShopFandomMeta failed: $e\n$st');
    } finally {
      shopFandomMetaLoading = false;
      _notify();
    }
  }

  /// 전국 핫 케이스 피드 로드 (오픈 커뮤니티).
  Future<void> refreshCommunityHotCases() async {
    if (communityHotCasesLoading) return;
    communityHotCasesLoading = true;
    _notify();
    try {
      final items = await _repository.loadCommunityHotCases();
      communityHotCases
        ..clear()
        ..addAll(items);
      // 단골 샵 리뷰 미러도 보강
      for (final item in items) {
        final r = item.review;
        if (r != null) _mergeReview(r);
      }
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshCommunityHotCases failed: $e\n$st');
    } finally {
      communityHotCasesLoading = false;
      _notify();
    }
  }

  /// 동일 고객·태그 회차 타임라인.
  Future<List<CaseTimelineEntry>> loadCaseTimelineGroup(String chartId) async {
    final id = chartId.trim();
    if (id.isEmpty) return const [];

    final local = findChartById(id);
    if (local != null && local.customerId.trim().isNotEmpty) {
      final tags = local.careTags.toSet();
      final grouped = charts
          .where((c) {
            if (c.customerId != local.customerId || c.shopId != local.shopId) {
              return false;
            }
            if (!c.caseShared) return false;
            if (c.id == id) return true;
            if (tags.isEmpty) return true;
            return c.careTags.any(tags.contains);
          })
          .map(
            (c) => CaseTimelineEntry(
              chartId: c.id,
              visitNumber: c.visitNumber,
              careName: c.careName,
              beforeImageUrl: c.beforeImageUrl,
              afterImageUrl: c.afterImageUrl,
              careTags: c.careTags,
              createdAt: c.createdAt ?? c.visitCheckedAt,
            ),
          )
          .toList()
        ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
      if (grouped.isNotEmpty) return grouped;
    }

    try {
      return await _repository.loadCaseTimelineGroup(id);
    } catch (e, st) {
      debugPrint('loadCaseTimelineGroup failed: $e\n$st');
      return const [];
    }
  }

  Future<bool> requestSeminar({
    required String caseId,
    required String requestorShopId,
  }) async {
    try {
      await _repository.insertSeminarRequest(
        caseId: caseId,
        requestorShopId: requestorShopId,
      );
      lastError = null;
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('requestSeminar failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return false;
    }
  }

  Future<void> refreshSeminarEducationInsight() async {
    if (seminarEducationLoading) return;
    seminarEducationLoading = true;
    _notify();
    final shopId = shop.id.trim();
    try {
      seminarEducationInsight =
          await _repository.loadSeminarEducationInsight(shopId);
      final insight = seminarEducationInsight;
      if (insight != null) {
        shop = shop.copyWith(
          soriCashBalance: insight.soriCashBalance > 0
              ? insight.soriCashBalance
              : shop.soriCashBalance,
          tierBadge: insight.tierBadgeLabel.isNotEmpty
              ? ShopTierBadge.fromDb(insight.tierBadgeLabel)
              : shop.tierBadge,
        );
      }
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshSeminarEducationInsight failed: $e\n$st');
    } finally {
      seminarEducationLoading = false;
      _notify();
    }
  }

  Future<SeminarClass?> createSeminarClass(SeminarClass draft) async {
    try {
      final created = await _repository.createSeminarClass(draft);
      lastError = null;
      _notify();
      return created;
    } catch (e, st) {
      debugPrint('createSeminarClass failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return null;
    }
  }

  Future<String?> enrollSeminarClass({
    required String classId,
    String? enrollorShopId,
  }) async {
    final sid = (enrollorShopId ?? shop.id).trim();
    if (sid.isEmpty) return null;
    try {
      final enrollId = await _repository.enrollSeminarClass(
        classId: classId,
        enrollorShopId: sid,
      );
      lastError = null;
      _notify();
      return enrollId;
    } catch (e, st) {
      debugPrint('enrollSeminarClass failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return null;
    }
  }

  Future<int> settleSeminarEnrollment(String enrollmentId) async {
    try {
      final net = await _repository.settleSeminarEnrollment(enrollmentId);
      shop = shop.copyWith(soriCashBalance: shop.soriCashBalance + net);
      await refreshSeminarEducationInsight();
      lastError = null;
      _notify();
      return net;
    } catch (e, st) {
      debugPrint('settleSeminarEnrollment failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return 0;
    }
  }

  /// 단골 샵 공유 케이스 (현재 샵).
  List<CommunityCaseItem> favoriteShopCaseItems() {
    final out = <CommunityCaseItem>[];
    for (final chart in charts) {
      if (chart.shopId != shop.id && chart.shopId.isNotEmpty) continue;
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      out.add(
        CommunityCaseItem(
          chart: chart.asPublicFeedProjection(),
          shop: shop,
          review: reviewForChart(chart.id)?.copyWith(customerId: ''),
          careTags: chart.careTags,
        ),
      );
    }
    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  void updateHomecareTip(String tip) {
    todayHomecareTip = tip.trim();
    _notify();
  }

  void upsertGallerySlide(ShopGallerySlide slide) {
    final index = gallerySlides.indexWhere((s) => s.id == slide.id);
    if (index >= 0) {
      gallerySlides[index] = slide;
    } else {
      gallerySlides.add(slide);
    }
    _notify();
  }

  void replaceGallerySlideAt(int index, ShopGallerySlide slide) {
    if (index < 0 || index >= gallerySlides.length) return;
    gallerySlides[index] = slide;
    _notify();
  }

  /// 관리 케이스 공개 공유 토글. 동의 서명 없는 차트는 shared=true 거부.
  /// returns false if blocked by consent defense.
  bool setManagementCaseShared(String chartId, bool shared) {
    final index = charts.indexWhere((c) => c.id == chartId);
    if (index < 0) return false;
    final chart = charts[index];
    if (shared && !chart.isConsentSigned) {
      return false;
    }
    final nextShared = chart.isConsentSigned ? shared : false;
    charts[index] = chart.copyWith(caseShared: nextShared);
    _notify();
    if (_repository.isRemote) {
      unawaited(() async {
        try {
          await _repository.updateChartCaseShared(
            chartId: chart.id,
            shared: nextShared,
          );
        } catch (e) {
          debugPrint('setManagementCaseShared remote failed: $e');
        }
      }());
    }
    return true;
  }

  /// 차트 관리 화면 — 텍스트/사진 부분 업데이트.
  Future<CustomerChart> updateCustomerChartFields({
    required String chartId,
    String? careName,
    String? treatmentSummary,
    String? directorInsight,
    String? beforeImageUrl,
    String? afterImageUrl,
    List<String>? concernChips,
    bool clearAfterImageUrl = false,
  }) async {
    final id = chartId.trim();
    final existing = findChartById(id);
    if (existing == null) {
      throw StateError('차트를 찾을 수 없습니다.');
    }

    if (!_repository.isRemote) {
      final next = existing.copyWith(
        careName: careName ?? existing.careName,
        treatmentSummary: treatmentSummary ?? existing.treatmentSummary,
        directorInsight: directorInsight ?? existing.directorInsight,
        beforeImageUrl: beforeImageUrl ?? existing.beforeImageUrl,
        afterImageUrl: clearAfterImageUrl
            ? null
            : (afterImageUrl ?? existing.afterImageUrl),
        concernChips: concernChips ?? existing.concernChips,
        clearAfterImageUrl: clearAfterImageUrl,
      );
      _mergeChart(next);
      _notify();
      return next;
    }

    try {
      final remote = await _repository.updateCustomerChartFields(
        chartId: id,
        careName: careName,
        treatmentSummary: treatmentSummary,
        directorInsight: directorInsight,
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
        concernChips: concernChips,
        clearAfterImageUrl: clearAfterImageUrl,
      );
      _mergeChart(remote);
      lastError = null;
      _notify();
      return findChartById(id) ?? remote;
    } catch (e, st) {
      debugPrint('updateCustomerChartFields failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      rethrow;
    }
  }

  /// After 사진만 즉시 덧붙이기 (Before-only 차트 Finalize).
  Future<CustomerChart> patchChartAfterImage({
    required String chartId,
    required String afterImageUrl,
  }) {
    return updateCustomerChartFields(
      chartId: chartId,
      afterImageUrl: afterImageUrl,
    );
  }

  /// 세션 고객의 스마트 회원권 지갑 (다중 샵).
  Future<void> refreshMembershipWallet() async {
    final session = this.session;
    if (session == null || session.activeMode != UserRole.customer) {
      membershipTickets.clear();
      _notify();
      return;
    }
    try {
      final remote = await _repository.loadMembershipWallet(
        phone: session.phone,
        authUserId: session.authUserId,
      );
      if (remote.isNotEmpty) {
        membershipTickets
          ..clear()
          ..addAll(remote);
        _notify();
        return;
      }
    } catch (e) {
      debugPrint('refreshMembershipWallet remote failed: $e');
    }

    // 로컬 폴백: 현재 샵 고객 기록 + 현재 샵 메타
    final digits = normalizePhone(session.phone);
    final out = <MembershipTicket>[];
    for (final c in customers) {
      if (digits.isNotEmpty && normalizePhone(c.phone) != digits) continue;
      if (session.customerId != null &&
          c.id != session.customerId &&
          digits.isEmpty) {
        continue;
      }
      final synced = c.withSyncedMembershipMirrors();
      for (final m in synced.memberships) {
        if (m.totalVisits <= 0) continue;
        out.add(
          MembershipTicket(
            id: m.id,
            shopId: c.shopId.isNotEmpty ? c.shopId : shop.id,
            customerId: c.id,
            customerPhoneDigits: normalizePhone(c.phone),
            shopName: shop.name.trim().isEmpty ? 'SORI 샵' : shop.name,
            ticketName: m.serviceName.isEmpty ? '회원권' : m.serviceName,
            totalVisits: m.totalVisits,
            usedVisits: m.usedVisits,
            expiresAt: m.expiresAt,
            naverPlaceUrl: shop.naverPlaceUrl,
            isActive: m.remainingVisits > 0,
          ),
        );
      }
    }
    membershipTickets
      ..clear()
      ..addAll(out);
    _notify();
  }

  List<MembershipTicket> get activeMembershipWallet => membershipTickets
      .where((t) => t.totalVisits > 0)
      .toList()
    ..sort((a, b) => a.remainingVisits.compareTo(b.remainingVisits));

  /// 보호자 연락처 + 정보 열람 동의가 있는 가족 고객 목록.
  List<Customer> familyCustomersForGuardianPhone(String phone) {
    final key = normalizePhone(phone);
    if (key.isEmpty) return const [];
    final ids = <String>{};
    for (final chart in charts) {
      if (!chart.infoViewConsent) continue;
      if (normalizePhone(chart.guardianPhone ?? '') != key) continue;
      ids.add(chart.customerId);
    }
    if (ids.isEmpty) return const [];
    return customers.where((c) => ids.contains(c.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void setHomeCareMissionCheck({
    required String chartId,
    required int dayIndex,
    required bool checked,
  }) {
    if (dayIndex < 0 || dayIndex > 2) return;
    final index = charts.indexWhere((c) => c.id == chartId);
    if (index < 0) return;
    final next = CustomerChart.normalizeMissionChecks(
      charts[index].homeCareMissionChecks,
    );
    next[dayIndex] = checked;
    // 로컬 즉시 반영 (UX)
    charts[index] = charts[index].copyWith(homeCareMissionChecks: next);
    _pendingMissionChecks[chartId] = List<bool>.from(next);
    _notify();

    // 마지막 터치 후 1.5초 디바운스 → 서버 1회 통신
    _missionDebounceTimers[chartId]?.cancel();
    _missionDebounceTimers[chartId] = Timer(
      const Duration(milliseconds: 1500),
      () {
        final checks = _pendingMissionChecks.remove(chartId);
        _missionDebounceTimers.remove(chartId);
        if (checks == null || !_repository.isRemote) return;
        unawaited(() async {
          try {
            await _repository.updateHomeCareMissionChecks(
              chartId: chartId,
              checks: checks,
            );
          } catch (e) {
            debugPrint('setHomeCareMissionCheck remote failed: $e');
          }
        }());
      },
    );
  }

  /// 앱 종료/로그아웃 전 대기 중인 미션 패치를 즉시 플러시.
  Future<void> flushPendingMissionChecks() async {
    final pending = Map<String, List<bool>>.from(_pendingMissionChecks);
    for (final timer in _missionDebounceTimers.values) {
      timer.cancel();
    }
    _missionDebounceTimers.clear();
    _pendingMissionChecks.clear();
    if (!_repository.isRemote) return;
    for (final entry in pending.entries) {
      try {
        await _repository.updateHomeCareMissionChecks(
          chartId: entry.key,
          checks: entry.value,
        );
      } catch (e) {
        debugPrint('flushPendingMissionChecks failed: $e');
      }
    }
  }

  CareDiaryNote? diaryNoteFor({
    required String customerId,
    required DateTime day,
  }) {
    for (final n in diaryNotes) {
      if (n.customerId == customerId && CareDiaryNote.sameDay(n.noteDate, day)) {
        return n;
      }
    }
    return null;
  }

  Future<CareDiaryNote> saveCareDiaryNote({
    required String customerId,
    required DateTime day,
    required String body,
  }) async {
    final existing = diaryNoteFor(customerId: customerId, day: day);
    final draft = CareDiaryNote(
      id: existing?.id ?? 'diary-${DateTime.now().millisecondsSinceEpoch}',
      shopId: shop.id,
      customerId: customerId,
      noteDate: DateTime(day.year, day.month, day.day),
      body: body.trim(),
      updatedAt: DateTime.now(),
    );
    CareDiaryNote saved = draft;
    if (_repository.isRemote) {
      try {
        saved = await _repository.upsertCareDiaryNote(draft);
      } catch (e) {
        debugPrint('saveCareDiaryNote remote failed: $e');
      }
    }
    final i = diaryNotes.indexWhere(
      (n) =>
          n.customerId == customerId &&
          CareDiaryNote.sameDay(n.noteDate, day),
    );
    if (i >= 0) {
      diaryNotes[i] = saved;
    } else {
      diaryNotes.insert(0, saved);
    }
    _notify();
    return saved;
  }

  List<Customer> customersForDate(DateTime day) {
    return customers.where((c) {
      final d = c.lastTreatmentDate;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  Set<int> visitDaysInMonth(int year, int month) {
    return customers
        .where((c) =>
            c.lastTreatmentDate.year == year &&
            c.lastTreatmentDate.month == month)
        .map((c) => c.lastTreatmentDate.day)
        .toSet();
  }

  /// 해당 날짜에 작성된 케어 차트 (created_at 기준, 예약이 아님).
  List<CustomerChart> chartsCreatedOnDate(DateTime day) {
    final out = charts.where((c) {
      final d = c.createdAt;
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// 월별 차트 작성일이 있는 day 집합 (캘린더 닷 표시).
  Set<int> chartCreatedDaysInMonth(int year, int month) {
    return charts
        .where((c) {
          final d = c.createdAt;
          if (d == null) return false;
          return d.year == year && d.month == month;
        })
        .map((c) => c.createdAt!.day)
        .toSet();
  }

  void addCustomer(Customer customer) {
    customers.insert(0, customer);
    _notify();
    if (_repository.isRemote) {
      // fire-and-forget remote upsert; 스키마/네트워크 실패는 quiet log
      () async {
        try {
          final saved = await _repository.upsertCustomer(customer);
          final idx = customers.indexWhere(
            (c) => c.id == customer.id || c.phone == customer.phone,
          );
          if (idx >= 0) customers[idx] = saved;
          _notify();
        } catch (e) {
          _setError(e, userFacing: false);
          _notify();
        }
      }();
    }
  }

  Future<Customer> addCustomerAsync(Customer customer) async {
    isLoading = true;
    lastError = null;
    _notify();
    try {
      // 등록 경로: name/phone/memo/shop_id 만 DB insert
      final saved = await _repository.registerCustomer(
        shopId: customer.shopId.isNotEmpty ? customer.shopId : shop.id,
        name: customer.name,
        phone: customer.phone,
        memo: customer.memo,
      );
      _mergeCustomer(saved);
      return saved;
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// 차트 없이 고객 회원권만 저장 (CRM 퀵 액션 / 바텀 시트).
  Future<Customer> saveCustomerMemberships({
    required String customerId,
    required List<CustomerMembership> memberships,
  }) async {
    if (blocksDirectorChartWrites) {
      throw StateError('고객 모드에서는 회원권을 수정할 수 없습니다.');
    }
    final current = findCustomer(customerId);
    if (current == null) {
      throw StateError('고객을 찾을 수 없습니다.');
    }
    final updated = current
        .copyWith(memberships: memberships)
        .withSyncedMembershipMirrors();

    if (!_repository.isRemote) {
      _mergeCustomer(updated);
      _notify();
      return updated;
    }

    isLoading = true;
    lastError = null;
    _notify();
    try {
      final saved = await _repository.upsertCustomer(updated);
      _mergeCustomer(saved);
      return saved;
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// 차트 저장 + 방문 확인 트리거 → 토큰/리뷰 초안 생성.
  /// [memberships] 는 방문 확인 직전 회원권 설정값이며,
  /// 아직 방문 미확인 차트인 경우 확인 시 careName과 매칭되는 회원권만 차감됩니다.
  CustomerChart saveChartAndConfirmVisit({
    required String customerId,
    required int visitNumber,
    String? customChartNo,
    String? chartId,
    required String careName,
    required String treatmentSummary,
    required String directorInsight,
    required List<String> concernChips,
    required List<String> firstVisitFearChips,
    required List<String> revisitFeedbackChips,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? customerName,
    String? customerPhone,
    CustomerGender? gender,
    DateTime? birthDate,
    String? address,
    String? occupation,
    String? allergyNotes,
    String? skinSensitivity,
    String? sideEffectHistory,
    List<CustomerMembership>? memberships,
    String? customerRequests,
    String? membershipServiceName,
    int? membershipTotalVisits,
    int? membershipUsedVisits,
    bool consentMandatory = false,
    bool consentPhoto = false,
    bool consentMarketing = false,
    bool consentOfflineOnly = false,
    String? signatureUrl,
    List<String> homeCarePrescriptions = const [],
    String? guardianPhone,
    bool infoViewConsent = false,
  }) {
    if (blocksDirectorChartWrites) {
      throw StateError('고객 모드에서는 원장 차트를 저장할 수 없습니다.');
    }
    final customer = findCustomer(customerId);
    if (customer == null) {
      throw StateError('Customer not found');
    }

    final wasAlreadyChecked = chartId != null &&
        charts.any((c) => c.id == chartId && c.visitChecked);

    final beforeUrl = DbMap.asTextOrNull(beforeImageUrl);
    final afterUrl = DbMap.asTextOrNull(afterImageUrl);
    final sigUrl = DbMap.asTextOrNull(signatureUrl);
    final prescriptions =
        HomecareDictionary.sanitizeTagIds(homeCarePrescriptions);
    final guardianDigits = normalizePhone(guardianPhone ?? '');
    final guardian = guardianDigits.isEmpty ? null : guardianDigits;

    // 고객 전화번호도 숫자만 저장
    final normalizedCustomerPhone = customerPhone == null
        ? null
        : normalizePhone(customerPhone);

    CustomerChart chart;
    if (chartId != null) {
      final index = charts.indexWhere((c) => c.id == chartId);
      if (index < 0) throw StateError('Chart not found');
      chart = charts[index].copyWith(
        visitNumber: visitNumber < 1 ? 1 : visitNumber,
        customChartNo: customChartNo,
        careName: careName.trim(),
        treatmentSummary: treatmentSummary.trim(),
        directorInsight: directorInsight.trim(),
        allergyNotes: DbMap.asText(allergyNotes),
        skinSensitivity: DbMap.asText(skinSensitivity),
        sideEffectHistory: DbMap.asText(sideEffectHistory),
        customerRequests: DbMap.asText(customerRequests),
        concernChips: DbMap.sanitizeStringList(concernChips),
        firstVisitFearChips: DbMap.sanitizeStringList(firstVisitFearChips),
        revisitFeedbackChips: DbMap.sanitizeStringList(revisitFeedbackChips),
        beforeImageUrl: beforeUrl,
        afterImageUrl: afterUrl,
        clearBeforeImageUrl: beforeUrl == null,
        clearAfterImageUrl: afterUrl == null,
        clearCustomChartNo:
            customChartNo == null || customChartNo.trim().isEmpty,
        consentMandatory: consentMandatory,
        consentPhoto: consentPhoto,
        consentMarketing: consentMarketing,
        consentOfflineOnly: consentOfflineOnly,
        signatureUrl: sigUrl ?? charts[index].signatureUrl,
        homeCarePrescriptions: prescriptions,
        guardianPhone: guardian,
        clearGuardianPhone: guardian == null,
        infoViewConsent: infoViewConsent,
      );
      charts[index] = chart;
    } else {
      chart = CustomerChart(
        id: 'chart-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shop.id,
        customerId: customerId,
        visitNumber: visitNumber < 1 ? 1 : visitNumber,
        customChartNo: customChartNo?.trim().isEmpty == true
            ? null
            : customChartNo?.trim(),
        careName: careName.trim(),
        treatmentSummary: treatmentSummary.trim(),
        directorInsight: directorInsight.trim(),
        allergyNotes: DbMap.asText(allergyNotes),
        skinSensitivity: DbMap.asText(skinSensitivity),
        sideEffectHistory: DbMap.asText(sideEffectHistory),
        customerRequests: DbMap.asText(customerRequests),
        concernChips: DbMap.sanitizeStringList(concernChips),
        firstVisitFearChips: DbMap.sanitizeStringList(firstVisitFearChips),
        revisitFeedbackChips: DbMap.sanitizeStringList(revisitFeedbackChips),
        beforeImageUrl: beforeUrl,
        afterImageUrl: afterUrl,
        consentMandatory: consentMandatory,
        consentPhoto: consentPhoto,
        consentMarketing: consentMarketing,
        consentOfflineOnly: consentOfflineOnly,
        signatureUrl: sigUrl,
        homeCarePrescriptions: prescriptions,
        guardianPhone: guardian,
        infoViewConsent: infoViewConsent,
      );
      charts.insert(0, chart);
    }

    final custIndex = customers.indexWhere((c) => c.id == customerId);
    Customer updatedCustomer;
    if (memberships != null) {
      updatedCustomer = customers[custIndex]
          .copyWith(memberships: memberships)
          .withSyncedMembershipMirrors();
    } else {
      final total = (membershipTotalVisits ?? customer.membershipTotalVisits)
          .clamp(0, 999);
      var used = (membershipUsedVisits ?? customer.membershipUsedVisits)
          .clamp(0, 999);
      if (total > 0 && used > total) used = total;
      updatedCustomer = customers[custIndex]
          .copyWith(
            membershipServiceName:
                membershipServiceName ?? customer.membershipServiceName,
            membershipTotalVisits: total,
            membershipUsedVisits: used,
          )
          .withSyncedMembershipMirrors();
    }

    // 고객 마스터: 인적/회원권만 갱신 (알레르기·부작용은 차트에만 저장)
    customers[custIndex] = updatedCustomer.copyWith(
      name: customerName?.trim().isNotEmpty == true
          ? customerName!.trim()
          : customer.name,
      phone: (normalizedCustomerPhone != null &&
              normalizedCustomerPhone.isNotEmpty)
          ? normalizedCustomerPhone
          : customer.phone,
      gender: gender,
      birthDate: birthDate,
      address: address ?? customer.address,
      occupation: occupation ?? customer.occupation,
      lastTreatmentDate: DateTime.now(),
      treatmentType: careName.isNotEmpty ? careName : customer.treatmentType,
    ).withSyncedMembershipMirrors();

    return confirmVisit(
      chartId: chart.id,
      deductMembership: !wasAlreadyChecked,
    );
  }

  CustomerChart confirmVisit({
    required String chartId,
    List<String> puzzleSelections = const [
      '피부 톤이 밝아졌어요',
      '시술 후 자극이 적었어요',
    ],
    bool deductMembership = true,
  }) {
    final index = charts.indexWhere((c) => c.id == chartId);
    if (index < 0) {
      throw StateError('Chart not found: $chartId');
    }

    final alreadyChecked = charts[index].visitChecked;
    final opened = _visitTrigger.markVisitChecked(charts[index]);
    charts[index] = opened;

    if (deductMembership && !alreadyChecked) {
      _deductMembershipVisit(opened.customerId, opened.careName);
    } else {
      lastMembershipDeducted = false;
      lastVisitFeedback = null;
    }

    if (reviewForChart(opened.id) == null) {
      final customer = findCustomer(opened.customerId);
      reviews.add(
        _visitTrigger.createDraftReview(
          chart: opened,
          puzzleSelections: puzzleSelections,
          customerName: customer?.name ?? '고객',
          treatmentType: opened.careName.isNotEmpty
              ? opened.careName
              : (customer?.treatmentType ?? '케어'),
        ),
      );
    }

    _notify();
    return opened;
  }

  /// 방문 확인 시 careName과 매칭되는 회원권 1회 차감.
  bool _deductMembershipVisit(String customerId, String careName) {
    final custIndex = customers.indexWhere((c) => c.id == customerId);
    if (custIndex < 0) {
      lastMembershipDeducted = false;
      lastVisitFeedback = null;
      return false;
    }
    final c = customers[custIndex].withSyncedMembershipMirrors();
    if (!c.isMembershipCustomer) {
      lastMembershipDeducted = false;
      lastVisitFeedback = null;
      return false;
    }

    if (careName.trim().isEmpty) {
      lastMembershipDeducted = false;
      lastVisitFeedback = '진행 서비스가 없어 회원권을 차감하지 않았습니다.';
      return false;
    }

    for (var i = 0; i < c.memberships.length; i++) {
      final m = c.memberships[i];
      if (!CustomerMembership.matchesService(m.serviceName, careName)) {
        continue;
      }
      if (m.remainingVisits <= 0) {
        lastMembershipDeducted = false;
        lastVisitFeedback = '${m.serviceName} 회원권 잔여 횟수가 없습니다.';
        return false;
      }
      final updated = m.copyWith(usedVisits: m.usedVisits + 1);
      final nextMemberships = List<CustomerMembership>.from(c.memberships)
        ..[i] = updated;
      customers[custIndex] = c
          .copyWith(memberships: nextMemberships)
          .withSyncedMembershipMirrors();
      lastMembershipDeducted = true;
      lastVisitFeedback =
          '${m.serviceName} 회원권 1회 차감 (잔여 ${updated.remainingVisits}회)';
      return true;
    }

    lastMembershipDeducted = false;
    lastVisitFeedback =
        '진행 서비스($careName)와 일치하는 회원권이 없어 차감하지 않았습니다.';
    return false;
  }

  CustomerReview acceptReview(String reviewId) {
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw StateError('Review not found');
    reviews[index] = reviews[index].copyWith(
      status: ReviewStatus.accepted,
      acceptedAt: DateTime.now(),
    );
    _notify();
    return reviews[index];
  }

  CustomerReview startEditingReview(String reviewId) {
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw StateError('Review not found');
    reviews[index] = reviews[index].copyWith(status: ReviewStatus.editing);
    _notify();
    return reviews[index];
  }

  CustomerReview togglePuzzleSentence({
    required String reviewId,
    required String sentence,
  }) {
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw StateError('Review not found');

    final review = reviews[index];
    final chart = charts.firstWhere((c) => c.id == review.chartId);
    final customer = findCustomer(review.customerId);
    final selected = List<String>.from(review.puzzleSelections);
    if (selected.contains(sentence)) {
      selected.remove(sentence);
    } else {
      selected.add(sentence);
    }

    final rebuilt = _visitTrigger.createDraftReview(
      chart: chart,
      puzzleSelections: selected,
      customerName: customer?.name ?? '고객',
      treatmentType: chart.careName.isNotEmpty
          ? chart.careName
          : (customer?.treatmentType ?? '케어'),
    );

    reviews[index] = review.copyWith(
      puzzleSelections: selected,
      originalText: rebuilt.originalText,
      editedText: rebuilt.originalText,
      status: ReviewStatus.editing,
    );
    _notify();
    return reviews[index];
  }

  CustomerReview finishPuzzleEdit(String reviewId) {
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw StateError('Review not found');
    reviews[index] = reviews[index].copyWith(
      status: ReviewStatus.accepted,
      acceptedAt: DateTime.now(),
    );
    _notify();
    return reviews[index];
  }

  Future<AiReply> requestAiReplyFeedback(String reviewId) async {
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw StateError('Review not found');

    final review = reviews[index].copyWith(
      requestAiReply: true,
      status: ReviewStatus.replyRequested,
    );
    reviews[index] = review;

    var reply = aiReplyForReview(reviewId);
    if (reply == null) {
      reply = _visitTrigger.enqueueAiReply(review: review);
      aiReplies.add(reply);
    }

    final replyIndex = aiReplies.indexWhere((r) => r.id == reply!.id);
    aiReplies[replyIndex] = reply.copyWith(status: AiReplyStatus.generating);
    _notify();

    await Future<void>.delayed(const Duration(milliseconds: 900));

    final customer = findCustomer(review.customerId);
    final completed = _visitTrigger.completeAiReply(
      aiReplies[replyIndex],
      customerName: customer?.name ?? '고객',
    );
    aiReplies[replyIndex] = completed;
    _notify();
    return completed;
  }

  AiReply markAiReplyCopied(String replyId) {
    final index = aiReplies.indexWhere((r) => r.id == replyId);
    if (index < 0) throw StateError('AI reply not found');
    aiReplies[index] = _visitTrigger.markCopied(aiReplies[index]);
    _notify();
    return aiReplies[index];
  }

  void saveToSkinJournal(String text) {
    skinJournalEntries.insert(0, text);
    _notify();
  }
}

/// 원장 리뷰 인박스 조인 뷰모델.
class DirectorReviewInboxItem {
  const DirectorReviewInboxItem({
    required this.review,
    this.customer,
    this.chart,
  });

  final CustomerReview review;
  final Customer? customer;
  final CustomerChart? chart;

  String get displayName {
    final n = customer?.name.trim() ?? '';
    return n.isEmpty ? '고객' : n;
  }

  String get careName {
    final c = chart?.careName.trim() ?? '';
    if (c.isNotEmpty) return c;
    final t = customer?.treatmentType.trim() ?? '';
    return t.isEmpty ? '케어' : t;
  }

  List<String> get bodyTags {
    final tags = <String>[];
    final chips = chart?.concernChips ?? const <String>[];
    for (final chip in chips) {
      final t = chip.trim();
      if (t.isNotEmpty) tags.add(t);
    }
    return tags;
  }

  DateTime get sortDate =>
      review.acceptedAt ??
      review.createdAt ??
      review.naverRegisteredAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  int? get age => customer?.koreanAge;

  CustomerGender? get gender => customer?.gender;

  String? get ageBand {
    final a = age;
    if (a == null) return null;
    if (a < 20) return '10대';
    if (a < 30) return '20대';
    if (a < 40) return '30대';
    if (a < 50) return '40대';
    return '50대 이상';
  }

  bool matchesBodyPart(String part) {
    final p = part.trim();
    if (p.isEmpty) return true;
    final hay = '$careName ${bodyTags.join(' ')}';
    return hay.contains(p);
  }
}
