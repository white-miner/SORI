import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../data/memory_sori_repository.dart';
import '../data/repository_factory.dart';
import '../data/sori_repository.dart';
import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_service_item.dart';
import 'sori_auth_service.dart';
import 'visit_trigger_service.dart';

/// 앱 Facade — UI는 Store, 데이터는 Repository (Memory | Supabase).
class SoriStore {
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

  void _setError(Object error) {
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
  final List<String> skinJournalEntries = [];
  final List<ShopGallerySlide> gallerySlides = [];
  final Set<String> reviewRequestedCustomerIds = {};
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

  void addListener(void Function() listener) => _listeners.add(listener);
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
      _setError(e);
      bootstrapFailed = true;
      // UI가 죽지 않도록 시드 유지하되, Retry로 원격 재연결 가능
      if (customers.isEmpty) {
        _applySnapshot(MemorySoriRepository.createSeedSnapshot());
      }
      bootstrapComplete = true;
    } finally {
      isLoading = false;
      _notify();
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
  }) async {
    if (!_repository.isRemote) {
      return saveChartAndConfirmVisit(
        customerId: customerId,
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
      );
    }

    isLoading = true;
    lastError = null;
    _notify();
    try {
      final wasAlreadyChecked = chartId != null &&
          charts.any((c) => c.id == chartId && c.visitChecked);
      final result = await _repository.saveChartAndConfirmVisit(
        SaveChartRequest(
          customerId: customerId,
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
          deductMembership: !wasAlreadyChecked,
        ),
      );
      _mergeCustomer(result.customer);
      _mergeChart(result.chart);
      if (result.review != null) _mergeReview(result.review!);
      lastVisitFeedback = result.feedbackMessage.isNotEmpty
          ? result.feedbackMessage
          : null;
      lastMembershipDeducted = result.membershipDeducted;
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
      phone.replaceAll(RegExp(r'\D'), '');

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
    String email = '',
  }) {
    session = SessionUser(
      role: UserRole.guest,
      name: name.trim(),
      phone: phone.trim(),
      provider: provider,
      authUserId: authUserId,
      email: email.trim(),
      onboardingComplete: false,
      shopSetupComplete: false,
      activeMode: UserRole.customer,
    );
    _notify();
    return session!;
  }

  /// Supabase Auth 세션 → 앱 SessionUser 동기화.
  /// 이미 온보딩 완료된 동일 유저면 유지, 아니면 guest 세션으로 온보딩 진입 준비.
  SessionUser syncFromAuthUser(User user) {
    final authId = user.id;
    final existing = session;
    if (existing != null &&
        existing.authUserId == authId &&
        existing.onboardingComplete) {
      return existing;
    }
    if (existing != null &&
        existing.onboardingComplete &&
        existing.authUserId == null) {
      // 로컬 세션만 있는 경우 auth id만 연결
      session = existing.copyWith(authUserId: authId);
      _notify();
      return session!;
    }

    final provider = SoriAuthService.providerFromUser(user);
    final name = SoriAuthService.displayNameFromUser(user);
    final phone = SoriAuthService.phoneFromUser(user);
    final email = user.email?.trim() ?? '';

    return beginSocialLogin(
      provider: provider,
      name: name,
      phone: phone,
      authUserId: authId,
      email: email,
    );
  }

  /// 로그인 성공 후 shops/customers 판별로 원장·고객 홈 세션을 구성.
  Future<SessionUser> hydrateSessionFromAuth(User user) async {
    syncFromAuthUser(user);
    if (session == null) {
      throw StateError('No session after syncFromAuthUser');
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
    String? address,
    String? phone,
    String? operatingHours,
    String? snsBlogUrl,
    String? snsInstagramUrl,
    List<ShopServiceItem>? serviceMenu,
  }) {
    shop = shop.copyWith(
      name: name.trim(),
      naverPlaceUrl: naverPlaceUrl.trim(),
      address: address?.trim(),
      phone: phone?.trim(),
      operatingHours: operatingHours?.trim(),
      snsBlogUrl: snsBlogUrl?.trim(),
      snsInstagramUrl: snsInstagramUrl?.trim(),
      serviceMenu: serviceMenu,
    );
    _notify();
    if (_repository.isRemote) {
      () async {
        try {
          shop = await _repository.upsertShop(shop);
          _notify();
        } catch (e) {
          _setError(e);
          _notify();
        }
      }();
    }
  }

  List<Customer> searchCustomers(String query) {
    if (query.trim().isEmpty) return List.of(customers);
    final q = query.trim().toLowerCase();
    final digits = normalizePhone(query);
    return customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (digits.isNotEmpty && normalizePhone(c.phone).contains(digits));
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

  CustomerChart? latestChart(String customerId) {
    final list = chartsForCustomer(customerId);
    return list.isEmpty ? null : list.first;
  }

  int nextVisitNumber(String customerId) {
    final list = chartsForCustomer(customerId);
    if (list.isEmpty) return 1;
    return list.first.visitNumber + 1;
  }

  CustomerReview? reviewForChart(String chartId) {
    try {
      return reviews.firstWhere((r) => r.chartId == chartId);
    } catch (_) {
      return null;
    }
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

    _setError(lastFailure ?? StateError('naver_registered sync failed'));
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

  void addCustomer(Customer customer) {
    customers.insert(0, customer);
    _notify();
    if (_repository.isRemote) {
      // fire-and-forget remote upsert; errors surface via lastError
      () async {
        try {
          final saved = await _repository.upsertCustomer(customer);
          final idx = customers.indexWhere(
            (c) => c.id == customer.id || c.phone == customer.phone,
          );
          if (idx >= 0) customers[idx] = saved;
          _notify();
        } catch (e) {
          _setError(e);
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
  }) {
    final customer = findCustomer(customerId);
    if (customer == null) {
      throw StateError('Customer not found');
    }

    final wasAlreadyChecked = chartId != null &&
        charts.any((c) => c.id == chartId && c.visitChecked);

    CustomerChart chart;
    if (chartId != null) {
      final index = charts.indexWhere((c) => c.id == chartId);
      if (index < 0) throw StateError('Chart not found');
      chart = charts[index].copyWith(
        visitNumber: visitNumber,
        customChartNo: customChartNo,
        careName: careName,
        treatmentSummary: treatmentSummary,
        directorInsight: directorInsight,
        allergyNotes: allergyNotes ?? charts[index].allergyNotes,
        skinSensitivity: skinSensitivity ?? charts[index].skinSensitivity,
        sideEffectHistory:
            sideEffectHistory ?? charts[index].sideEffectHistory,
        customerRequests: customerRequests ?? charts[index].customerRequests,
        concernChips: concernChips,
        firstVisitFearChips: firstVisitFearChips,
        revisitFeedbackChips: revisitFeedbackChips,
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
        clearCustomChartNo:
            customChartNo == null || customChartNo.trim().isEmpty,
      );
      charts[index] = chart;
    } else {
      chart = CustomerChart(
        id: 'chart-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shop.id,
        customerId: customerId,
        visitNumber: visitNumber,
        customChartNo: customChartNo?.trim().isEmpty == true
            ? null
            : customChartNo?.trim(),
        careName: careName,
        treatmentSummary: treatmentSummary,
        directorInsight: directorInsight,
        allergyNotes: allergyNotes ?? '',
        skinSensitivity: skinSensitivity ?? '',
        sideEffectHistory: sideEffectHistory ?? '',
        customerRequests: customerRequests ?? '',
        concernChips: concernChips,
        firstVisitFearChips: firstVisitFearChips,
        revisitFeedbackChips: revisitFeedbackChips,
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
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
      phone: customerPhone?.trim().isNotEmpty == true
          ? customerPhone!.trim()
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
