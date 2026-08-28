import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../models/customer_merge_preview.dart';
import '../models/customer_membership.dart';
import '../services/customer_merge_service.dart';
import '../models/customer_review.dart';
import '../models/home_care_prescriptions.dart';
import '../models/kakao_alimtalk.dart';
import '../models/membership_ticket.dart';
import '../models/review_reply.dart';
import '../models/review_request_event.dart';
import '../models/session_user.dart';
import '../models/shoot_inbox_item.dart';
import '../models/shop.dart';
import '../models/shop_supporter_header.dart';
import '../models/shop_business_hours.dart';
import '../models/shop_equipment_item.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_post.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../models/affiliate_earnings.dart';
import '../models/sori_point_wallet.dart';
import '../models/point_shop.dart';
import '../models/premium_overlay.dart';
import '../models/my_boost_gift.dart';
import '../models/case_bookmark.dart';
import '../models/boost_contribution_report.dart';
import '../models/fan_supporter.dart';
import '../models/seminar_application.dart';
import '../models/seminar_class.dart';
import '../models/seminar_class_detail.dart';
import '../models/seminar_education_insight.dart';
import '../models/seminar_feedback_report.dart';
import '../models/seminar_enrollment.dart';
import '../models/shop_highlight.dart';
import '../models/shop_tier_badge.dart';
import '../models/shop_service_item.dart';
import '../models/subscription.dart';
import '../models/whisper.dart';
import '../utils/db_map.dart';
import '../utils/feed_interleave.dart';
import '../utils/korean_choseong.dart';
import 'consent_pdf_generator.dart';
import 'fan_boost_fill_service.dart';
import 'consent_pdf_storage.dart';
import 'chart_photo_compressor.dart';
import 'chart_photo_storage.dart';
import 'shop_media_storage.dart';
import 'shop_profile_storage.dart';
import 'shoot_inbox_local.dart';
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
  bool authHydrating = false;
  String? lastError;
  String? authError;

  /// PC 우측 패널에 표시할 댓글 대상 게시물 ID (null이면 대시보드 표시).
  String? activeCommentPostId;

  /// Community 탭 진입 시 선택될 세그먼트 (0=전체 … 4=세미나) — 허브「전체」내부.
  int? pendingCommunitySegment;

  /// Community 기기 리뷰 작성 시트 자동 오픈 (리뷰 콘솔 → 광장).
  bool pendingCommunityComposeDevice = false;

  /// Community 허브 탭: 0 전체 · 1 팔로잉 · 2 탐색.
  int? pendingCommunityHubTab;

  /// 원장 「고객」허브 세그먼트: 0 고객 · 1 리뷰.
  int? pendingCustomerHubSegment;

  /// GNB 탭 (0=홈 … 4=마이) — 루트 오버레이에서 셸로 전환할 때.
  int? pendingAppTab;

  /// 홈 내부 탭: 0 추천 · 1 탐색 · 2 우리 지역.
  int? pendingHomeInnerTab;

  /// 마이페이지 등에서 홈 탐색으로 이동.
  void requestHomeExplore() {
    pendingAppTab = 0;
    pendingHomeInnerTab = 1;
    _notify();
  }

  /// 원장 GNB 「고객」→ 리뷰 세그먼트.
  void requestCustomerReviews() {
    pendingAppTab = 1;
    pendingCustomerHubSegment = 1;
    _notify();
  }

  void openCommentPanel(String postId) {
    activeCommentPostId = postId;
    _notify();
  }

  void closeCommentPanel() {
    activeCommentPostId = null;
    _notify();
  }

  bool get isRemoteEnabled => _repository.isRemote;
  bool get hasError => lastError != null && lastError!.isNotEmpty;

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    _notify();
  }

  void setAuthHydrating(bool value) {
    if (authHydrating == value) return;
    authHydrating = value;
    _notify();
  }

  void setAuthError(String? message) {
    final trimmed = message?.trim();
    authError = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _notify();
  }

  void clearAuthError() {
    if (authError == null) return;
    authError = null;
    _notify();
  }

  /// Supabase signedOut 등 — 원격 signOut은 호출하지 않음.
  void clearAuthSession({bool localOnly = false}) {
    debugPrint('[Auth] clearAuthSession localOnly=$localOnly');
    session = null;
    authError = null;
    authHydrating = false;
    _notify();
    if (!localOnly && SoriAuthService.instance.isAvailable) {
      unawaited(SoriAuthService.instance.signOut());
    }
  }

  /// 스키마 드리프트/백그라운드 실패 — UI 전역 빨간 배너에 올리지 않음.
  static bool isNonFatalRemoteNoise(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst204') ||
        (msg.contains('could not find the') && msg.contains('column')) ||
        msg.contains('schema cache') ||
        (msg.contains('customer_reviews') && msg.contains('customer_id')) ||
        msg.contains('postgrestexception') ||
        msg.contains('oauth state') ||
        msg.contains('state not found') ||
        (msg.contains('state') && msg.contains('expired')) ||
        msg.contains('code verifier') ||
        msg.contains('pkce');
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
  final List<ShopPost> shopPosts = [];
  final List<CommunityPost> communityPosts = [];
  bool communityPostsLoading = false;
  final Set<String> reviewRequestedCustomerIds = {};
  final List<ReviewRequestEvent> reviewRequestEvents = [];
  bool reviewRequestEventsLoading = false;
  final Set<String> followedShopIds = {};
  final Set<String> followedDirectorIds = {};
  final List<Subscription> mySubscriptions = [];
  final List<CommunityPost> followingFeedPosts = [];
  bool followingFeedLoading = false;
  DateTime? followingFeedFetchedAt;
  final List<DiscoverDirector> discoverDirectors = [];
  bool discoverDirectorsLoading = false;
  DateTime? discoverFetchedAt;
  String discoverQuery = '';
  DateTime? hubWarmedAt;
  final List<WhisperAudiencePreset> whisperPresets = [];
  WhisperAudiencePreview? whisperAudiencePreview;
  bool whisperPreviewLoading = false;
  final List<ShopHighlight> shopHighlights = [];
  int shopFollowerCount = 0;
  ShopSupporterHeader shopSupporterHeader = const ShopSupporterHeader();
  bool shopFandomMetaLoading = false;
  final List<CommunityCaseItem> communityHotCases = [];
  bool communityHotCasesLoading = false;

  /// 촬영 허브 미연결(신규) 큐.
  final List<ShootInboxItem> shootInbox = [];
  bool shootInboxLoading = false;
  SeminarEducationInsight? seminarEducationInsight;
  bool seminarEducationLoading = false;
  List<SeminarEnrollment> mySeminarEnrollments = [];
  bool mySeminarEnrollmentsLoading = false;
  final List<SeminarClass> seminarClasses = [];
  List<SeminarFeedbackReport> seminarFeedbackReports = [];
  bool seminarFeedbackReportsLoading = false;
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
    shopPosts
      ..clear()
      ..addAll(snapshot.shopPosts);
    seminarClasses
      ..clear()
      ..addAll(snapshot.seminarClasses);
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
      unawaited(refreshSeminarClasses());
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
      // Also match by chart_id when remote returns a different id.
      final byChart = reviews.indexWhere((r) => r.chartId == review.chartId);
      if (byChart >= 0 && review.chartId.isNotEmpty) {
        reviews[byChart] = review.copyWith(id: reviews[byChart].id);
      } else {
        reviews.insert(0, review);
      }
    }
    if (review.isInboxVisible &&
        review.id.isNotEmpty &&
        review.customerId.trim().isNotEmpty) {
      unawaited(
        _convertOpenReviewRequests(
          customerId: review.customerId,
          reviewId: review.id,
        ),
      );
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
    String? deviceInfo,
    bool publishToCommunity = false,
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
        deviceInfo: deviceInfo,
      );
      if (publishToCommunity) {
        await publishChartCaseToCommunity(chart);
      }
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
              deviceInfo: deviceInfo,
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
      if (publishToCommunity) {
        await publishChartCaseToCommunity(result.chart);
      }
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
    debugPrint('[Auth] hydrateSessionFromAuth start uid=${user.id}');
    syncFromAuthUser(user);
    if (session == null) {
      debugPrint('[Auth] syncFromAuthUser produced null session — creating guest');
      syncFromAuthUser(user);
    }
    if (session == null) {
      throw StateError('No session after syncFromAuthUser');
    }

    // Auth metadata → public.profiles upsert (이름/아바타)
    try {
      debugPrint('[Auth] upsertAuthProfile');
      await _repository.upsertAuthProfile(
        userId: user.id,
        name: SoriAuthService.displayNameFromUser(user),
        avatarUrl: SoriAuthService.avatarUrlFromUser(user),
        phone: SoriAuthService.phoneFromUser(user),
      );
    } catch (e) {
      debugPrint('[Auth] upsertAuthProfile skipped: $e');
    }

    if (session!.onboardingComplete) {
      debugPrint('[Auth] session already onboarded');
      return session!;
    }

    try {
      debugPrint('[Auth] resolveAuthRole');
      final resolved = await _repository.resolveAuthRole(user.id);
      debugPrint(
        '[Auth] resolveAuthRole director=${resolved.isDirector} '
        'customer=${resolved.isCustomer}',
      );
      if (resolved.isDirector && resolved.shop != null) {
        shop = resolved.shop!;
        shopRegisteredByUser = true;
        // 소유 샵 기준으로 데이터 재로드
        if (_repository.isRemote) {
          try {
            debugPrint('[Auth] reload initial data for director');
            final snapshot = await _repository.loadInitialData();
            _applySnapshot(snapshot);
            shop = resolved.shop!;
          } catch (e) {
            debugPrint('[Auth] hydrate reload after director resolve: $e');
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
        debugPrint('[Auth] director session ready shopId=${shop.id}');
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
        debugPrint('[Auth] customer session ready customerId=${c.id}');
        return session!;
      }
    } catch (e, st) {
      debugPrint('[Auth] hydrateSessionFromAuth resolve failed: $e\n$st');
    }

    debugPrint('[Auth] hydrate complete — onboarding required');
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

  void toggleActiveMode({bool force = false}) {
    if (session == null) return;
    if (!force && !session!.canToggleMode) return;
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
    debugPrint('[Auth] logout requested');
    clearAuthSession();
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
    ShopBusinessHours? businessHours,
    String? snsBlogUrl,
    String? snsInstagramUrl,
    String? bio,
    String? profileImageUrl,
    String? coverImageUrl,
    List<ShopServiceItem>? serviceMenu,
    List<ShopEquipmentItem>? equipmentItems,
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
      businessHours: businessHours,
      snsBlogUrl: snsBlogUrl?.trim(),
      snsInstagramUrl: snsInstagramUrl?.trim(),
      bio: bio?.trim(),
      profileImageUrl: profileImageUrl?.trim(),
      coverImageUrl: coverImageUrl?.trim(),
      serviceMenu: serviceMenu,
      equipmentItems: equipmentItems,
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

  /// 샵 컬럼 부분 저장 — 실패 시 전체 upsert 로 재시도.
  Future<bool> _persistShopFields(Map<String, dynamic> fields) async {
    if (!_repository.isRemote) return true;
    final shopId = shop.id.trim();
    if (shopId.isEmpty) return false;
    try {
      await _repository.patchShopFields(shopId, fields);
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('patchShopFields failed, upsert fallback: $e');
      try {
        shop = await _repository.upsertShop(shop);
        lastError = null;
        _notify();
        return true;
      } catch (e2) {
        debugPrint('upsertShop fallback failed: $e2');
        _setError(e2, userFacing: false);
        _notify();
        return false;
      }
    }
  }

  /// 샵 프로필 아바타 업로드 → Storage → shops.profile_image_url.
  Future<bool> uploadShopProfileImage(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    final shopId = shop.id.trim().isEmpty ? 'local-shop' : shop.id.trim();
    var url = await ShopProfileStorage.uploadAvatar(
      bytes: bytes,
      shopId: shopId,
    );
    if (url == null || url.trim().isEmpty) {
      if (!_repository.isRemote) {
        url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else {
        return false;
      }
    }
    final resolved = url.trim();
    shop = shop.copyWith(profileImageUrl: resolved);
    _notify();
    return _persistShopFields({'profile_image_url': resolved});
  }

  /// Hero 간판 업로드 → shops.cover_image_url.
  Future<bool> uploadShopCoverImage(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    final shopId = shop.id.trim().isEmpty ? 'local-shop' : shop.id.trim();
    var url = await ShopMediaStorage.uploadGalleryImage(
      bytes: bytes,
      shopId: shopId,
    );
    if (url == null || url.trim().isEmpty) {
      if (!_repository.isRemote) {
        url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else {
        return false;
      }
    }
    final resolved = url.trim();
    shop = shop.copyWith(coverImageUrl: resolved);
    _notify();
    return _persistShopFields({'cover_image_url': resolved});
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
    var maxVn = 0;
    for (final c in list) {
      if (c.visitNumber > maxVn) maxVn = c.visitNumber;
    }
    return maxVn + 1;
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
  List<DirectorReviewInboxItem> directorReviewInboxItems({
    ReviewOpsLane lane = ReviewOpsLane.all,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
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
      final item = DirectorReviewInboxItem(
        review: review,
        customer: customer,
        chart: chart,
      );
      if (!_matchesReviewOpsLane(item, lane, clock)) continue;
      items.add(item);
    }
    if (lane == ReviewOpsLane.unreplied) {
      items.sort((a, b) => a.sortDate.compareTo(b.sortDate));
    }
    return items;
  }

  bool _matchesReviewOpsLane(
    DirectorReviewInboxItem item,
    ReviewOpsLane lane,
    DateTime now,
  ) {
    switch (lane) {
      case ReviewOpsLane.all:
        return true;
      case ReviewOpsLane.unreplied:
        return !item.review.hasDirectorReply;
      case ReviewOpsLane.new24h:
        final t = item.review.acceptedAt ?? item.review.createdAt;
        if (t == null) return false;
        return now.difference(t) <= const Duration(hours: 24);
    }
  }

  int get reviewUnrepliedCount =>
      directorReviewInboxItems(lane: ReviewOpsLane.unreplied).length;

  int get reviewNew24hCount =>
      directorReviewInboxItems(lane: ReviewOpsLane.new24h).length;

  /// 요청됨인데 아직 인박스 후기가 없는 고객 수.
  int get reviewRequestedPendingCount {
    final reviewedCustomers = <String>{};
    for (final r in reviews) {
      if (!r.isInboxVisible) continue;
      final id = r.customerId.trim();
      if (id.isNotEmpty) reviewedCustomers.add(id);
    }
    final pending = <String>{};
    for (final id in reviewRequestedCustomerIds) {
      if (!reviewedCustomers.contains(id)) pending.add(id);
    }
    for (final e in reviewRequestEvents) {
      if (!e.status.isOpen) continue;
      if (reviewedCustomers.contains(e.customerId)) continue;
      pending.add(e.customerId);
    }
    return pending.length;
  }

  int get reviewRemindDueCount {
    var n = 0;
    for (final e in reviewRequestEvents) {
      if (e.isDueForRemind) n++;
    }
    return n;
  }

  ReviewOpsKpi reviewOpsKpi({
    Duration window = const Duration(days: 7),
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final inbox = directorReviewInboxItems(lane: ReviewOpsLane.all);
    var weekCount = 0;
    var ratingSum = 0;
    var ratingN = 0;
    var naverN = 0;
    var replied = 0;
    for (final item in inbox) {
      final t = item.review.acceptedAt ?? item.review.createdAt;
      if (t != null && clock.difference(t) <= window) {
        weekCount++;
      }
      final stars = item.review.effectiveRating;
      if (stars >= 1) {
        ratingSum += stars;
        ratingN++;
      }
      if (item.review.naverRegistered) naverN++;
      if (item.review.hasDirectorReply) replied++;
    }
    return ReviewOpsKpi(
      unreplied: reviewUnrepliedCount,
      new24h: reviewNew24hCount,
      requestedPending: reviewRequestedPendingCount,
      weekCount: weekCount,
      avgRating: ratingN == 0 ? 0 : ratingSum / ratingN,
      naverRate: inbox.isEmpty ? 0 : naverN / inbox.length,
      replyRate: inbox.isEmpty ? 0 : replied / inbox.length,
      inboxTotal: inbox.length,
      remindDue: reviewRemindDueCount,
    );
  }

  /// 케어명별 평균 별점 (상위 [limit]).
  List<CareRatingStat> careRatingStats({int limit = 5}) {
    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final item in directorReviewInboxItems(lane: ReviewOpsLane.all)) {
      final name = item.careName.trim();
      if (name.isEmpty || name == '케어') continue;
      final stars = item.review.effectiveRating;
      if (stars < 1) continue;
      sums[name] = (sums[name] ?? 0) + stars;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final stats = <CareRatingStat>[
      for (final e in sums.entries)
        CareRatingStat(
          careName: e.key,
          avgRating: e.value / (counts[e.key] ?? 1),
          count: counts[e.key] ?? 0,
        ),
    ];
    stats.sort((a, b) {
      final c = b.avgRating.compareTo(a.avgRating);
      return c != 0 ? c : b.count.compareTo(a.count);
    });
    return stats.take(limit).toList(growable: false);
  }

  ReviewRequestEvent? latestReviewRequestFor(String customerId) {
    final id = customerId.trim();
    if (id.isEmpty) return null;
    for (final e in reviewRequestEvents) {
      if (e.customerId == id) return e;
    }
    return null;
  }

  Future<void> refreshReviewRequestEvents({bool soft = false}) async {
    if (reviewRequestEventsLoading) return;
    reviewRequestEventsLoading = true;
    if (!soft) _notify();
    try {
      final rows = await _repository.loadReviewRequestEvents(shopId: shop.id);
      reviewRequestEvents
        ..clear()
        ..addAll(rows);
      for (final e in rows) {
        if (e.status.isOpen) {
          reviewRequestedCustomerIds.add(e.customerId);
        }
      }
    } catch (e) {
      debugPrint('refreshReviewRequestEvents failed: $e');
    } finally {
      reviewRequestEventsLoading = false;
      _notify();
    }
  }

  Future<ReviewRequestEvent?> recordReviewRequest({
    required String customerId,
    String? chartId,
    String channel = 'qr',
    int remindHours = 24,
  }) async {
    final cid = customerId.trim();
    if (cid.isEmpty) return null;
    reviewRequestedCustomerIds.add(cid);
    _notify();
    try {
      final event = await _repository.insertReviewRequestEvent(
        customerId: cid,
        chartId: chartId,
        channel: channel,
        shopId: shop.id,
        remindHours: remindHours,
      );
      reviewRequestEvents.removeWhere((e) => e.id == event.id);
      reviewRequestEvents.insert(0, event);
      _notify();
      return event;
    } catch (e) {
      debugPrint('recordReviewRequest failed: $e');
      // Offline / memory-less path: keep Set flag.
      return null;
    }
  }

  Future<void> _convertOpenReviewRequests({
    required String customerId,
    required String reviewId,
  }) async {
    final cid = customerId.trim();
    final rid = reviewId.trim();
    if (cid.isEmpty || rid.isEmpty) return;
    try {
      await _repository.convertReviewRequestEvents(
        customerId: cid,
        reviewId: rid,
        shopId: shop.id,
      );
    } catch (e) {
      debugPrint('convertReviewRequestEvents failed: $e');
    }
    for (var i = 0; i < reviewRequestEvents.length; i++) {
      final e = reviewRequestEvents[i];
      if (e.customerId == cid && e.status.isOpen) {
        reviewRequestEvents[i] = e.copyWith(
          status: ReviewRequestStatus.converted,
          convertedReviewId: rid,
        );
      }
    }
    _notify();
  }

  Future<void> acknowledgeReviewRemind(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return;
    await _repository.markReviewRequestReminded(id);
    for (var i = 0; i < reviewRequestEvents.length; i++) {
      if (reviewRequestEvents[i].id == id) {
        reviewRequestEvents[i] = reviewRequestEvents[i].copyWith(
          remindedAt: DateTime.now(),
        );
      }
    }
    _notify();
  }

  /// 네이버 등록 플래그 토글 (ON은 원격 sync, OFF는 로컬 즉시 반영).
  Future<CustomerReview?> setNaverRegistered({
    required String chartId,
    required bool registered,
    String? composedText,
  }) async {
    if (registered) {
      return markNaverRegistered(
        chartId: chartId,
        composedText: composedText,
      );
    }
    final local = reviewForChart(chartId);
    if (local == null) return null;
    final updated = local.copyWith(
      naverRegistered: false,
      clearNaverRegisteredAt: true,
      naverPublishStatus: NaverPublishStatus.none,
    );
    _mergeReview(updated);
    _notify();
    return updated;
  }

  Future<CustomerReview?> setNaverPublishStatus({
    required String reviewId,
    required NaverPublishStatus status,
  }) async {
    final id = reviewId.trim();
    if (id.isEmpty) return null;
    final local = reviewById(id);
    final optimistic = (local ??
            CustomerReview(
              id: id,
              chartId: '',
              customerId: '',
              shopId: shop.id,
            ))
        .copyWith(
          naverPublishStatus: status,
          naverRegistered: status == NaverPublishStatus.registered ||
              status == NaverPublishStatus.confirmed,
          naverRegisteredAt: status == NaverPublishStatus.none
              ? null
              : (local?.naverRegisteredAt ?? DateTime.now()),
          clearNaverRegisteredAt: status == NaverPublishStatus.none,
        );
    if (local != null) {
      _mergeReview(optimistic);
      _notify();
    }
    try {
      final remote = await _repository.setReviewNaverPublishStatus(
        reviewId: id,
        status: status.dbValue,
      );
      if (remote != null) {
        if (local != null && remote.chartId == 'chart-local') {
          _mergeReview(optimistic);
        } else {
          _mergeReview(remote);
        }
        _notify();
        return reviewById(id) ?? remote;
      }
    } catch (e) {
      debugPrint('setNaverPublishStatus failed: $e');
    }
    return local == null ? null : reviewById(id);
  }

  /// 후기 연결 차트를 BA 포트폴리오(케이스 공유)로 승격. 동의 필수.
  Future<String?> promoteReviewToPortfolio(String reviewId) async {
    final review = reviewById(reviewId);
    if (review == null) return '후기를 찾을 수 없습니다.';
    CustomerChart? chart;
    try {
      chart = charts.firstWhere((c) => c.id == review.chartId);
    } catch (_) {
      chart = null;
    }
    if (chart == null) return '연결된 차트가 없습니다.';
    final before = chart.beforeImageUrl?.trim() ?? '';
    final after = chart.afterImageUrl?.trim() ?? '';
    if (before.isEmpty && after.isEmpty) {
      return 'BA 사진이 없어 포트폴리오에 올릴 수 없습니다.';
    }
    if (!chart.isConsentSigned && !chart.consentPhoto) {
      return '사진 활용 동의가 없어 공개할 수 없습니다.';
    }
    final ok = setManagementCaseShared(chart.id, true);
    if (!ok) return '동의 서명 없이는 공개할 수 없습니다.';
    return null;
  }

  /// 후기 요청 알림톡 (옵트인: 마케팅/연락처 있는 고객).
  Future<KakaoAlimtalkSendResult> sendReviewRequestAlimtalk({
    required String customerId,
    String? chartId,
  }) async {
    final customer = findCustomer(customerId);
    if (customer == null) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'customer_not_found',
        message: '고객을 찾을 수 없습니다.',
      );
    }
    final phone = customer.phone.trim();
    if (phone.isEmpty) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'phone_missing',
        message: '고객 연락처가 없습니다.',
      );
    }
    final chartIdTrim = (chartId ?? '').trim();
    CustomerChart? chart;
    if (chartIdTrim.isNotEmpty) {
      try {
        chart = charts.firstWhere((c) => c.id == chartIdTrim);
      } catch (_) {
        chart = latestChart(customerId);
      }
    } else {
      chart = latestChart(customerId);
    }
    final token = chart?.feedbackToken?.trim() ?? '';
    final link = token.isEmpty
        ? buildCareReportUrl(chart?.id ?? '')
        : buildCustomerReviewUrl(token);
    final name = customer.name.trim().isEmpty ? '고객' : customer.name.trim();
    final content =
        '$name님, 오늘 케어는 만족스러우셨나요? 짧은 후기를 남겨주시면 큰 힘이 됩니다.\n$link';

    final result = await sendKakaoAlimtalk(
      customerPhone: phone,
      content: content,
      templateCode: KakaoAlimtalkPricing.reviewRequestTemplate,
    );
    if (result.ok) {
      await recordReviewRequest(
        customerId: customerId,
        chartId: chart?.id,
        channel: 'alimtalk',
      );
    }
    return result;
  }

  void openCommunityDeviceReviewComposer() {
    pendingCommunitySegment = 3; // 기기 리뷰 (속삭임 탭 삽입 후)
    pendingCommunityComposeDevice = true;
    _notify();
  }

  /// 원장 Review 탭 — 고객 차트에 연결된 published 리뷰 등록/갱신.
  Future<CustomerReview?> publishShopReview({
    required String chartId,
    required String customerId,
    required String text,
    required int rating,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return null;
    final stars = rating.clamp(1, 5);
    final cid = chartId.trim();
    final customer = customerId.trim();
    if (cid.isEmpty || customer.isEmpty) return null;

    final existing = reviewForChart(cid);
    final draft = (existing ??
            CustomerReview(
              id: '',
              chartId: cid,
              customerId: customer,
              shopId: shop.id,
            ))
        .copyWith(
          originalText: body,
          editedText: body,
          status: ReviewStatus.published,
          rating: stars,
          acceptedAt: DateTime.now(),
        );

    try {
      final remote = await _repository.upsertReview(draft);
      _mergeReview(remote);
      if (remote.isInboxVisible) {
        await _convertOpenReviewRequests(
          customerId: customer,
          reviewId: remote.id,
        );
      }
      lastError = null;
      _notify();
      return remote;
    } catch (e, st) {
      debugPrint('publishShopReview failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      rethrow;
    }
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
          naverPublishStatus: NaverPublishStatus.registered,
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
          final existing = reviewForChart(chartId);
          if (existing != null && existing.id != remote.id) {
            _mergeReview(
              existing.copyWith(
                naverRegistered: true,
                naverRegisteredAt:
                    remote.naverRegisteredAt ?? DateTime.now(),
                naverPublishStatus: NaverPublishStatus.registered,
                editedText: composedText ?? existing.editedText,
                status: ReviewStatus.published,
              ),
            );
          } else {
            _mergeReview(remote);
          }
          lastError = null;
          _notify();
          return reviewForChart(chartId) ?? remote;
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
    unawaited(
      recordReviewRequest(
        customerId: customerId,
        chartId: latestChart(customerId)?.id,
        channel: 'qr',
      ),
    );
  }

  bool isReviewRequested(String customerId) {
    final id = customerId.trim();
    if (id.isEmpty) return false;
    if (reviewRequestedCustomerIds.contains(id)) return true;
    for (final e in reviewRequestEvents) {
      if (e.customerId == id && e.status.isOpen) return true;
    }
    return false;
  }

  bool isFollowingShop([String? shopId]) {
    final id = (shopId ?? shop.id).trim();
    return id.isNotEmpty && followedShopIds.contains(id);
  }

  bool isFollowingDirector(String? userId) {
    final id = (userId ?? '').trim();
    return id.isNotEmpty && followedDirectorIds.contains(id);
  }

  int get subscriptionCount =>
      followedShopIds.length + followedDirectorIds.length;

  void requestCommunityHubTab(int index) {
    pendingCommunityHubTab = index.clamp(0, 2);
    _notify();
  }

  /// Community 허브 첫 진입 — ForYou + subscriptions 병렬, Following/Discover idle.
  Future<void> ensureCommunityHubWarm({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        hubWarmedAt != null &&
        now.difference(hubWarmedAt!) < const Duration(minutes: 3)) {
      return;
    }
    await Future.wait([
      refreshCommunityPosts(),
      refreshMySubscriptions(),
      refreshSeminarClasses(),
      refreshDiscoverDirectors(),
      refreshFollowingFeed(soft: true),
    ]);
    hubWarmedAt = DateTime.now();
  }

  Future<void> refreshMySubscriptions() async {
    try {
      final rows = await _repository.loadMySubscriptions();
      mySubscriptions
        ..clear()
        ..addAll(rows);
      followedShopIds
        ..clear()
        ..addAll(
          rows
              .where((s) => s.targetType == SubscriptionTargetType.shop)
              .map((s) => (s.targetShopId ?? '').trim())
              .where((id) => id.isNotEmpty),
        );
      followedDirectorIds
        ..clear()
        ..addAll(
          rows
              .where((s) => s.targetType == SubscriptionTargetType.director)
              .map((s) => (s.targetUserId ?? '').trim())
              .where((id) => id.isNotEmpty),
        );
      _notify();
    } catch (e) {
      debugPrint('refreshMySubscriptions failed: $e');
    }
  }

  Future<void> refreshFollowingFeed({bool soft = false}) async {
    if (followingFeedLoading) return;
    if (soft &&
        followingFeedFetchedAt != null &&
        DateTime.now().difference(followingFeedFetchedAt!) <
            const Duration(minutes: 3) &&
        followingFeedPosts.isNotEmpty) {
      return;
    }
    followingFeedLoading = true;
    if (!soft) _notify();
    try {
      final posts = await _repository.loadFollowingFeed();
      followingFeedPosts
        ..clear()
        ..addAll(posts);
      followingFeedFetchedAt = DateTime.now();
    } catch (e) {
      debugPrint('refreshFollowingFeed failed: $e');
    } finally {
      followingFeedLoading = false;
      _notify();
    }
  }

  Future<void> refreshDiscoverDirectors({
    bool soft = false,
    String? query,
  }) async {
    if (discoverDirectorsLoading) return;
    final q = query ?? discoverQuery;
    if (soft &&
        query == null &&
        discoverFetchedAt != null &&
        DateTime.now().difference(discoverFetchedAt!) <
            const Duration(minutes: 3) &&
        discoverDirectors.isNotEmpty) {
      return;
    }
    discoverDirectorsLoading = true;
    if (!soft) _notify();
    try {
      discoverQuery = q;
      final rows = await _repository.loadDiscoverDirectors(query: q);
      discoverDirectors
        ..clear()
        ..addAll(rows);
      discoverFetchedAt = DateTime.now();
    } catch (e) {
      debugPrint('refreshDiscoverDirectors failed: $e');
    } finally {
      discoverDirectorsLoading = false;
      _notify();
    }
  }

  /// Discover CTA — optimistic shop (+ optional director) subscription.
  Future<bool> toggleDiscoverFollow(DiscoverDirector director) async {
    final shopId = director.shopId.trim();
    if (shopId.isEmpty) return false;
    final wasFollowing = followedShopIds.contains(shopId);
    final next = !wasFollowing;
    if (next) {
      followedShopIds.add(shopId);
      final uid = director.ownerUserId?.trim() ?? '';
      if (uid.isNotEmpty) followedDirectorIds.add(uid);
      shopFollowerCount += 1;
    } else {
      followedShopIds.remove(shopId);
      final uid = director.ownerUserId?.trim() ?? '';
      if (uid.isNotEmpty) followedDirectorIds.remove(uid);
      shopFollowerCount = (shopFollowerCount - 1).clamp(0, 999999);
    }
    followingFeedFetchedAt = null; // soft-invalidate
    _notify();

    try {
      await _repository.setSubscription(
        targetType: SubscriptionTargetType.shop,
        targetShopId: shopId,
        following: next,
        source: 'discover',
      );
      final directorId = director.ownerUserId?.trim() ?? '';
      if (directorId.isNotEmpty) {
        await _repository.setSubscription(
          targetType: SubscriptionTargetType.director,
          targetUserId: directorId,
          following: next,
          source: 'discover',
        );
      }
      final customerId = session?.customerId?.trim() ?? '';
      if (customerId.isNotEmpty) {
        await _repository.setShopFollow(
          shopId: shopId,
          customerId: customerId,
          following: next,
        );
      }
      unawaited(refreshFollowingFeed());
      return next;
    } catch (e) {
      debugPrint('toggleDiscoverFollow failed: $e');
      if (next) {
        followedShopIds.remove(shopId);
      } else {
        followedShopIds.add(shopId);
      }
      _notify();
      return followedShopIds.contains(shopId);
    }
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
    followingFeedFetchedAt = null;
    _notify();

    final customerId = session?.customerId?.trim() ?? '';
    unawaited(() async {
      try {
        await _repository.setSubscription(
          targetType: SubscriptionTargetType.shop,
          targetShopId: id,
          following: !wasFollowing,
          source: 'shop_page',
        );
        if (customerId.isNotEmpty) {
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
        }
        unawaited(refreshFollowingFeed());
      } catch (e) {
        debugPrint('toggleFollowShop remote failed: $e');
      }
    }());
    return followedShopIds.contains(id);
  }

  Future<void> refreshWhisperPresets() async {
    try {
      whisperPresets
        ..clear()
        ..addAll(await _repository.loadWhisperPresets());
      _notify();
    } catch (e) {
      debugPrint('refreshWhisperPresets failed: $e');
    }
  }

  Future<WhisperAudiencePreview> previewWhisperAudience(
    WhisperAudienceSpec spec,
  ) async {
    whisperPreviewLoading = true;
    _notify();
    try {
      final withShop = spec.shopId == null || spec.shopId!.isEmpty
          ? spec.copyWith(shopId: shop.id)
          : spec;
      final preview = await _repository.previewWhisperAudience(withShop);
      whisperAudiencePreview = preview;
      return preview;
    } catch (e) {
      debugPrint('previewWhisperAudience failed: $e');
      whisperAudiencePreview = const WhisperAudiencePreview(count: 0);
      return whisperAudiencePreview!;
    } finally {
      whisperPreviewLoading = false;
      _notify();
    }
  }

  Future<WhisperSendResult> sendWhisper({
    required String body,
    required WhisperAudienceSpec spec,
  }) async {
    final withShop = spec.shopId == null || spec.shopId!.isEmpty
        ? spec.copyWith(shopId: shop.id)
        : spec;
    final result = await _repository.sendWhisper(body: body, spec: withShop);
    await refreshCommunityPosts();
    return result;
  }

  Future<WhisperAudiencePreset> saveWhisperPreset({
    required String name,
    required WhisperAudienceSpec spec,
  }) async {
    final p = await _repository.saveWhisperPreset(name: name, spec: spec);
    whisperPresets.insert(0, p);
    _notify();
    return p;
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
      final boosts = await _repository.loadActiveBoostPlacements();
      final overlays = await _repository.loadActivePremiumOverlays();
      activeBoostPlacements
        ..clear()
        ..addAll(boosts);
      activePremiumOverlays
        ..clear()
        ..addAll(overlays);
      final overlayByChart = <String, PremiumOverlay>{};
      for (final o in overlays) {
        final key = o.pinKey?.trim() ?? '';
        if (key.isEmpty) continue;
        final prev = overlayByChart[key];
        if (prev == null) {
          overlayByChart[key] = o;
        } else {
          final prevRank = prev.isPlatinum ? 2 : (prev.isGold ? 1 : 0);
          final nextRank = o.isPlatinum ? 2 : (o.isGold ? 1 : 0);
          if (nextRank > prevRank ||
              (nextRank == prevRank &&
                  o.endsAt != null &&
                  (prev.endsAt == null || o.endsAt!.isAfter(prev.endsAt!)))) {
            overlayByChart[key] = o;
          }
        }
      }
      final boostByChart = <String, BoostPlacement>{};
      for (final b in boosts) {
        final key = b.chartId?.trim().isNotEmpty == true
            ? b.chartId!.trim()
            : (b.targetType == 'chart' ? b.targetId.trim() : '');
        if (key.isEmpty) continue;
        final prev = boostByChart[key];
        if (prev == null ||
            (b.endsAt != null &&
                (prev.endsAt == null || b.endsAt!.isAfter(prev.endsAt!)))) {
          boostByChart[key] = b;
        }
      }

      final fanChartIds = boostByChart.entries
          .where((e) => e.value.isFanBoost)
          .map((e) => e.key)
          .toList();
      Map<String, List<FanSupporterEntry>> supportersByChart = const {};
      if (fanChartIds.isNotEmpty) {
        try {
          supportersByChart = await _repository.loadFanBoostSupportersBatch(
            targetIds: fanChartIds,
            targetType: 'chart',
          );
        } catch (e, st) {
          debugPrint('fan supporters batch failed: $e\n$st');
        }
      }

      final annotated = items
          .map((item) {
            final b = boostByChart[item.chart.id];
            final ov = overlayByChart[item.chart.id];
            if (b == null && ov == null) return item;
            final supporters = supportersByChart[item.chart.id] ??
                (b != null &&
                        b.isFanBoost &&
                        b.fanDisplayName.trim().isNotEmpty
                    ? [
                        FanSupporterEntry(
                          name: b.fanDisplayName.trim(),
                          echoSpent: b.pointsSpent,
                          customerId: b.paidByCustomerId,
                          walletId: b.paidByWalletId,
                        ),
                      ]
                    : const <FanSupporterEntry>[]);
            final lead = supporters.isNotEmpty
                ? supporters.first.name
                : (b?.fanDisplayName ?? ov?.fanDisplayName ?? '');
            return item.copyWith(
              isBoosted: b != null || ov != null,
              boostEndsAt: b?.endsAt ?? ov?.endsAt,
              boostSource: b?.source ?? (ov != null ? 'fan_boost' : 'shop_ad'),
              fanDisplayName: lead,
              fanSupporters: supporters,
              premiumTier: ov?.tier ?? '',
              specialSupporterName: ov?.fanDisplayName ?? '',
            );
          })
          .toList();
      communityHotCases
        ..clear()
        ..addAll(annotated);
      // 단골 샵 리뷰 미러도 보강
      for (final item in annotated) {
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

  /// 우리 지역 탭 — 4:1 Interleave (pin-all 폐기).
  List<CommunityCaseItem> interleavedCaseFeed({String? viewerId}) {
    final base = communityHotCases.isNotEmpty
        ? List<CommunityCaseItem>.from(communityHotCases)
        : favoriteShopCaseItems();
    return _interleaveCases(base, viewerId: viewerId);
  }

  /// @Deprecated 호환 — pin-all 대신 interleave.
  List<CommunityCaseItem> localBoostPinnedFeed({String? viewerId}) =>
      interleavedCaseFeed(viewerId: viewerId);

  List<CommunityCaseItem> _interleaveCases(
    List<CommunityCaseItem> base, {
    String? viewerId,
  }) {
    if (base.isEmpty) return const [];
    final now = DateTime.now();
    final fandomBy = <String, int>{};
    for (final b in activeBoostPlacements) {
      if (!b.isFanBoost) continue;
      final key = b.pinKey ?? b.targetId;
      fandomBy[key] = (fandomBy[key] ?? 0) + b.pointsSpent;
    }

    final byId = {for (final item in base) item.chart.id: item};
    final candidates = <BoostScoreInput>[];
    for (final b in activeBoostPlacements) {
      if (!b.isActive) continue;
      if (b.targetType != 'chart') continue;
      final id = b.pinKey ?? b.targetId;
      if (!byId.containsKey(id)) continue;
      candidates.add(
        BoostScoreInput(
          targetId: id,
          placementId: b.id,
          fandomEcho: fandomBy[id] ??
              (b.isFanBoost ? b.pointsSpent : 0),
          paidRatio: b.isFanBoost ? 0.85 : 0.55,
          startsAt: b.startsAt,
          isFanBoost: b.isFanBoost,
          pointsSpent: b.pointsSpent,
        ),
      );
    }

    final seed = feedViewerSeed(
      viewerId: viewerId ?? session?.id ?? 'anon',
      segment: FeedSegment.caseFeed,
      now: now,
    );
    final slots = boostSlotsForPage(math.max(base.length, 20));
    final picked = pickBoostSlots(
      candidates: candidates,
      slotCount: slots,
      viewerSeed: seed,
      now: now,
    );
    final boosted = <CommunityCaseItem>[];
    for (final p in picked) {
      final item = byId[p.targetId];
      if (item == null) continue;
      boosted.add(
        item.isBoosted
            ? item
            : item.copyWith(
                isBoosted: true,
                boostSource: p.isFanBoost ? 'fan_boost' : 'shop_ad',
              ),
      );
    }

    return interleaveFeed<CommunityCaseItem>(
      organic: base,
      boosted: boosted,
      idOf: (e) => e.chart.id,
    );
  }

  /// Community 탭 — 세그먼트 격리 4:1 Interleave.
  List<CommunityPost> interleavedCommunityPosts(
    CommunityPostType type, {
    String? viewerId,
  }) {
    final organic = communityPosts
        .where((p) => p.postType == type && !p.isWhisper)
        .toList();
    if (organic.isEmpty) return organic;

    final segment = type == CommunityPostType.interior
        ? FeedSegment.interior
        : type == CommunityPostType.deviceReview
            ? FeedSegment.deviceReview
            : FeedSegment.caseFeed;

    final byId = {for (final p in organic) p.id: p};
    final now = DateTime.now();
    final candidates = <BoostScoreInput>[];
    for (final b in activeBoostPlacements) {
      if (!b.isActive) continue;
      if (b.targetType != 'community_post') continue;
      if (!byId.containsKey(b.targetId)) continue;
      // regionCode may carry segment hint in memory tests
      final hint = FeedSegment.fromDb(b.regionCode);
      if (segment != FeedSegment.caseFeed &&
          b.regionCode.trim().isNotEmpty &&
          hint != segment) {
        continue;
      }
      candidates.add(
        BoostScoreInput(
          targetId: b.targetId,
          placementId: b.id,
          fandomEcho: b.isFanBoost ? b.pointsSpent : 0,
          paidRatio: b.isFanBoost ? 0.85 : 0.55,
          startsAt: b.startsAt,
          isFanBoost: b.isFanBoost,
          pointsSpent: b.pointsSpent,
        ),
      );
    }

    final seed = feedViewerSeed(
      viewerId: viewerId ?? session?.id ?? 'anon',
      segment: segment,
      now: now,
    );
    final picked = pickBoostSlots(
      candidates: candidates,
      slotCount: boostSlotsForPage(math.max(organic.length, 20)),
      viewerSeed: seed,
      now: now,
    );
    final boosted = [
      for (final p in picked)
        if (byId[p.targetId] != null) byId[p.targetId]!,
    ];

    return interleaveFeed<CommunityPost>(
      organic: organic,
      boosted: boosted,
      idOf: (e) => e.id,
    );
  }

  List<PointShopItem> pointShopBoosters = List.from(
    PointShopItem.catalogBoosters,
  );
  List<PointShopItem> supporterGiftItems = List.from(
    PointShopItem.catalogSpecialGifts,
  );
  List<BoostPlacement> activeBoostPlacements = [];
  List<PremiumOverlay> activePremiumOverlays = [];

  Future<void> refreshPointShopItems() async {
    try {
      pointShopBoosters = await _repository.loadPointShopItems(
        category: 'booster',
      );
      if (pointShopBoosters.isEmpty) {
        pointShopBoosters = List.from(PointShopItem.catalogBoosters);
      }
      supporterGiftItems = await _repository.loadPointShopItems(
        category: 'supporter_gift',
      );
      if (supporterGiftItems.isEmpty) {
        supporterGiftItems = List.from(PointShopItem.catalogSpecialGifts);
      }
      _notify();
    } catch (e, st) {
      debugPrint('refreshPointShopItems failed: $e\n$st');
    }
  }

  /// 부스터 구매. 잔액 부족 시 insufficient 플래그 결과 반환 (예외 X).
  Future<BoostPurchaseResult> purchaseBoostForChart({
    required String chartId,
    required String sku,
  }) async {
    final sid = shop.id.trim();
    if (sid.isEmpty || chartId.trim().isEmpty) {
      return const BoostPurchaseResult(ok: false, message: 'shop/chart required');
    }
    try {
      final result = await _repository.purchasePointShopItem(
        shopId: sid,
        sku: sku,
        targetType: 'chart',
        targetId: chartId.trim(),
      );
      if (result.ok) {
        await refreshPointWallet();
        await refreshCommunityHotCases();
      } else if (result.insufficient) {
        await refreshPointWallet();
      }
      return result;
    } catch (e, st) {
      debugPrint('purchaseBoostForChart failed: $e\n$st');
      final msg = e.toString();
      if (msg.contains('insufficient points')) {
        final haveMatch = RegExp(r'have (\d+)').firstMatch(msg);
        final needMatch = RegExp(r'need (\d+)').firstMatch(msg);
        await refreshPointWallet();
        return BoostPurchaseResult.insufficientPoints(
          have: int.tryParse(haveMatch?.group(1) ?? '') ?? pointWallet.pointTotal,
          need: int.tryParse(needMatch?.group(1) ?? '') ?? 0,
        );
      }
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  SoriPointWallet customerEchoWallet = SoriPointWallet.empty;
  List<Map<String, dynamic>> shopNotifications = [];
  List<SupporterNotificationItem> supporterNotifications = [];
  List<MyBoostGiftItem> myBoostGifts = [];
  List<BoostGiftImpactReport> boostGiftImpactReports = [];
  ShopSponsorshipImpact shopSponsorshipImpact = ShopSponsorshipImpact.empty;
  Set<String> bookmarkedChartIds = {};

  Future<SoriPointWallet> refreshCustomerEchoWallet() async {
    final cid = session?.customerId?.trim() ?? '';
    if (cid.isEmpty) return customerEchoWallet;
    try {
      customerEchoWallet = await _repository.loadCustomerEchoWallet(cid);
      _notify();
      return customerEchoWallet;
    } catch (e, st) {
      debugPrint('refreshCustomerEchoWallet failed: $e\n$st');
      return customerEchoWallet;
    }
  }

  Future<SoriPointWallet?> purchaseCustomerEchoPack({
    required int amount,
    required String sku,
  }) async {
    final cid = session?.customerId?.trim() ?? '';
    if (cid.isEmpty) return null;
    try {
      final w = await _repository.purchaseCustomerEcho(
        customerId: cid,
        amount: amount,
        sku: sku,
        orderRef: 'stub-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (w != null) {
        customerEchoWallet = w;
        await refreshCustomerEchoWallet();
      }
      return w;
    } catch (e, st) {
      debugPrint('purchaseCustomerEchoPack failed: $e\n$st');
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  /// Fan-Boost — 고객 모드 전용.
  Future<BoostPurchaseResult> purchaseFanBoostForChart({
    required String chartId,
    required String sku,
    required String targetShopId,
  }) async {
    final cid = session?.customerId?.trim() ?? '';
    if (cid.isEmpty || chartId.trim().isEmpty) {
      return const BoostPurchaseResult(
        ok: false,
        message: 'customer/chart required',
      );
    }
    final fanName = (session?.name ?? '').trim();
    if (fanName.isEmpty) {
      return const BoostPurchaseResult(
        ok: false,
        message: '후원자 닉네임이 필요합니다. 프로필에서 이름을 설정해 주세요.',
      );
    }
    try {
      final result = await _repository.purchaseFanBoost(
        customerId: cid,
        sku: sku,
        targetType: 'chart',
        targetId: chartId.trim(),
        targetShopId: targetShopId,
        fanDisplayName: fanName,
      );
      if (result.ok) {
        await refreshCustomerEchoWallet();
        await refreshCommunityHotCases();
        await refreshShopNotifications();
        await refreshShopSupporterHeader();
        // Best-effort OpenAI upgrade (sync fill already applied in RPC).
        final raw = result.raw;
        if (raw != null &&
            FanBoostFillService.edgeQueuedFromPurchase(raw)) {
          await FanBoostFillService.tryEdgeUpgrade(
            chartId: chartId.trim(),
            jobId: FanBoostFillService.jobIdFromPurchase(raw) ?? '',
          );
          await refreshCommunityHotCases();
        }
      } else if (result.insufficient) {
        await refreshCustomerEchoWallet();
      }
      return result;
    } catch (e, st) {
      debugPrint('purchaseFanBoostForChart failed: $e\n$st');
      final msg = e.toString();
      if (msg.contains('insufficient points')) {
        final haveMatch = RegExp(r'have (\d+)').firstMatch(msg);
        final needMatch = RegExp(r'need (\d+)').firstMatch(msg);
        await refreshCustomerEchoWallet();
        return BoostPurchaseResult.insufficientPoints(
          have: int.tryParse(haveMatch?.group(1) ?? '') ??
              customerEchoWallet.pointTotal,
          need: int.tryParse(needMatch?.group(1) ?? '') ?? 0,
        );
      }
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  /// VIP 스페셜 후원 — overlay 스택 (기존 부스트 유지).
  Future<BoostPurchaseResult> purchaseSpecialSupporterForChart({
    required String chartId,
    required String sku,
    required String targetShopId,
  }) async {
    final cid = session?.customerId?.trim() ?? '';
    if (cid.isEmpty || chartId.trim().isEmpty) {
      return const BoostPurchaseResult(
        ok: false,
        message: 'customer/chart required',
      );
    }
    final fanName = (session?.name ?? '').trim();
    if (fanName.isEmpty) {
      return const BoostPurchaseResult(
        ok: false,
        message: '후원자 닉네임이 필요합니다. 프로필에서 이름을 설정해 주세요.',
      );
    }
    try {
      final result = await _repository.purchaseSpecialSupporterGift(
        customerId: cid,
        sku: sku,
        targetType: 'chart',
        targetId: chartId.trim(),
        targetShopId: targetShopId,
        fanDisplayName: fanName,
      );
      if (result.ok) {
        await refreshCustomerEchoWallet();
        await refreshCommunityHotCases();
        await refreshShopNotifications();
        await refreshShopSupporterHeader();
      } else if (result.insufficient) {
        await refreshCustomerEchoWallet();
      }
      return result;
    } catch (e, st) {
      debugPrint('purchaseSpecialSupporterForChart failed: $e\n$st');
      final msg = e.toString();
      if (msg.contains('insufficient points')) {
        return BoostPurchaseResult.insufficientPoints(have: 0, need: 0);
      }
      return BoostPurchaseResult(ok: false, message: msg);
    }
  }

  Future<void> refreshShopSupporterHeader() async {
    final sid = shop.id.trim();
    if (sid.isEmpty) return;
    try {
      shopSupporterHeader = await _repository.loadShopSupporterHeader(sid);
      _notify();
    } catch (e, st) {
      debugPrint('refreshShopSupporterHeader failed: $e\n$st');
    }
  }

  Future<void> refreshShopNotifications() async {
    final sid = shop.id.trim();
    if (sid.isEmpty) return;
    try {
      shopNotifications =
          await _repository.loadShopNotifications(sid, limit: 20);
      supporterNotifications =
          await _repository.loadSupporterNotifications(sid, limit: 30);
      _notify();
    } catch (e, st) {
      debugPrint('refreshShopNotifications failed: $e\n$st');
    }
  }

  Future<void> refreshMyBoostGifts() async {
    final cid = session?.customerId?.trim() ?? '';
    if (cid.isEmpty) return;
    try {
      boostGiftImpactReports =
          await _repository.loadBoostGiftImpactReports(cid, limit: 50);
      myBoostGifts = boostGiftImpactReports;
      _notify();
    } catch (e, st) {
      debugPrint('refreshMyBoostGifts failed: $e\n$st');
    }
  }

  Future<void> refreshShopSponsorshipImpact({int periodDays = 30}) async {
    final sid = shop.id.trim();
    if (sid.isEmpty) return;
    try {
      shopSponsorshipImpact = await _repository.loadShopSponsorshipImpact(
        sid,
        periodDays: periodDays,
      );
      _notify();
    } catch (e, st) {
      debugPrint('refreshShopSponsorshipImpact failed: $e\n$st');
    }
  }

  Future<WhisperSendResult?> sendThankYouWhisperForGift({
    required String fanGiftId,
    String body = '',
  }) async {
    final id = fanGiftId.trim();
    if (id.isEmpty) return null;
    try {
      final result = await _repository.sendThankYouWhisper(
        fanGiftId: id,
        body: body,
      );
      await refreshSupporterNotificationsOnly();
      await refreshCommunityPosts();
      return result;
    } catch (e, st) {
      debugPrint('sendThankYouWhisperForGift failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> refreshSupporterNotificationsOnly() async {
    final sid = shop.id.trim();
    if (sid.isEmpty) return;
    try {
      supporterNotifications =
          await _repository.loadSupporterNotifications(sid, limit: 30);
      _notify();
    } catch (e, st) {
      debugPrint('refreshSupporterNotificationsOnly failed: $e\n$st');
    }
  }

  bool isChartBookmarked(String chartId) =>
      bookmarkedChartIds.contains(chartId.trim());

  Future<void> refreshCaseBookmarks() async {
    final uid = session?.id.trim() ?? '';
    if (uid.isEmpty) {
      bookmarkedChartIds = {};
      _notify();
      return;
    }
    try {
      final rows = await _repository.loadMyCaseBookmarks(limit: 300);
      bookmarkedChartIds = rows.map((e) => e.chartId.trim()).toSet();
      _notify();
    } catch (e, st) {
      debugPrint('refreshCaseBookmarks failed: $e\n$st');
    }
  }

  Future<bool> toggleCaseBookmark(String chartId) async {
    final id = chartId.trim();
    if (id.isEmpty) return isChartBookmarked(id);
    final uid = session?.id.trim() ?? '';
    if (uid.isEmpty) return false;
    try {
      final result = await _repository.toggleCaseBookmark(id);
      if (!result.ok) return isChartBookmarked(id);
      if (result.bookmarked) {
        bookmarkedChartIds.add(id);
      } else {
        bookmarkedChartIds.remove(id);
      }
      _notify();
      return result.bookmarked;
    } catch (e, st) {
      debugPrint('toggleCaseBookmark failed: $e\n$st');
      rethrow;
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
    String? requestorShopId,
    String? requestorUserId,
    String? caseOwnerShopId,
  }) async {
    try {
      final count = await _repository.insertSeminarRequest(
        caseId: caseId,
        requestorShopId: requestorShopId,
        requestorUserId: requestorUserId,
      );
      lastError = null;
      final owner = caseOwnerShopId?.trim() ?? '';
      if (owner.isNotEmpty && owner == shop.id.trim() && count > 0) {
        shop = shop.copyWith(seminarRequestCount: count);
        final insight = seminarEducationInsight;
        if (insight != null) {
          final byCase = Map<String, int>.from(insight.requestsByCase);
          byCase[caseId.trim()] = (byCase[caseId.trim()] ?? 0) + 1;
          seminarEducationInsight = SeminarEducationInsight(
            totalRequests: count,
            requestsByCase: byCase,
            soriCashBalance: insight.soriCashBalance,
            tierBadgeLabel: insight.tierBadgeLabel,
            totalSeminarCount: insight.totalSeminarCount,
            totalFundingAmount: insight.totalFundingAmount,
            totalLikes: insight.totalLikes,
            sharedCaseCount: insight.sharedCaseCount,
            seminarRequestCount: count,
            completedSeminarCount: insight.completedSeminarCount,
            followerCount: insight.followerCount,
          );
        }
      }
      // 사이드바 실시간 반영을 위해 내 인사이트 재조회
      if (owner.isEmpty || owner == shop.id.trim()) {
        seminarEducationLoading = false;
        await refreshSeminarEducationInsight();
      }
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
          totalSeminarCount: insight.totalSeminarCount > 0
              ? insight.totalSeminarCount
              : shop.totalSeminarCount,
          totalFundingAmount: insight.totalFundingAmount > 0
              ? insight.totalFundingAmount
              : shop.totalFundingAmount,
          totalLikes: insight.totalLikes,
          sharedCaseCount: insight.sharedCaseCount,
          seminarRequestCount: insight.seminarRequestCount,
          completedSeminarCount: insight.completedSeminarCount > 0
              ? insight.completedSeminarCount
              : shop.completedSeminarCount,
          followerCount: insight.followerCount > 0
              ? insight.followerCount
              : shop.followerCount,
        );
        if (insight.followerCount > 0) {
          shopFollowerCount = insight.followerCount;
        }
      }
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshSeminarEducationInsight failed: $e\n$st');
    } finally {
      seminarEducationLoading = false;
      _notify();
    }
  }

  SeminarClass? seminarClassById(String? id) {
    final key = id?.trim() ?? '';
    if (key.isEmpty) return null;
    for (final c in seminarClasses) {
      if (c.id == key) return c;
    }
    return null;
  }

  Future<SeminarClass?> createSeminarClass(SeminarClass draft) async {
    try {
      final created = await _repository.createSeminarClass(draft);
      seminarClasses.insert(0, created);
      lastError = null;
      // Home 쓰레드 크로스포스트 (shop_posts.post_kind = seminar)
      try {
        final when = created.eventDate;
        final whenLabel = when == null
            ? ''
            : '${when.month}/${when.day} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
        final body = [
          '[모집 중] ${created.title}',
          if (whenLabel.isNotEmpty) '일시 $whenLabel',
          if (created.location.trim().isNotEmpty) '장소 ${created.location.trim()}',
          '정원 ${created.currentEnrollment}/${created.maxCapacity}',
        ].join('\n');
        await createShopPost(
          body: body,
          postKind: 'seminar',
          seminarClassId: created.id,
        );
      } catch (e) {
        debugPrint('seminar cross-post failed: $e');
      }
      _notify();
      return created;
    } catch (e, st) {
      debugPrint('createSeminarClass failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return null;
    }
  }

  Future<void> refreshSeminarClasses() async {
    final sid = shop.id.trim();
    try {
      seminarClasses
        ..clear()
        ..addAll(await _repository.loadSeminarClassesForShop(sid));
      _notify();
    } catch (e) {
      debugPrint('refreshSeminarClasses failed: $e');
    }
  }

  /// 다른 원장 샵의 세미나 목록 (Community 브릿지용).
  Future<List<SeminarClass>> loadSeminarClassesForShop(String shopId) {
    return _repository.loadSeminarClassesForShop(shopId.trim());
  }

  Future<bool> submitSeminarApplication(SeminarApplication draft) async {
    try {
      await _repository.submitSeminarApplication(draft);
      lastError = null;
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('submitSeminarApplication failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return false;
    }
  }

  Future<SeminarClassDetail?> loadSeminarClassDetail(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) return null;
    try {
      final detail = await _repository.loadSeminarClassDetail(id);
      lastError = null;
      return detail;
    } catch (e, st) {
      debugPrint('loadSeminarClassDetail failed: $e\n$st');
      _setError(e, userFacing: true);
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
      await refreshMySeminarEnrollments();
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
      await refreshMySeminarEnrollments();
      if (net > 0) {
        await refreshSeminarEducationInsight();
      }
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

  Future<void> refreshMySeminarEnrollments() async {
    if (mySeminarEnrollmentsLoading) return;
    mySeminarEnrollmentsLoading = true;
    _notify();
    final sid = shop.id.trim();
    try {
      mySeminarEnrollments = sid.isEmpty
          ? const []
          : await _repository.loadMySeminarEnrollments(sid);
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshMySeminarEnrollments failed: $e\n$st');
    } finally {
      mySeminarEnrollmentsLoading = false;
      _notify();
    }
  }

  Future<bool> submitSeminarEnrollmentReview({
    required String enrollmentId,
    required List<String> insightTags,
    String comment = '',
  }) async {
    try {
      await _repository.submitSeminarEnrollmentReview(
        enrollmentId: enrollmentId,
        insightTags: insightTags,
        comment: comment,
      );
      lastError = null;
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('submitSeminarEnrollmentReview failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return false;
    }
  }

  Future<void> refreshSeminarFeedbackReports() async {
    if (seminarFeedbackReportsLoading) return;
    seminarFeedbackReportsLoading = true;
    _notify();
    final sid = shop.id.trim();
    try {
      seminarFeedbackReports = sid.isEmpty
          ? const []
          : await _repository.loadSeminarFeedbackReports(sid);
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshSeminarFeedbackReports failed: $e\n$st');
    } finally {
      seminarFeedbackReportsLoading = false;
      _notify();
    }
  }

  Future<SeminarFeedbackReport?> loadSeminarFeedbackReportDetail(
    String reportId,
  ) async {
    try {
      final detail = await _repository.loadSeminarFeedbackReportDetail(reportId);
      lastError = null;
      return detail;
    } catch (e, st) {
      debugPrint('loadSeminarFeedbackReportDetail failed: $e\n$st');
      _setError(e, userFacing: true);
      return null;
    }
  }

  Future<void> refreshSeminarFeedbackReport(String classId) async {
    try {
      await _repository.refreshSeminarFeedbackReport(classId);
      lastError = null;
    } catch (e, st) {
      debugPrint('refreshSeminarFeedbackReport failed: $e\n$st');
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
      Customer? cust;
      for (final c in customers) {
        if (c.id == chart.customerId) {
          cust = c;
          break;
        }
      }
      out.add(
        CommunityCaseItem(
          chart: chart.asPublicFeedProjection().copyWith(
            feedAge: cust?.koreanAge,
            feedGenderLabel: cust?.gender?.label,
            authorId: shop.ownerUserId,
          ),
          shop: shop,
          review: reviewForChart(chart.id)?.copyWith(customerId: ''),
          careTags: chart.careTags,
          customerAge: cust?.koreanAge,
          customerGenderLabel: cust?.gender?.label,
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

  Future<bool> uploadShopGalleryImage(Uint8List bytes, {String title = ''}) async {
    if (bytes.isEmpty) return false;
    if (gallerySlides.length >= 20) {
      throw StateError('샵 갤러리는 최대 20장까지 등록할 수 있습니다.');
    }
    final shopId = shop.id.trim().isEmpty ? 'local-shop' : shop.id.trim();
    var url = await ShopMediaStorage.uploadGalleryImage(
      bytes: bytes,
      shopId: shopId,
    );
    if (url == null || url.isEmpty) {
      if (!_repository.isRemote) {
        url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else {
        return false;
      }
    }
    try {
      final slide = await _repository.insertShopGalleryItem(
        shopId: shopId,
        imageUrl: url,
        title: title,
      );
      gallerySlides.add(slide);
      _notify();
      return true;
    } catch (e) {
      debugPrint('uploadShopGalleryImage failed: $e');
      rethrow;
    }
  }

  Future<void> removeShopGalleryItem(String itemId) async {
    await _repository.deleteShopGalleryItem(itemId);
    gallerySlides.removeWhere((e) => e.id == itemId);
    _notify();
  }

  /// 기기/제품 카드 목록 저장 (이미지 URL 포함).
  Future<bool> saveEquipmentItems(List<ShopEquipmentItem> items) async {
    final frozen = List<ShopEquipmentItem>.unmodifiable(items);
    shop = shop.copyWith(equipmentItems: frozen);
    _notify();
    return _persistShopFields({
      'equipment_items': frozen.map((e) => e.toMap()).toList(),
    });
  }

  Future<ShopEquipmentItem?> addEquipmentItem({
    required String name,
    Uint8List? imageBytes,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    String? url;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      url = await ShopMediaStorage.uploadEquipmentImage(
        bytes: imageBytes,
        shopId: shop.id.trim().isEmpty ? 'local-shop' : shop.id.trim(),
      );
      if ((url == null || url.isEmpty) && !_repository.isRemote) {
        url = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      }
    }
    final item = ShopEquipmentItem(
      id: 'eq-${DateTime.now().millisecondsSinceEpoch}',
      name: n,
      imageUrl: url,
    );
    await saveEquipmentItems([...shop.equipmentItems, item]);
    return item;
  }

  Future<ShopPost?> createShopPost({
    required String body,
    Uint8List? imageBytes,
    List<Uint8List>? imageBytesList,
    String postKind = 'note',
    String? seminarClassId,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return null;
    final shopId = shop.id.trim();
    final chunks = <Uint8List>[
      if (imageBytes != null && imageBytes.isNotEmpty) imageBytes,
      ...?imageBytesList?.where((e) => e.isNotEmpty),
    ];
    final urls = <String>[];
    for (final bytes in chunks) {
      var url = await ShopMediaStorage.uploadPostImage(
        bytes: bytes,
        shopId: shopId.isEmpty ? 'local-shop' : shopId,
      );
      if (url == null || url.isEmpty) {
        if (!_repository.isRemote) {
          url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    final post = await _repository.insertShopPost(
      shopId: shopId,
      body: text,
      authorUserId: session?.id,
      imageUrls: urls,
      postKind: postKind,
      seminarClassId: seminarClassId,
    );
    shopPosts.insert(0, post);
    _applyCommunityActivityBump(1);
    _notify();
    return post;
  }

  Future<bool> removeShopPost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return false;
    ShopPost? target;
    for (final p in shopPosts) {
      if (p.id == id) {
        target = p;
        break;
      }
    }
    if (target != null &&
        target.shopId.isNotEmpty &&
        shop.id.isNotEmpty &&
        target.shopId != shop.id) {
      return false;
    }
    await _repository.deleteShopPost(id);
    shopPosts.removeWhere((e) => e.id == id);
    _notify();
    return true;
  }

  Future<void> refreshCommunityPosts({CommunityPostType? type}) async {
    if (communityPostsLoading) return;
    communityPostsLoading = true;
    _notify();
    try {
      final list = await _repository.loadCommunityPosts(type: type, limit: 50);
      communityPosts
        ..clear()
        ..addAll(list);
      lastError = null;
    } catch (e) {
      debugPrint('refreshCommunityPosts failed: $e');
    } finally {
      communityPostsLoading = false;
      _notify();
    }
  }

  Future<CommunityPost?> createCommunityPost({
    required CommunityPostType postType,
    required String body,
    String title = '',
    List<Uint8List>? imageBytesList,
    List<String> styleTags = const [],
    List<CommunityTagDraft> tagDrafts = const [],
    DeviceReviewDraft? deviceReview,
    MarketListingDraft? marketListing,
    CommunityVisibility visibility = CommunityVisibility.public,
    String? sourceChartId,
  }) async {
    final text = body.trim();
    if (text.isEmpty &&
        title.trim().isEmpty &&
        (imageBytesList == null || imageBytesList.isEmpty) &&
        deviceReview == null) {
      return null;
    }
    final shopId = shop.id.trim();
    if (shopId.isEmpty) return null;

    final urls = <String>[];
    for (final bytes in imageBytesList ?? const <Uint8List>[]) {
      if (bytes.isEmpty) continue;
      var url = await ShopMediaStorage.uploadPostImage(
        bytes: bytes,
        shopId: shopId,
      );
      if (url == null || url.isEmpty) {
        if (!_repository.isRemote) {
          url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }
      if (url != null && url.isNotEmpty) urls.add(url);
    }

    try {
      var post = await _repository.insertCommunityPost(
        shopId: shopId,
        postType: postType,
        body: text,
        title: title,
        authorUserId: session?.id,
        imageUrls: urls,
        styleTags: styleTags,
        tagDrafts: tagDrafts,
        deviceReview: deviceReview,
        marketListing: marketListing,
        visibility: visibility,
        sourceChartId: sourceChartId,
      );
      post = post.copyWith(
        shopName: shop.name,
        shopOwnerName: shop.ownerName,
        shopAvatarUrl: shop.profileImageUrl,
        tierBadge: shop.tierBadge,
      );
      communityPosts.insert(0, post);
      // device_review insert also bumps via trigger (+1); community_posts +1.
      final bump = deviceReview != null ? 2 : 1;
      _applyCommunityActivityBump(bump);
      _notify();
      return post;
    } catch (e, st) {
      debugPrint('createCommunityPost failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return null;
    }
  }

  /// My Page 티어 프로그레스에 즉시 반영 (DB 트리거와 동일 가산 가정).
  void _applyCommunityActivityBump(int delta) {
    if (delta <= 0) return;
    shop = shop.copyWith(
      communityActivityScore: shop.communityActivityScore + delta,
    );
  }

  /// 차트 → Community case_share (개인정보 마스킹, DB 트랜잭션 RPC).
  /// [title]/[body]가 있으면 AI/편집본을 그대로 발행한다.
  Future<CommunityPost?> publishChartCaseToCommunity(
    CustomerChart chart, {
    String? title,
    String? body,
  }) async {
    final shopId = shop.id.trim();
    if (shopId.isEmpty) return null;
    // Avoid duplicate publish for same chart.
    for (final p in communityPosts) {
      if (p.sourceChartId == chart.id &&
          p.postType == CommunityPostType.caseShare) {
        return p;
      }
    }

    final care = chart.careName.trim().isEmpty ? '시술 케이스' : chart.careName.trim();
    final insight = chart.directorInsight.trim();
    final summary = chart.treatmentSummary.trim();
    final resolvedTitle =
        (title ?? '').trim().isNotEmpty ? title!.trim() : '$care · 임상 케이스';
    final resolvedBody = (body ?? '').trim().isNotEmpty
        ? body!.trim()
        : [
            if (summary.isNotEmpty) summary,
            if (insight.isNotEmpty) insight,
            if (summary.isEmpty && insight.isEmpty)
              '$care 임상 기록 공유 (고객 정보는 비식별화되었습니다)',
          ].join('\n\n');

    final urls = <String>[];
    final before = (chart.beforeImageUrl ?? '').trim();
    final after = (chart.afterImageUrl ?? '').trim();
    if (before.startsWith('http') || before.startsWith('data:')) {
      urls.add(before);
    }
    if (after.startsWith('http') || after.startsWith('data:')) {
      urls.add(after);
    }

    try {
      CommunityPost? post;
      try {
        post = await _repository.saveChartAndPublishCase(
          chartId: chart.id,
          shopId: shopId,
          publish: true,
          title: resolvedTitle,
          body: resolvedBody,
          imageUrls: urls,
          authorUserId: session?.id,
        );
      } catch (e, st) {
        debugPrint('saveChartAndPublishCase RPC failed, fallback: $e\n$st');
        try {
          setManagementCaseShared(chart.id, true);
        } catch (_) {}
        post = await _repository.insertCommunityPost(
          shopId: shopId,
          postType: CommunityPostType.caseShare,
          title: resolvedTitle,
          body: resolvedBody,
          authorUserId: session?.id,
          imageUrls: urls,
          styleTags: const ['케이스공유', '비식별'],
          sourceChartId: chart.id,
        );
      }
      if (post == null) return null;
      try {
        setManagementCaseShared(chart.id, true);
      } catch (_) {}
      final enriched = post.copyWith(
        shopName: shop.name,
        shopOwnerName: shop.ownerName,
        shopAvatarUrl: shop.profileImageUrl,
        tierBadge: shop.tierBadge,
      );
      communityPosts.insert(0, enriched);
      _applyCommunityActivityBump(1);
      _notify();
      return enriched;
    } catch (e, st) {
      debugPrint('publishChartCaseToCommunity failed: $e\n$st');
      return null;
    }
  }

  Future<List<CommunityComment>> loadCommunityComments(String postId) {
    return _repository.loadCommunityComments(postId);
  }

  Future<CommunityComment?> addCommunityComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return null;
    try {
      final c = await _repository.insertCommunityComment(
        postId: postId,
        content: text,
        authorUserId: session?.id,
        authorShopId: shop.id,
        parentId: parentId,
      );
      return c.copyWith();
    } catch (e, st) {
      debugPrint('addCommunityComment failed: $e\n$st');
      _setError(e, userFacing: true);
      return null;
    }
  }

  Future<void> openAffiliateExternalUrl({
    required String url,
    required String ownerShopId,
    String label = '',
    String? postId,
    String? postTagId,
    String? partnerId,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    unawaited(
      _repository.trackAffiliateClick(
        shopId: ownerShopId,
        destinationUrl: trimmed.startsWith('http') ? trimmed : 'https://$trimmed',
        label: label,
        postId: postId,
        postTagId: postTagId,
        partnerId: partnerId,
        clickedByUserId: session?.id,
        clickedByShopId: shop.id,
      ),
    );
  }

  Future<AffiliateEarningsSummary> loadAffiliateEarnings() {
    return _repository.loadAffiliateEarnings(shop.id);
  }

  Future<AffiliateConversion?> recordAffiliateConversion({
    required int commissionAmount,
    String orderRef = '',
    int grossAmount = 0,
    String note = '',
  }) {
    return _repository.recordAffiliateConversion(
      shopId: shop.id,
      commissionAmount: commissionAmount,
      orderRef: orderRef,
      grossAmount: grossAmount,
      note: note,
    );
  }

  Future<AffiliateConversion?> settleAffiliateConversion({
    required String conversionId,
    required String toStatus,
  }) {
    return _repository.settleAffiliateConversion(
      conversionId: conversionId,
      toStatus: toStatus,
      actorUserId: session?.id,
    );
  }

  SoriPointWallet pointWallet = SoriPointWallet.empty;
  List<PointTransaction> pointTransactions = [];
  List<SettlementTransaction> settlementTransactions = [];

  Future<SoriPointWallet> refreshPointWallet() async {
    try {
      pointWallet = await _repository.loadPointWallet(shop.id);
      pointTransactions =
          await _repository.loadPointTransactions(shop.id, limit: 20);
      settlementTransactions =
          await _repository.loadSettlementTransactions(shop.id, limit: 20);
      _notify();
      return pointWallet;
    } catch (e, st) {
      debugPrint('refreshPointWallet failed: $e\n$st');
      return pointWallet;
    }
  }

  Future<SoriPointWallet?> purchaseSoriPoints({
    required int amount,
    required String sku,
  }) async {
    try {
      final w = await _repository.purchaseSoriPoints(
        shopId: shop.id,
        amount: amount,
        sku: sku,
        orderRef: 'stub-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (w != null) {
        pointWallet = w;
        await refreshPointWallet();
      }
      return w;
    } catch (e, st) {
      debugPrint('purchaseSoriPoints failed: $e\n$st');
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  /// 정산금만 환전 — 포인트 잔액은 변경되지 않음.
  Future<Map<String, dynamic>?> requestSettlementWithdraw({
    required int amount,
    String bankAccountMask = '',
    String note = '',
  }) async {
    try {
      final raw = await _repository.requestSettlementWithdraw(
        shopId: shop.id,
        amount: amount,
        bankAccountMask: bankAccountMask,
        note: note,
      );
      await refreshPointWallet();
      return raw;
    } catch (e, st) {
      debugPrint('requestSettlementWithdraw failed: $e\n$st');
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  /// 잠금 게시물 포인트 해금 — 원본 body로 communityPosts 갱신.
  Future<CommunityPost?> unlockCommunityPostWithPoints(
    CommunityPost post, {
    int cost = 5,
  }) async {
    final sid = shop.id.trim();
    if (sid.isEmpty) return null;
    try {
      final result = await _repository.unlockCommunityPostWithPoints(
        postId: post.id,
        viewerShopId: sid,
        cost: cost,
      );
      if (!result.ok) return null;
      await refreshPointWallet();
      CommunityPost unlocked = post.copyWith(isBodyLocked: false);
      final raw = result.post;
      if (raw != null) {
        unlocked = CommunityPost.fromMap(raw).copyWith(
          shopName: post.shopName,
          shopOwnerName: post.shopOwnerName,
          shopAvatarUrl: post.shopAvatarUrl,
          tierBadge: post.tierBadge,
          businessVerified: post.businessVerified,
          isBodyLocked: false,
          listing: post.listing,
          deviceReview: post.deviceReview,
          tags: post.tags,
        );
      }
      for (var i = 0; i < communityPosts.length; i++) {
        if (communityPosts[i].id == post.id) {
          communityPosts[i] = unlocked;
          break;
        }
      }
      _notify();
      return unlocked;
    } catch (e, st) {
      debugPrint('unlockCommunityPostWithPoints failed: $e\n$st');
      _setError(e, userFacing: true);
      rethrow;
    }
  }

  Future<bool> updateMarketListingStatus({
    required String listingId,
    required MarketListingStatus status,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) return false;
    try {
      await _repository.updateMarketListingStatus(
        listingId: id,
        status: status,
      );
      for (var i = 0; i < communityPosts.length; i++) {
        final p = communityPosts[i];
        final l = p.listing;
        if (l == null || l.id != id) continue;
        if (p.shopId.isNotEmpty &&
            shop.id.isNotEmpty &&
            p.shopId != shop.id) {
          return false;
        }
        communityPosts[i] = p.copyWith(listing: l.copyWith(status: status));
        _notify();
        return true;
      }
      return true;
    } catch (e, st) {
      debugPrint('updateMarketListingStatus failed: $e\n$st');
      _setError(e, userFacing: true);
      _notify();
      return false;
    }
  }

  Future<bool> removeCommunityPost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return false;
    CommunityPost? target;
    for (final p in communityPosts) {
      if (p.id == id) {
        target = p;
        break;
      }
    }
    if (target != null &&
        target.shopId.isNotEmpty &&
        shop.id.isNotEmpty &&
        target.shopId != shop.id) {
      return false;
    }
    await _repository.deleteCommunityPost(id);
    communityPosts.removeWhere((e) => e.id == id);
    _notify();
    return true;
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

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 촬영용 오늘 회차 — 있으면 재사용, 없으면 직전 케어 내용 복사해 생성.
  Future<CustomerChart> ensureTodayShootChart({
    required String customerId,
    bool copyPreviousCare = true,
  }) async {
    final cid = customerId.trim();
    if (cid.isEmpty) throw StateError('customerId required');
    if (findCustomer(cid) == null) {
      throw StateError('Customer not found');
    }

    final now = DateTime.now();
    final todays = chartsForCustomer(cid).where((c) {
      final t = c.createdAt ?? c.visitCheckedAt;
      return t != null && _isSameCalendarDay(t, now);
    }).toList();

    if (todays.isNotEmpty) {
      todays.sort((a, b) {
        final aw = a.needsAfterPhoto ? 0 : 1;
        final bw = b.needsAfterPhoto ? 0 : 1;
        if (aw != bw) return aw.compareTo(bw);
        return b.visitNumber.compareTo(a.visitNumber);
      });
      return todays.first;
    }

    final previous = latestChart(cid);
    final nextVisit = (previous?.visitNumber ?? 0) + 1;
    final copy = copyPreviousCare && previous != null;

    return saveChartAndConfirmVisitAsync(
      customerId: cid,
      visitNumber: nextVisit < 1 ? 1 : nextVisit,
      careName: copy ? previous.careName : '',
      treatmentSummary: copy ? previous.treatmentSummary : '',
      directorInsight: copy ? previous.directorInsight : '',
      concernChips: copy ? previous.concernChips : const [],
      firstVisitFearChips: copy ? previous.firstVisitFearChips : const [],
      revisitFeedbackChips: copy ? previous.revisitFeedbackChips : const [],
      deviceInfo: copy ? previous.deviceInfo : null,
      allergyNotes: copy ? previous.allergyNotes : null,
      skinSensitivity: copy ? previous.skinSensitivity : null,
      sideEffectHistory: copy ? previous.sideEffectHistory : null,
      customerRequests: copy ? previous.customerRequests : null,
      homeCarePrescriptions:
          copy ? previous.homeCarePrescriptions : const [],
    );
  }

  /// After 대기 목록 (차트 단위, 최근 14일).
  List<({Customer customer, CustomerChart chart})> shootAfterWaiting({
    int maxAgeDays = 14,
  }) {
    final out = <({Customer customer, CustomerChart chart})>[];
    final now = DateTime.now();
    for (final c in customers) {
      for (final chart in chartsForCustomer(c.id)) {
        if (!chart.needsAfterPhoto) continue;
        final created = chart.createdAt ?? chart.visitCheckedAt;
        if (created != null &&
            now.difference(created).inDays > maxAgeDays) {
          continue;
        }
        out.add((customer: c, chart: chart));
      }
    }
    out.sort((a, b) {
      final ad = a.chart.createdAt ??
          a.chart.visitCheckedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.createdAt ??
          b.chart.visitCheckedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  Future<void> refreshShootInbox() async {
    shootInboxLoading = true;
    _notify();
    try {
      final rows = await ShootInboxLocal.load(shop.id);
      shootInbox
        ..clear()
        ..addAll(rows);
    } finally {
      shootInboxLoading = false;
      _notify();
    }
  }

  Future<void> _persistShootInbox() async {
    await ShootInboxLocal.save(shop.id, List.of(shootInbox));
  }

  /// 신규 촬영 → 미연결 큐.
  Future<ShootInboxItem> addUnboundShootPhoto({
    required Uint8List jpegOrRaw,
    required String kind,
    String label = '',
    String? sessionToken,
    String? ghostBeforeUrl,
  }) async {
    final compressed = await ChartPhotoCompressor.toWebp(jpegOrRaw);
    if (compressed == null || compressed.isEmpty) {
      throw StateError('WebP 압축 실패');
    }
    final token = (sessionToken?.trim().isNotEmpty == true)
        ? sessionToken!.trim()
        : 'sess-${DateTime.now().millisecondsSinceEpoch}';
    final url = await ChartPhotoStorage.uploadWebp(
      bytes: compressed,
      shopId: shop.id,
      customerId: 'unbound',
      kind: kind,
    );
    if (url == null || url.trim().isEmpty) {
      throw StateError('업로드 실패');
    }
    final item = ShootInboxItem(
      id: 'inbox-${DateTime.now().microsecondsSinceEpoch}',
      shopId: shop.id,
      kind: kind == 'after' ? 'after' : 'before',
      imageUrl: url,
      label: label.trim(),
      sessionToken: token,
      createdAt: DateTime.now(),
      ghostBeforeUrl: ghostBeforeUrl,
    );
    shootInbox.insert(0, item);
    await _persistShootInbox();
    _notify();
    return item;
  }

  Future<void> dismissShootInboxItem(String id) async {
    shootInbox.removeWhere((e) => e.id == id);
    await _persistShootInbox();
    _notify();
  }

  Future<void> enqueueShootInboxItem(ShootInboxItem item) async {
    shootInbox.removeWhere((e) => e.id == item.id);
    shootInbox.insert(0, item);
    await _persistShootInbox();
    _notify();
  }

  /// 미연결 사진을 고객 오늘 회차에 연결.
  Future<CustomerChart> bindShootInboxToCustomer({
    required String inboxId,
    required String customerId,
    bool copyPreviousCare = true,
  }) async {
    final idx = shootInbox.indexWhere((e) => e.id == inboxId);
    if (idx < 0) throw StateError('inbox item not found');
    final item = shootInbox[idx];
    final chart = await ensureTodayShootChart(
      customerId: customerId,
      copyPreviousCare: copyPreviousCare,
    );
    if (item.isBefore) {
      await updateCustomerChartFields(
        chartId: chart.id,
        beforeImageUrl: item.imageUrl,
      );
    } else {
      await patchChartAfterImage(
        chartId: chart.id,
        afterImageUrl: item.imageUrl,
      );
    }
    shootInbox.removeWhere((e) => e.id == inboxId);
    await _persistShootInbox();
    _notify();
    return findChartById(chart.id) ?? chart;
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

  /// 고객 일괄 삭제 — 원격 성공 ID만 로컬 customers/charts/reviews에서 purge.
  Future<BulkDeleteResult> bulkDeleteCustomers(List<String> customerIds) async {
    final ids = customerIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const BulkDeleteResult(deletedIds: [], failedIds: []);
    }
    if (ids.length > 50) {
      throw ArgumentError('한 번에 최대 50명까지 삭제할 수 있습니다.');
    }

    isLoading = true;
    lastError = null;
    _notify();
    try {
      final BulkDeleteResult result;
      if (_repository.isRemote) {
        result = await _repository.bulkDeleteCustomers(ids);
      } else {
        result = BulkDeleteResult(deletedIds: ids);
      }
      _purgeCustomersLocally(result.deletedIds);
      return result;
    } catch (e) {
      _setError(e, userFacing: true);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void _purgeCustomersLocally(List<String> deletedIds) {
    if (deletedIds.isEmpty) return;
    final idSet = deletedIds.toSet();
    customers.removeWhere((c) => idSet.contains(c.id));
    charts.removeWhere((c) => idSet.contains(c.customerId));
    reviews.removeWhere((r) => idSet.contains(r.customerId));
    reviewRequestedCustomerIds.removeWhere(idSet.contains);
  }

  /// 중복 고객 병합 — Primary 유지, Secondary purge + 차트 재번호.
  Future<CustomerMergeResult> mergeShopCustomers({
    required String primaryId,
    required List<String> sourceIds,
  }) async {
    final primary = primaryId.trim();
    final sources = sourceIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != primary)
        .toSet()
        .toList();
    if (primary.isEmpty || sources.isEmpty) {
      throw ArgumentError('Primary와 Secondary 고객을 선택해 주세요.');
    }
    if (sources.length > 10) {
      throw ArgumentError('한 번에 최대 10명까지 병합할 수 있습니다.');
    }

    final primaryCustomer = findCustomer(primary);
    if (primaryCustomer == null) {
      throw StateError('Primary 고객을 찾을 수 없습니다.');
    }
    final mergeTargets = sources
        .map(findCustomer)
        .whereType<Customer>()
        .toList();
    if (mergeTargets.isEmpty) {
      throw StateError('병합 가능한 Secondary 고객이 없습니다.');
    }

    isLoading = true;
    lastError = null;
    _notify();
    try {
      CustomerMergeResult result;
      if (_repository.isRemote) {
        result = await _repository.mergeShopCustomers(
          primaryId: primary,
          sourceIds: sources,
        );
        await reloadCustomersAndCharts();
      } else {
        result = _mergeCustomersLocally(
          primary: primaryCustomer,
          sources: mergeTargets,
        );
      }
      return result;
    } catch (e) {
      _setError(e, userFacing: true);
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  CustomerMergeResult _mergeCustomersLocally({
    required Customer primary,
    required List<Customer> sources,
  }) {
    final sourceIds = sources.map((c) => c.id).toSet();
    var reviewsMoved = 0;

    for (final chart in charts) {
      if (sourceIds.contains(chart.customerId)) {
        final idx = charts.indexOf(chart);
        charts[idx] = chart.copyWith(customerId: primary.id);
      }
    }

    for (var i = 0; i < reviews.length; i++) {
      if (sourceIds.contains(reviews[i].customerId)) {
        reviews[i] = reviews[i].copyWith(customerId: primary.id);
        reviewsMoved++;
      }
    }

    final primaryCharts = charts.where((c) => c.customerId == primary.id).toList()
      ..sort((a, b) {
        final ad = a.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });
    for (var i = 0; i < primaryCharts.length; i++) {
      final ch = primaryCharts[i];
      final idx = charts.indexWhere((c) => c.id == ch.id);
      if (idx >= 0) {
        charts[idx] = ch.copyWith(visitNumber: i + 1);
      }
    }

    final mergedMemberships = CustomerMergeService.mergeMembershipsCombineByName(
      [primary, ...sources],
    );
    final latestVisit = primaryCharts.isEmpty
        ? primary.lastTreatmentDate
        : primaryCharts.last.feedPostedAt ?? primary.lastTreatmentDate;

    final updated = primary
        .copyWith(
          memberships: mergedMemberships,
          lastTreatmentDate: latestVisit,
          memo: [
            primary.memo,
            ...sources.map((s) => s.memo).where((m) => m.trim().isNotEmpty),
          ].where((m) => m.trim().isNotEmpty).join('\n'),
        )
        .withSyncedMembershipMirrors();
    _mergeCustomer(updated);
    _purgeCustomersLocally(sourceIds.toList());

    _notify();
    return CustomerMergeResult(
      primaryId: primary.id,
      mergedIds: sourceIds.toList(),
      chartsTotal: primaryCharts.length,
      reviewsMoved: reviewsMoved,
      walletsMerged: 0,
    );
  }

  /// 차트·고객 원격 재로드 (병합 후 SSOT 동기화).
  Future<void> reloadCustomersAndCharts() async {
    if (!_repository.isRemote) return;
    final snap = await _repository.loadInitialData();
    customers
      ..clear()
      ..addAll(snap.customers);
    charts
      ..clear()
      ..addAll(snap.charts);
    reviews
      ..clear()
      ..addAll(snap.reviews);
    _notify();
  }

  /// 고객 회원권만 저장 (CRM 퀵 액션 / 바텀 시트).
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
    String? deviceInfo,
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
        deviceInfo: deviceInfo,
      );
      charts[index] = chart;
    } else {
      var assignedVisit = visitNumber < 1 ? 1 : visitNumber;
      final used = charts
          .where((c) => c.customerId == customerId)
          .map((c) => c.visitNumber)
          .toSet();
      while (used.contains(assignedVisit)) {
        assignedVisit += 1;
      }
      chart = CustomerChart(
        id: 'chart-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shop.id,
        customerId: customerId,
        visitNumber: assignedVisit,
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
        deviceInfo: deviceInfo,
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

/// 리뷰 운영 콘솔 — 인박스 레인.
enum ReviewOpsLane {
  unreplied,
  new24h,
  all,
}

/// 리뷰 운영 콘솔 KPI (클라 파생).
class ReviewOpsKpi {
  const ReviewOpsKpi({
    required this.unreplied,
    required this.new24h,
    required this.requestedPending,
    required this.weekCount,
    required this.avgRating,
    required this.naverRate,
    required this.replyRate,
    required this.inboxTotal,
    this.remindDue = 0,
  });

  final int unreplied;
  final int new24h;
  final int requestedPending;
  final int weekCount;
  final double avgRating;
  final double naverRate;
  final double replyRate;
  final int inboxTotal;
  final int remindDue;
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
