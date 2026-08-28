import '../models/care_diary_note.dart';
import '../models/case_timeline_entry.dart';
import '../models/community_case_item.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_merge_preview.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/kakao_alimtalk.dart';
import '../models/membership_ticket.dart';
import '../models/review_reply.dart';
import '../models/review_request_event.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_post.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../models/affiliate_earnings.dart';
import '../models/sori_point_wallet.dart';
import '../models/point_shop.dart';
import '../models/premium_overlay.dart';
import '../models/fan_supporter.dart';
import '../models/shop_supporter_header.dart';
import '../models/seminar_class.dart';
import '../models/seminar_application.dart';
import '../models/seminar_class_detail.dart';
import '../models/seminar_education_insight.dart';
import '../models/seminar_feedback_report.dart';
import '../models/seminar_enrollment.dart';
import '../utils/db_map.dart';
import '../utils/feed_interleave.dart';
import '../models/shop_highlight.dart';
import '../models/shop_tier_badge.dart';
import '../models/shop_service_item.dart';
import '../models/subscription.dart';
import '../models/whisper.dart';
import 'sori_repository.dart';

/// 로컬 더미 데이터 (UI 하드코딩 분리용).
class MemorySoriRepository implements SoriRepository {
  /// shopId → customerIds 팔로우 셋 (프로세스 내 유지).
  static final Map<String, Set<String>> _followersByShop = {};
  /// followerUserId → subscriptions
  static final Map<String, List<Subscription>> _subscriptionsByUser = {};
  static final List<_MemWhisperRecipient> _whisperRecipients = [];
  static final List<WhisperAudiencePreset> _whisperPresets = [];
  /// Seed graph for audience tests: userId → role
  static final Map<String, String> _seedRoles = {
    '00000000-0000-4000-8000-000000000201': 'director', // 서연
    '00000000-0000-4000-8000-000000000202': 'director', // 준호
    '00000000-0000-4000-8000-000000000203': 'director', // 하늘
    '00000000-0000-4000-8000-000000000301': 'customer', // 민지 fan
    '00000000-0000-4000-8000-000000000302': 'customer',
    'fan-boost-user': 'customer',
    'peer-director-a': 'director',
    'peer-director-b': 'director',
    'normal-follower': 'customer',
  };
  static final Set<String> _seedFollowersOfSender = {
    'peer-director-a',
    'peer-director-b',
    'normal-follower',
    'fan-boost-user',
    '00000000-0000-4000-8000-000000000301',
  };
  static final Set<String> _seedSuperFans = {
    'fan-boost-user',
    '00000000-0000-4000-8000-000000000301',
  };
  static final Set<String> _seedVisited = {
    '00000000-0000-4000-8000-000000000301',
    'normal-follower',
  };
  static final Map<String, Set<String>> _seminarRequestsByCase = {};
  static final List<SeminarClass> _seminarClasses = [];
  static int _seminarClassSeq = 0;
  static int _enrollmentSeq = 0;
  static final Map<String, int> _shopCashBalance = {};
  static final List<Map<String, dynamic>> _enrollments = [];
  static final Map<String, Map<String, dynamic>> _enrollmentReviews = {};
  static final List<Map<String, dynamic>> _feedbackReports = [];
  static bool _seededDemoFeedback = false;

  @override
  bool get isRemote => false;

  @override
  Future<SoriSnapshot> loadInitialData() async {
    return createSeedSnapshot();
  }

  /// 동기 시드 — 테스트/생성자 호환.
  static SoriSnapshot createSeedSnapshot() {
    const shop = Shop(
      id: 'shop-demo',
      name: 'SORI 에스테틱',
      ownerName: '김원장',
      phone: '02-1234-5678',
      naverPlaceUrl: 'https://m.place.naver.com/place/sori-demo',
      address: '서울시 강남구',
      bio: '피부 장벽과 라인 케어를 섬세하게 다루는 아티스트 샵입니다. 단골 팬과 가까이 소통해요.',
      kakaoPoint: 1000,
      isPro: true,
      monthlyCapa: 100,
      tierBadge: ShopTierBadge.silver,
      totalSeminarCount: 3,
      completedSeminarCount: 3,
      totalFundingAmount: 4500000,
      sharedCaseCount: 28,
      totalLikes: 160,
      followerCount: 62,
      seminarRequestCount: 8,
      serviceMenu: [
        ShopServiceItem(
          name: '재생케어',
          description: '피부 장벽을 편안하게 회복시키는 집중 케어예요.',
          deviceInfo: '셀큐어 프로',
        ),
        ShopServiceItem(
          name: '수분케어',
          description: '건조한 피부에 촉촉함을 더하는 수분 충전 케어예요.',
        ),
        ShopServiceItem(
          name: 'EMS 윤곽케어',
          description: '탄력과 라인 정리를 돕는 EMS 기반 윤곽 케어예요.',
          deviceInfo: 'EMS 리프팅 기기',
        ),
        ShopServiceItem(
          name: '테라노바 복부관리',
          description: '복부 순환과 컨디션을 가볍게 풀어주는 관리예요.',
          deviceInfo: '테라노바',
        ),
      ],
    );

    final customers = [
      Customer(
        id: '1',
        shopId: shop.id,
        name: '김민지',
        phone: '010-1234-5678',
        lastTreatmentDate: DateTime(2026, 8, 8),
        treatmentType: '재생케어',
        memo: '두피 민감, 자연 펌 선호',
        gender: CustomerGender.female,
        birthDate: DateTime(1994, 3, 12),
        address: '서울시 강남구',
        allergyNotes: '향료 민감',
      ),
      Customer(
        id: '2',
        shopId: shop.id,
        name: '이수진',
        phone: '010-2345-6789',
        lastTreatmentDate: DateTime(2026, 8, 8),
        treatmentType: '수분케어',
        memo: '정기 예약 고객',
        gender: CustomerGender.female,
        birthDate: DateTime(1990, 7, 21),
        address: '서울시 서초구',
        allergyNotes: '없음',
        medicationHistory: '이소티논 복용 이력(2년 전)',
        membershipServiceName: '수분 케어 10회권',
        membershipTotalVisits: 10,
        membershipUsedVisits: 8,
        memberships: [
          CustomerMembership(
            id: 'm-moisture',
            serviceName: '수분 케어 10회권',
            totalVisits: 10,
            usedVisits: 8,
            paidAmount: 900000,
            perSessionValue: 90000,
            expiresAt: DateTime.now().add(const Duration(days: 120)),
          ),
        ],
      ).withSyncedMembershipMirrors(),
      Customer(
        id: '3',
        shopId: shop.id,
        name: '박서연',
        phone: '010-3456-7890',
        lastTreatmentDate: DateTime(2026, 7, 28),
        treatmentType: '재생케어',
        memo: '트리트먼트 관심 많음',
        gender: CustomerGender.female,
        birthDate: DateTime(1988, 11, 5),
        address: '서울시 송파구',
        allergyNotes: '니켈 알레르기',
        membershipServiceName: '재생 케어 10회권',
        membershipTotalVisits: 10,
        membershipUsedVisits: 4,
        createdAt: DateTime.now().subtract(const Duration(days: 220)),
        memberships: [
          CustomerMembership(
            id: 'm-regen',
            serviceName: '재생 케어 10회권',
            totalVisits: 10,
            usedVisits: 4,
            paidAmount: 1200000,
            perSessionValue: 120000,
            expiresAt: DateTime.now().add(const Duration(days: 200)),
          ),
        ],
      ).withSyncedMembershipMirrors(),
      Customer(
        id: '4',
        shopId: shop.id,
        name: '정하은',
        phone: '010-4567-8901',
        lastTreatmentDate: DateTime.now().subtract(const Duration(days: 75)),
        treatmentType: '테라노바 복부관리',
        memo: '장기 미방문 · 잔여 부채',
        gender: CustomerGender.female,
        birthDate: DateTime(1992, 4, 2),
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
        memberships: [
          CustomerMembership(
            id: 'm-theranova-bulk',
            serviceName: '테라노바 복부 20회권',
            totalVisits: 20,
            usedVisits: 5,
            paidAmount: 2400000,
            perSessionValue: 120000,
          ),
          CustomerMembership(
            id: 'm-ldm-pack',
            serviceName: 'LDM 장벽 10회권',
            totalVisits: 10,
            usedVisits: 1,
            paidAmount: 1100000,
            perSessionValue: 110000,
          ),
        ],
      ).withSyncedMembershipMirrors(),
      Customer(
        id: '5',
        shopId: shop.id,
        name: '오수빈',
        phone: '010-5678-9012',
        lastTreatmentDate: DateTime.now().subtract(const Duration(days: 10)),
        treatmentType: 'EMS 윤곽케어',
        memo: '대량 잔여 부채 (Hell-Zone)',
        gender: CustomerGender.female,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        memberships: [
          CustomerMembership(
            id: 'm-ems-50',
            serviceName: 'EMS 윤곽 50회권',
            totalVisits: 50,
            usedVisits: 8,
            paidAmount: 4500000,
            perSessionValue: 90000,
          ),
          CustomerMembership(
            id: 'm-moisture-30',
            serviceName: '수분 케어 30회권',
            totalVisits: 30,
            usedVisits: 4,
            paidAmount: 2100000,
            perSessionValue: 70000,
          ),
          CustomerMembership(
            id: 'm-regen-40',
            serviceName: '재생 케어 40회권',
            totalVisits: 40,
            usedVisits: 6,
            paidAmount: 4000000,
            perSessionValue: 100000,
          ),
        ],
      ).withSyncedMembershipMirrors(),
    ];

    const gallerySlides = [
      ShopGallerySlide(
        id: 'g1',
        title: '샵 대표 공간',
        subtitle: '상담 · 케어룸 분위기',
        kind: GalleryKind.shop,
      ),
      ShopGallerySlide(
        id: 'g2',
        title: 'Before',
        subtitle: '방문 전 피부 컨디션',
        kind: GalleryKind.before,
      ),
      ShopGallerySlide(
        id: 'g3',
        title: 'After',
        subtitle: '시술 직후 개선 포인트',
        kind: GalleryKind.after,
      ),
    ];

    final charts = [
      CustomerChart(
        id: 'chart-1',
        shopId: shop.id,
        customerId: '1',
        visitNumber: 1,
        careName: '재생케어',
        treatmentSummary: '첫 방문 재생케어 — 장벽 진정 및 수분 리페어',
        directorInsight: '두피 민감 — 저자극 제품 권장',
        concernChips: const ['홍조/민감', '건조/장벽'],
        skinSensitivity: '수부지',
        deviceInfo: '테라노바',
        beforeImageUrl: 'https://picsum.photos/seed/sori-b1/600/800',
        afterImageUrl: 'https://picsum.photos/seed/sori-a1/600/800',
        signatureUrl: 'https://example.com/sig-1.png',
        consentPhoto: true,
        caseShared: true,
        homeCarePrescriptions: const [
          'tag_gentle_cleanse',
          'tag_moisture_pack',
          'tag_sun',
        ],
        visitCheckedAt: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      CustomerChart(
        id: 'chart-2',
        shopId: shop.id,
        customerId: '2',
        visitNumber: 6,
        customChartNo: 'A-106',
        careName: '수분케어',
        treatmentSummary: '회원권 6회차 테라노바 수분케어',
        directorInsight: '테라노바 저자극 세션 후 장벽 크림 레이어링을 권장합니다.',
        concernChips: const ['모공/피지', '건조/장벽', '여드름'],
        skinSensitivity: '지성',
        deviceInfo: '테라노바',
        beforeImageUrl: 'https://picsum.photos/seed/sori-b2/600/800',
        afterImageUrl: 'https://picsum.photos/seed/sori-a2/600/800',
        signatureUrl: 'https://example.com/sig-2.png',
        consentPhoto: true,
        caseShared: true,
        visitCheckedAt: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      CustomerChart(
        id: 'chart-3',
        shopId: shop.id,
        customerId: '3',
        visitNumber: 4,
        careName: '재생케어',
        treatmentSummary: '회원권 4회차 재생케어',
        directorInsight: '트리트먼트 업셀 가능',
        concernChips: const ['탄력/리프팅'],
        skinSensitivity: '건성',
        beforeImageUrl: 'https://picsum.photos/seed/sori-b3/600/800',
        afterImageUrl: 'https://picsum.photos/seed/sori-a3/600/800',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ];

    final reviews = [
      CustomerReview(
        id: 'rev-1',
        chartId: 'chart-1',
        customerId: '1',
        shopId: shop.id,
        originalText: '시술 후 자극이 거의 없고 다음 날 피부가 촉촉했어요. 설명도 친절하셨습니다.',
        status: ReviewStatus.published,
        rating: 5,
        acceptedAt: DateTime.now().subtract(const Duration(days: 1)),
        directorReply: '첫 방문부터 잘 따라와 주셔서 감사해요. 홈케어만 꾸준히 이어가 주세요!',
        directorRepliedAt: DateTime.now().subtract(const Duration(hours: 20)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CustomerReview(
        id: 'rev-2',
        chartId: 'chart-2',
        customerId: '2',
        shopId: shop.id,
        originalText: '수분감이 오래가고 화장 먹음이 좋아졌어요. 회원권 하길 잘했습니다.',
        status: ReviewStatus.published,
        rating: 5,
        acceptedAt: DateTime.now().subtract(const Duration(days: 4)),
        directorReply: '6회차까지 꾸준히 와주신 덕분에 변화가 보이네요. 다음에도 기대할게요!',
        directorRepliedAt: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];

    return SoriSnapshot(
      shop: shop,
      customers: customers,
      charts: charts,
      reviews: reviews,
      aiReplies: const [],
      gallerySlides: gallerySlides,
    );
  }

  @override
  Future<Customer?> findCustomerByPhone(String phone, {String? shopId}) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final snap = createSeedSnapshot();
    try {
      return snap.customers.firstWhere(
        (c) =>
            (shopId == null || c.shopId == shopId) &&
            c.phone.replaceAll(RegExp(r'\D'), '') == digits,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) async => customer;

  @override
  Future<Customer> registerCustomer({
    required String shopId,
    required String name,
    required String phone,
    String memo = '',
  }) async {
    return Customer(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      name: name.trim(),
      phone: phone.trim(),
      memo: memo.trim(),
      lastTreatmentDate: DateTime.now(),
      treatmentType: '',
      membershipTotalVisits: 0,
    );
  }

  @override
  Future<BulkDeleteResult> bulkDeleteCustomers(List<String> customerIds) async {
    final ids =
        customerIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return BulkDeleteResult(deletedIds: ids);
  }

  @override
  Future<CustomerMergeResult> mergeShopCustomers({
    required String primaryId,
    required List<String> sourceIds,
  }) async {
    final sources = sourceIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != primaryId)
        .toList();
    return CustomerMergeResult(
      primaryId: primaryId,
      mergedIds: sources,
      chartsTotal: 0,
      reviewsMoved: 0,
      walletsMerged: 0,
    );
  }

  @override
  Future<Shop> upsertShop(Shop shop) async => shop;

  @override
  Future<Shop> patchShopFields(String shopId, Map<String, dynamic> fields) async {
    final base = createSeedSnapshot().shop;
    return base.copyWith(
      id: shopId,
      profileImageUrl: fields['profile_image_url'] as String?,
      coverImageUrl: fields['cover_image_url'] as String?,
    );
  }

  @override
  Future<SaveChartResult> saveChartAndConfirmVisit(
    SaveChartRequest request,
  ) async {
    throw UnsupportedError('Use SoriStore.saveChartAndConfirmVisit for memory');
  }

  @override
  Future<void> updateChartCaseShared({
    required String chartId,
    required bool shared,
  }) async {}

  @override
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
    throw UnsupportedError('Use SoriStore.updateCustomerChartFields for memory');
  }

  @override
  Future<void> updateChartConsentPdfUrl({
    required String chartId,
    required String consentPdfUrl,
  }) async {}

  @override
  Future<void> updateHomeCareMissionChecks({
    required String chartId,
    required List<bool> checks,
  }) async {}

  @override
  Future<CareDiaryNote> upsertCareDiaryNote(CareDiaryNote note) async => note;

  @override
  Future<List<MembershipTicket>> loadMembershipWallet({
    String? phone,
    String? authUserId,
  }) async {
    // 시드 스냅샷에서 전화번호 매칭 고객의 회원권을 지갑으로 변환
    final snap = createSeedSnapshot();
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final out = <MembershipTicket>[];
    for (final c in snap.customers) {
      final match = digits.isNotEmpty &&
          c.phone.replaceAll(RegExp(r'[^0-9]'), '') == digits;
      if (!match) continue;
      final synced = c.withSyncedMembershipMirrors();
      for (final m in synced.memberships) {
        if (m.totalVisits <= 0) continue;
        out.add(
          MembershipTicket(
            id: m.id,
            shopId: snap.shop.id,
            customerId: c.id,
            customerPhoneDigits: digits,
            shopName: snap.shop.name,
            ticketName: m.serviceName.isEmpty ? '회원권' : m.serviceName,
            totalVisits: m.totalVisits,
            usedVisits: m.usedVisits,
            expiresAt: m.expiresAt ??
                DateTime.now().add(const Duration(days: 180)),
            naverPlaceUrl: snap.shop.naverPlaceUrl,
            isActive: m.remainingVisits > 0,
          ),
        );
      }
    }
    // 데모용 다중 샵 티켓 (같은 번호에 2장)
    if (digits == '01023456789' || digits.isEmpty) {
      out.add(
        MembershipTicket(
          id: 'demo-ticket-partner',
          shopId: 'shop-partner',
          customerId: '2',
          customerPhoneDigits: digits.isEmpty ? '01023456789' : digits,
          shopName: '파트너 스킨랩',
          ticketName: '리프팅 케어 5회권',
          totalVisits: 5,
          usedVisits: 3,
          expiresAt: DateTime.now().add(const Duration(days: 90)),
          naverPlaceUrl: snap.shop.naverPlaceUrl,
          isActive: true,
        ),
      );
    }
    return out;
  }

  @override
  Future<void> syncMembershipTicketsForCustomer(String customerId) async {}

  @override
  Future<CustomerReview> upsertReview(CustomerReview review) async => review;

  @override
  Future<CustomerReview> saveDirectorReviewReply({
    required String reviewId,
    required String shopId,
    required String body,
  }) async {
    return CustomerReview(
      id: reviewId,
      chartId: 'local-chart',
      customerId: 'local',
      shopId: shopId,
      originalText: '',
      status: ReviewStatus.published,
      directorReply: body.trim(),
      directorRepliedAt: DateTime.now(),
    );
  }

  @override
  Future<CustomerReview?> markNaverRegistered({
    required String chartId,
    String? composedText,
  }) async {
    return CustomerReview(
      id: 'local-$chartId',
      chartId: chartId,
      customerId: 'local',
      shopId: 'shop-demo',
      originalText: composedText ?? '',
      editedText: composedText,
      status: ReviewStatus.published,
      naverRegistered: true,
      naverRegisteredAt: DateTime.now(),
      naverPublishStatus: NaverPublishStatus.registered,
    );
  }

  @override
  Future<CustomerReview?> setReviewNaverPublishStatus({
    required String reviewId,
    required String status,
  }) async {
    final st = NaverPublishStatusX.fromDb(status);
    return CustomerReview(
      id: reviewId,
      chartId: 'chart-local',
      customerId: 'local',
      shopId: 'shop-demo',
      status: ReviewStatus.published,
      naverRegistered: st == NaverPublishStatus.registered ||
          st == NaverPublishStatus.confirmed,
      naverRegisteredAt: DateTime.now(),
      naverPublishStatus: st,
    );
  }

  static final List<ReviewRequestEvent> _reviewRequestEvents = [];

  @override
  Future<List<ReviewRequestEvent>> loadReviewRequestEvents({
    String? shopId,
    int limit = 80,
  }) async {
    var list = List<ReviewRequestEvent>.from(_reviewRequestEvents);
    final sid = (shopId ?? '').trim();
    if (sid.isNotEmpty) {
      list = list.where((e) => e.shopId == sid).toList();
    }
    list.sort((a, b) {
      final ad = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return list.take(limit).toList(growable: false);
  }

  @override
  Future<ReviewRequestEvent> insertReviewRequestEvent({
    required String customerId,
    String? chartId,
    String channel = 'qr',
    String? shopId,
    int remindHours = 24,
  }) async {
    final now = DateTime.now();
    final event = ReviewRequestEvent(
      id: 'rre-${_reviewRequestEvents.length + 1}',
      shopId: (shopId ?? 'shop-demo').trim().isEmpty
          ? 'shop-demo'
          : (shopId ?? 'shop-demo'),
      customerId: customerId,
      chartId: chartId,
      channel: ReviewRequestChannelX.fromDb(channel),
      status: ReviewRequestStatus.sent,
      sentAt: now,
      remindAt: now.add(Duration(hours: remindHours.clamp(1, 168))),
    );
    _reviewRequestEvents.insert(0, event);
    return event;
  }

  @override
  Future<int> convertReviewRequestEvents({
    required String customerId,
    required String reviewId,
    String? shopId,
  }) async {
    var n = 0;
    for (var i = 0; i < _reviewRequestEvents.length; i++) {
      final e = _reviewRequestEvents[i];
      if (e.customerId != customerId) continue;
      if (shopId != null &&
          shopId.isNotEmpty &&
          e.shopId != shopId) {
        continue;
      }
      if (!e.status.isOpen) continue;
      _reviewRequestEvents[i] = e.copyWith(
        status: ReviewRequestStatus.converted,
        convertedReviewId: reviewId,
      );
      n++;
    }
    return n;
  }

  @override
  Future<bool> markReviewRequestReminded(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return false;
    for (var i = 0; i < _reviewRequestEvents.length; i++) {
      final e = _reviewRequestEvents[i];
      if (e.id != id) continue;
      _reviewRequestEvents[i] = e.copyWith(remindedAt: DateTime.now());
      return true;
    }
    return false;
  }

  /// Test helper — clear in-memory request events.
  static void debugClearReviewRequestEvents() {
    _reviewRequestEvents.clear();
  }

  @override
  Future<AuthRoleResolution> resolveAuthRole(String userId) async {
    return const AuthRoleResolution.unknown();
  }

  @override
  Future<void> linkShopOwner({
    required String shopId,
    required String userId,
  }) async {}

  @override
  Future<void> linkCustomerUser({
    required String customerId,
    required String userId,
  }) async {}

  @override
  Future<void> upsertAuthProfile({
    required String userId,
    String name = '',
    String avatarUrl = '',
    String phone = '',
  }) async {}

  @override
  Future<List<ReviewReply>> loadReviewReplies(String reviewId) async {
    return const [];
  }

  @override
  Future<KakaoAlimtalkSendResult> sendKakaoAlimtalkMock({
    required String shopId,
    required String customerPhone,
    required String templateCode,
    required String content,
    int cost = KakaoAlimtalkPricing.sendCostPoint,
    int marginAmount = KakaoAlimtalkPricing.defaultMarginAmount,
  }) async {
    return KakaoAlimtalkSendResult.success(
      logId: 'local-${DateTime.now().millisecondsSinceEpoch}',
      remainingPoints: -1,
    );
  }

  @override
  Future<PublicCareReport?> loadPublicCareReport(String chartId) async {
    final snap = createSeedSnapshot();
    try {
      final chart = snap.charts.firstWhere((c) => c.id == chartId);
      String? customerName;
      for (final c in snap.customers) {
        if (c.id == chart.customerId) {
          customerName = c.name;
          break;
        }
      }
      return PublicCareReport(
        chart: chart,
        shop: snap.shop,
        customerDisplayName: customerName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Phase 10 — cold-start quality bar (mirrors 062 seed matrix).
  static List<CommunityCaseItem> _coldStartMasterCases() {
    const masters = <({
      String shopId,
      String shopName,
      String nick,
      String authorId,
    })>[
      (
        shopId: '00000000-0000-4000-8000-000000000101',
        shopName: '글로우핏 청담',
        nick: '서연',
        authorId: '00000000-0000-4000-8000-000000000201',
      ),
      (
        shopId: '00000000-0000-4000-8000-000000000102',
        shopName: '바디아틀리에 성수',
        nick: '준호',
        authorId: '00000000-0000-4000-8000-000000000202',
      ),
      (
        shopId: '00000000-0000-4000-8000-000000000103',
        shopName: '루미에르 한남',
        nick: '하늘',
        authorId: '00000000-0000-4000-8000-000000000203',
      ),
    ];
    const cares = [
      '리프팅 집중 케어',
      '윤곽 라인 케어',
      '홍조·장벽 진정',
      '첫방문 상담 케어',
      '복부 체형 케어',
      '셀룰라이트 집중',
      '부종·순환 케어',
      'EMS 바디 케어',
      '수분장벽 케어',
      '민감 진정 케어',
      '홈케어 미션 케어',
      '시즌 피부 케어',
    ];
    final now = DateTime.now();
    final out = <CommunityCaseItem>[];
    for (var i = 0; i < 12; i++) {
      final m = masters[i % 3];
      final day = i; // spread across 0..11 days ago
      final created = now.subtract(Duration(days: day, hours: 8 + (i % 5)));
      final chartId =
          '00000000-0000-4000-8000-0000000006${(i + 1).toRadixString(16).padLeft(2, '0')}';
      final shop = Shop(
        id: m.shopId,
        name: m.shopName,
        naverPlaceUrl: '',
        ownerName: m.nick,
        ownerUserId: m.authorId,
        profileImageUrl:
            'https://picsum.photos/seed/sori-shop-${m.nick}/200',
      );
      final hit = i < 3;
      out.add(
        CommunityCaseItem(
          chart: CustomerChart(
            id: chartId,
            shopId: m.shopId,
            customerId: 'seed-cust-$i',
            visitNumber: 1 + (i % 4),
            careName: cares[i],
            treatmentSummary: '${cares[i]} · 시드 퀄리티 바',
            directorInsight: '시드 표준 케이스 — 동일 각도 B/A와 기기명을 남기세요.',
            concernChips: [cares[i].split(' ').first],
            beforeImageUrl:
                'https://picsum.photos/seed/sori-seed-ba-${i + 1}b/600/800',
            afterImageUrl:
                'https://picsum.photos/seed/sori-seed-ba-${i + 1}a/600/800',
            signatureUrl: 'https://example.com/seed-sig-$i.png',
            consentPhoto: true,
            caseShared: true,
            deviceInfo: '시드 기기',
            feedAge: 30 + (i % 12),
            feedGenderLabel: '여성',
            authorId: m.authorId,
            visitCheckedAt: created,
            createdAt: created,
          ),
          shop: shop,
          authorNickname: m.nick,
          authorAvatarUrl:
              'https://picsum.photos/seed/sori-seed-avatar-${i % 3}/200',
          isBoosted: hit,
          boostSource: hit ? 'fan_boost' : 'shop_ad',
          boostEndsAt: hit ? now.add(const Duration(days: 5)) : null,
          fanDisplayName: hit ? '민지' : '',
          fanSupporters: hit
              ? [
                  const FanSupporterEntry(name: '민지', echoSpent: 300),
                  const FanSupporterEntry(name: '수아', echoSpent: 200),
                  const FanSupporterEntry(name: '도윤', echoSpent: 150),
                  const FanSupporterEntry(name: '하린', echoSpent: 100),
                ]
              : const [],
        ),
      );
    }
    return out;
  }

  @override
  Future<List<CommunityCaseItem>> loadCommunityHotCases({int limit = 40}) async {
    final snap = createSeedSnapshot();
    final byChartReview = <String, CustomerReview>{};
    for (final r in snap.reviews) {
      byChartReview[r.chartId] = r;
    }

    final partnerShop = const Shop(
      id: 'shop-gangnam-glow',
      name: '글로우핏 강남',
      ownerName: '이서연',
      naverPlaceUrl: 'https://m.place.naver.com/place/glow-demo',
    );
    final partnerChart = CustomerChart(
      id: 'chart-hot-1',
      shopId: partnerShop.id,
      customerId: 'hot-c1',
      visitNumber: 3,
      careName: '리프팅 집중 케어',
      treatmentSummary: '얼굴 라인 리프팅 · 탄력 집중',
      directorInsight: 'EMS + 림프 드레인 후 쿨링 마스크로 마무리하면 붓기 재발이 줄어요.',
      concernChips: const ['탄력/리프팅', '윤곽'],
      beforeImageUrl: 'https://picsum.photos/seed/sori-hot-b/600/800',
      afterImageUrl: 'https://picsum.photos/seed/sori-hot-a/600/800',
      signatureUrl: 'https://example.com/sig-hot.png',
      consentPhoto: true,
      caseShared: true,
      visitCheckedAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final partnerReview = CustomerReview(
      id: 'rev-hot-1',
      chartId: partnerChart.id,
      customerId: 'hot-c1',
      shopId: partnerShop.id,
      originalText: '라인 변화가 눈에 보여서 놀랐어요. 상담이 꼼꼼했습니다.',
      status: ReviewStatus.published,
      rating: 5,
      directorReply: '와주셔서 감사해요. 유지 케어만 잘 따라와 주세요!',
      directorRepliedAt: DateTime.now().subtract(const Duration(hours: 8)),
      acceptedAt: DateTime.now().subtract(const Duration(hours: 12)),
    );

    final byCustomer = {for (final c in snap.customers) c.id: c};
    final out = <CommunityCaseItem>[];
    for (final chart in snap.charts) {
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      final cust = byCustomer[chart.customerId];
      out.add(
        CommunityCaseItem(
          chart: chart.asPublicFeedProjection().copyWith(
            feedAge: cust?.koreanAge,
            feedGenderLabel: cust?.gender?.label,
            authorId: snap.shop.ownerUserId,
          ),
          shop: snap.shop,
          review: byChartReview[chart.id]?.copyWith(customerId: ''),
          customerAge: cust?.koreanAge,
          customerGenderLabel: cust?.gender?.label,
          authorNickname: snap.shop.ownerName?.trim() ?? '',
        ),
      );
    }
    out.add(
      CommunityCaseItem(
        chart: partnerChart.copyWith(
          skinSensitivity: '수부지',
          deviceInfo: 'EMS 리프팅',
          feedAge: 38,
          feedGenderLabel: '여성',
          authorId: 'member-therapist-1',
        ),
        shop: partnerShop,
        review: partnerReview,
        customerAge: 38,
        customerGenderLabel: '여성',
        authorNickname: '박지성',
        authorAvatarUrl: 'https://picsum.photos/seed/sori-member-avatar/200',
      ),
    );

    // Phase 10 cold-start pack — 12 ideal B/A spaced over ~14 days
    out.addAll(_coldStartMasterCases());

    // SORI Official seed (060) — badge smoke in memory feeds
    const officialShop = Shop(
      id: '00000000-0000-4000-8000-0000000000f1',
      name: 'SORI',
      naverPlaceUrl: '',
      ownerName: 'SORI',
      bio: '소통하는 리뷰 — SORI 공식 계정',
      isOfficial: true,
      slug: 'sori-official',
    );
    out.insert(
      0,
      CommunityCaseItem(
        chart: CustomerChart(
          id: 'chart-official-seed',
          shopId: officialShop.id,
          customerId: 'official-c0',
          visitNumber: 1,
          careName: 'SORI 공식 가이드',
          treatmentSummary: '플랫폼 공지·온보딩 가이드',
          directorInsight: '공식 계정은 Admin이 아닙니다.',
          concernChips: const ['공지'],
          beforeImageUrl: 'https://picsum.photos/seed/sori-official-b/600/800',
          afterImageUrl: 'https://picsum.photos/seed/sori-official-a/600/800',
          signatureUrl: 'https://example.com/sig-official.png',
          consentPhoto: true,
          caseShared: true,
          visitCheckedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        shop: officialShop,
      ),
    );
    final bodyShop = const Shop(
      id: 'shop-body-atelier',
      name: '바디아틀리에 청담',
      ownerName: '김하은',
      naverPlaceUrl: 'https://m.place.naver.com/place/body-demo',
    );
    out.add(
      CommunityCaseItem(
        chart: CustomerChart(
          id: 'chart-hot-2',
          shopId: bodyShop.id,
          customerId: 'hot-c2',
          visitNumber: 5,
          careName: '복부 체형 케어',
          treatmentSummary: '복부·옆구리 순환 집중 프로그램',
          directorInsight: '식후 2시간 뒤 림프 패들 + 온열 랩핑 조합이 붓기 해소에 효과적입니다.',
          concernChips: const ['바디 셀룰라이트', '복부', '부종/순환'],
          skinSensitivity: '중성',
          deviceInfo: '고주파 바디',
          feedAge: 42,
          feedGenderLabel: '여성',
          beforeImageUrl: 'https://picsum.photos/seed/sori-hot-body-b/600/800',
          afterImageUrl: 'https://picsum.photos/seed/sori-hot-body-a/600/800',
          signatureUrl: 'https://example.com/sig-hot-2.png',
          consentPhoto: true,
          caseShared: true,
          visitCheckedAt: DateTime.now().subtract(const Duration(days: 3)),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        shop: bodyShop,
        customerAge: 42,
        customerGenderLabel: '여성',
      ),
    );
    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out.take(limit).toList();
  }

  @override
  Future<List<ShopHighlight>> loadShopHighlights(String shopId) async {
    final id = shopId.trim().isEmpty ? 'shop-demo' : shopId.trim();
    return [
      ShopHighlight(
        id: 'hl-barrier',
        shopId: id,
        title: '장벽케어',
        coverImageUrl: 'https://picsum.photos/seed/sori-hl-barrier/400/400',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ShopHighlight(
        id: 'hl-lift',
        shopId: id,
        title: '리프팅',
        coverImageUrl: 'https://picsum.photos/seed/sori-hl-lift/400/400',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      ShopHighlight(
        id: 'hl-body',
        shopId: id,
        title: '바디',
        coverImageUrl: 'https://picsum.photos/seed/sori-hl-body/400/400',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      ShopHighlight(
        id: 'hl-daily',
        shopId: id,
        title: '일상',
        coverImageUrl: 'https://picsum.photos/seed/sori-hl-daily/400/400',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      ShopHighlight(
        id: 'hl-nova',
        shopId: id,
        title: '테라노바',
        coverImageUrl: 'https://picsum.photos/seed/sori-hl-nova/400/400',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];
  }

  @override
  Future<int> countShopFollowers(String shopId) async {
    final id = shopId.trim();
    final extra = _followersByShop[id]?.length ?? 0;
    return 128 + extra;
  }

  @override
  Future<bool> isShopFollowed({
    required String shopId,
    required String customerId,
  }) async {
    final set = _followersByShop[shopId.trim()];
    return set != null && set.contains(customerId.trim());
  }

  @override
  Future<void> setShopFollow({
    required String shopId,
    required String customerId,
    required bool following,
  }) async {
    final sid = shopId.trim();
    final cid = customerId.trim();
    if (sid.isEmpty || cid.isEmpty) return;
    final set = _followersByShop.putIfAbsent(sid, () => <String>{});
    if (following) {
      set.add(cid);
    } else {
      set.remove(cid);
    }
  }

  @override
  Future<List<Subscription>> loadMySubscriptions({int limit = 200}) async {
    // Memory: aggregate all users' subs for local UI; filter by caller later via store.
    final all = _subscriptionsByUser.values.expand((e) => e).toList();
    all.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return all.take(limit).toList();
  }

  @override
  Future<void> setSubscription({
    required SubscriptionTargetType targetType,
    String? targetShopId,
    String? targetUserId,
    required bool following,
    String source = 'discover',
  }) async {
    const uid = 'memory-user';
    final list = _subscriptionsByUser.putIfAbsent(uid, () => <Subscription>[]);
    if (!following) {
      list.removeWhere((s) {
        if (targetType == SubscriptionTargetType.shop) {
          return s.targetType == SubscriptionTargetType.shop &&
              s.targetShopId == targetShopId;
        }
        return s.targetType == SubscriptionTargetType.director &&
            s.targetUserId == targetUserId;
      });
      return;
    }
    final exists = list.any((s) {
      if (targetType == SubscriptionTargetType.shop) {
        return s.targetType == SubscriptionTargetType.shop &&
            s.targetShopId == targetShopId;
      }
      return s.targetType == SubscriptionTargetType.director &&
          s.targetUserId == targetUserId;
    });
    if (exists) return;
    list.add(
      Subscription(
        id: 'sub-${list.length + 1}',
        followerUserId: uid,
        targetType: targetType,
        targetShopId: targetShopId,
        targetUserId: targetUserId,
        source: source,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<CommunityPost>> loadFollowingFeed({int limit = 40}) async {
    final subs = await loadMySubscriptions();
    if (subs.isEmpty) return const [];
    final shopIds = subs
        .where((s) => s.targetType == SubscriptionTargetType.shop)
        .map((s) => s.targetShopId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final directorIds = subs
        .where((s) => s.targetType == SubscriptionTargetType.director)
        .map((s) => s.targetUserId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final posts = await loadCommunityPosts(limit: 80);
    return posts
        .where(
          (p) =>
              shopIds.contains(p.shopId) ||
              directorIds.contains(p.authorUserId ?? ''),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<DiscoverDirector>> loadDiscoverDirectors({
    int limit = 40,
    String query = '',
  }) async {
    final q = query.trim().toLowerCase();
    final masters = <DiscoverDirector>[
      const DiscoverDirector(
        shopId: '00000000-0000-4000-8000-000000000101',
        shopName: '글로우핏 청담',
        nickname: '서연',
        ownerUserId: '00000000-0000-4000-8000-000000000201',
        avatarUrl: 'https://picsum.photos/seed/sori-seed-avatar-1/200',
        address: '서울 강남구 청담동',
        bio: '페이스·리프팅 전문',
        followerCount: 1280,
        sharedCaseCount: 48,
        isSeed: true,
      ),
      const DiscoverDirector(
        shopId: '00000000-0000-4000-8000-000000000102',
        shopName: '바디아틀리에 성수',
        nickname: '준호',
        ownerUserId: '00000000-0000-4000-8000-000000000202',
        avatarUrl: 'https://picsum.photos/seed/sori-seed-avatar-2/200',
        address: '서울 성동구 성수동',
        bio: '바디·순환 전문',
        followerCount: 940,
        sharedCaseCount: 36,
        isSeed: true,
      ),
      const DiscoverDirector(
        shopId: '00000000-0000-4000-8000-000000000103',
        shopName: '루미에르 한남',
        nickname: '하늘',
        ownerUserId: '00000000-0000-4000-8000-000000000203',
        avatarUrl: 'https://picsum.photos/seed/sori-seed-avatar-3/200',
        address: '서울 용산구 한남동',
        bio: '피부·장벽 전문',
        followerCount: 1120,
        sharedCaseCount: 41,
        isSeed: true,
      ),
      const DiscoverDirector(
        shopId: 'shop-gangnam-glow',
        shopName: '글로우핏 강남',
        nickname: '이서연',
        ownerUserId: 'member-therapist-1',
        avatarUrl: 'https://picsum.photos/seed/sori-member-avatar/200',
        address: '서울 강남구',
        followerCount: 320,
        sharedCaseCount: 12,
      ),
      const DiscoverDirector(
        shopId: 'shop-body-atelier',
        shopName: '바디아틀리에 청담',
        nickname: '김하은',
        avatarUrl: 'https://picsum.photos/seed/sori-body-avatar/200',
        address: '서울 강남구 청담동',
        followerCount: 210,
        sharedCaseCount: 8,
      ),
    ];
    final filtered = q.isEmpty
        ? masters
        : masters
            .where(
              (d) =>
                  d.nickname.toLowerCase().contains(q) ||
                  d.shopName.toLowerCase().contains(q) ||
                  d.address.toLowerCase().contains(q),
            )
            .toList();
    return filtered.take(limit).toList();
  }

  Map<String, int> _resolveAudience(WhisperAudienceSpec spec) {
    const sender = 'memory-sender';
    final bits = <String, int>{};
    void add(String uid, int bit) {
      if (uid.isEmpty || uid == sender) return;
      bits[uid] = (bits[uid] ?? 0) | bit;
    }

    final atoms = spec.atoms.toSet();
    if (atoms.contains(WhisperAtoms.everyone)) {
      for (final uid in _seedRoles.keys) {
        add(uid, 32);
      }
    }
    if (atoms.contains(WhisperAtoms.visited)) {
      for (final u in _seedVisited) {
        add(u, 1);
      }
    }
    if (atoms.contains(WhisperAtoms.followers)) {
      for (final u in _seedFollowersOfSender) {
        add(u, 2);
      }
    }
    if (atoms.contains(WhisperAtoms.peerDirectors)) {
      for (final u in _seedFollowersOfSender) {
        if (_seedRoles[u] == 'director') add(u, 4);
      }
    }
    if (atoms.contains(WhisperAtoms.superFans)) {
      for (final u in _seedSuperFans) {
        add(u, 8);
      }
    }
    if (atoms.contains(WhisperAtoms.seminarHosts)) {
      for (final e in _seedRoles.entries) {
        if (e.value == 'director' && e.key != sender) {
          add(e.key, 64);
        }
      }
    }
    if (atoms.contains(WhisperAtoms.customerMode)) {
      for (final e in _seedRoles.entries) {
        if (e.value == 'customer' && e.key != sender) {
          if (!_seedVisited.contains(e.key)) {
            add(e.key, 128);
          }
        }
      }
    }
    if (atoms.contains(WhisperAtoms.explicit)) {
      for (final u in spec.explicitUserIds) {
        add(u.trim(), 16);
      }
    }

    if (spec.op == 'intersect') {
      bits.removeWhere((uid, b) {
        if (atoms.contains(WhisperAtoms.everyone) && (b & 32) == 0) return true;
        if (atoms.contains(WhisperAtoms.visited) && (b & 1) == 0) return true;
        if (atoms.contains(WhisperAtoms.followers) && (b & 2) == 0) return true;
        if (atoms.contains(WhisperAtoms.peerDirectors) && (b & 4) == 0) {
          return true;
        }
        if (atoms.contains(WhisperAtoms.superFans) && (b & 8) == 0) return true;
        if (atoms.contains(WhisperAtoms.explicit) && (b & 16) == 0) return true;
        if (atoms.contains(WhisperAtoms.seminarHosts) && (b & 64) == 0) return true;
        if (atoms.contains(WhisperAtoms.customerMode) && (b & 128) == 0) return true;
        return false;
      });
    }
    return bits;
  }

  @override
  Future<WhisperAudiencePreview> previewWhisperAudience(
    WhisperAudienceSpec spec,
  ) async {
    final bits = _resolveAudience(spec);
    final people = bits.entries.take(12).map((e) {
      return WhisperPreviewPerson(
        userId: e.key,
        nickname: e.key.startsWith('peer') ? '동료원장' : '팬',
        atomBits: e.value,
      );
    }).toList();
    return WhisperAudiencePreview(
      count: bits.length,
      preview: people,
      op: spec.op,
      atoms: spec.atoms,
    );
  }

  @override
  Future<WhisperSendResult> sendWhisper({
    required String body,
    required WhisperAudienceSpec spec,
  }) async {
    final text = body.trim();
    if (text.isEmpty) throw StateError('body required');
    if (spec.atoms.isEmpty) throw StateError('atoms required');
    final bits = _resolveAudience(spec);
    if (bits.isEmpty) throw StateError('no recipients matched');
    final id = 'cp-whisper-${_communityPosts.length + 1}';
    _communityPosts.insert(
      0,
      CommunityPost(
        id: id,
        shopId: spec.shopId ?? 'shop-demo',
        authorUserId: 'memory-sender',
        postType: CommunityPostType.caseShare,
        body: text,
        isWhisper: true,
        audienceOp: spec.op,
        whisperRecipientCount: bits.length,
        shopName: 'SORI 에스테틱',
        shopOwnerName: '김원장',
        createdAt: DateTime.now(),
      ),
    );
    for (final e in bits.entries) {
      _whisperRecipients.add(
        _MemWhisperRecipient(
          postId: id,
          userId: e.key,
          atomBits: e.value,
        ),
      );
    }
    return WhisperSendResult(
      postId: id,
      recipientCount: bits.length,
    );
  }

  @override
  Future<List<WhisperAudiencePreset>> loadWhisperPresets() async {
    return List.unmodifiable(_whisperPresets);
  }

  @override
  Future<WhisperAudiencePreset> saveWhisperPreset({
    required String name,
    required WhisperAudienceSpec spec,
  }) async {
    final p = WhisperAudiencePreset(
      id: 'preset-${_whisperPresets.length + 1}',
      name: name.trim().isEmpty ? '나의 그룹' : name.trim(),
      spec: spec,
      op: spec.op,
    );
    _whisperPresets.insert(0, p);
    return p;
  }

  @override
  Future<void> deleteWhisperPreset(String presetId) async {
    _whisperPresets.removeWhere((e) => e.id == presetId);
  }

  /// Test helper — recipients for a whisper post id.
  static List<String> debugWhisperRecipientIds(String postId) {
    return _whisperRecipients
        .where((r) => r.postId == postId)
        .map((r) => r.userId)
        .toList();
  }

  static int debugWhisperAtomBits(String postId, String userId) {
    for (final r in _whisperRecipients) {
      if (r.postId == postId && r.userId == userId) return r.atomBits;
    }
    return 0;
  }

  @override
  Future<List<CaseTimelineEntry>> loadCaseTimelineGroup(String chartId) async {
    final snap = createSeedSnapshot();
    CustomerChart? anchor;
    for (final c in snap.charts) {
      if (c.id == chartId) {
        anchor = c;
        break;
      }
    }
    if (anchor == null) return const [];

    final tags = anchor.careTags.toSet();
    final out = <CaseTimelineEntry>[];
    for (final c in snap.charts) {
      if (c.customerId != anchor.customerId || c.shopId != anchor.shopId) {
        continue;
      }
      if (!c.caseShared) continue;
      final overlap = tags.isEmpty ||
          c.careTags.any(tags.contains) ||
          c.id == chartId;
      if (!overlap) continue;
      out.add(
        CaseTimelineEntry(
          chartId: c.id,
          visitNumber: c.visitNumber,
          careName: c.careName,
          beforeImageUrl: c.beforeImageUrl,
          afterImageUrl: c.afterImageUrl,
          careTags: c.careTags,
          createdAt: c.createdAt,
        ),
      );
    }
    out.sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
    return out;
  }

  @override
  Future<int> insertSeminarRequest({
    required String caseId,
    String? requestorShopId,
    String? requestorUserId,
  }) async {
    final key = caseId.trim();
    final shop = requestorShopId?.trim() ?? '';
    final user = requestorUserId?.trim() ?? '';
    if (key.isEmpty) return 0;
    final token = shop.isNotEmpty ? 'shop:$shop' : 'user:$user';
    if (token == 'shop:' || token == 'user:') return 0;
    _seminarRequestsByCase.putIfAbsent(key, () => <String>{}).add(token);

    final snap = createSeedSnapshot();
    final ownerShopId = snap.charts
        .where((c) => c.id == key)
        .map((c) => c.shopId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    if (ownerShopId == null || ownerShopId.isEmpty) {
      return _seminarRequestsByCase[key]?.length ?? 0;
    }
    var total = 0;
    final myChartIds =
        snap.charts.where((c) => c.shopId == ownerShopId).map((c) => c.id);
    for (final id in myChartIds) {
      total += _seminarRequestsByCase[id]?.length ?? 0;
    }
    return total;
  }

  @override
  Future<SeminarEducationInsight> loadSeminarEducationInsight(
    String directorShopId,
  ) async {
    final snap = createSeedSnapshot();
    final myChartIds = snap.charts
        .where((c) => c.shopId == directorShopId)
        .map((c) => c.id)
        .toSet();
    final byCase = <String, int>{};
    for (final entry in _seminarRequestsByCase.entries) {
      if (!myChartIds.contains(entry.key)) continue;
      byCase[entry.key] = entry.value.length;
    }
    return SeminarEducationInsight(
      totalRequests: byCase.values.fold(0, (a, b) => a + b),
      requestsByCase: byCase,
      soriCashBalance: _shopCashBalance[directorShopId] ?? 0,
      tierBadgeLabel: snap.shop.tierBadge.dbValue,
      totalSeminarCount: snap.shop.totalSeminarCount,
      totalFundingAmount: snap.shop.totalFundingAmount,
      totalLikes: snap.shop.totalLikes,
      sharedCaseCount: snap.shop.sharedCaseCount,
      seminarRequestCount: snap.shop.seminarRequestCount,
      completedSeminarCount: snap.shop.completedSeminarCount,
      followerCount: snap.shop.followerCount,
    );
  }

  @override
  Future<SeminarClass> createSeminarClass(SeminarClass draft) async {
    _seminarClassSeq++;
    final created = SeminarClass(
      id: 'sem-local-$_seminarClassSeq',
      directorShopId: draft.directorShopId,
      targetCaseId: draft.targetCaseId,
      title: draft.title,
      eventDate: draft.eventDate,
      location: draft.location,
      price: draft.price,
      maxCapacity: draft.maxCapacity,
      status: draft.status,
      description: draft.description,
      classFormat: draft.classFormat,
      createdAt: DateTime.now(),
    );
    _seminarClasses.add(created);
    return created;
  }

  static final List<SeminarApplication> _seminarApplications = [];

  @override
  Future<SeminarApplication> submitSeminarApplication(
    SeminarApplication draft,
  ) async {
    final created = SeminarApplication(
      id: 'sapp-local-${_seminarApplications.length + 1}',
      classId: draft.classId,
      applicantShopId: draft.applicantShopId,
      applicantUserId: draft.applicantUserId,
      applicantName: draft.applicantName,
      shopName: draft.shopName,
      contactPhone: draft.contactPhone,
      careerType: draft.careerType,
      question: draft.question,
      refundAgreed: draft.refundAgreed,
      status: 'submitted',
      createdAt: DateTime.now(),
    );
    _seminarApplications.add(created);
    return created;
  }

  @override
  Future<SeminarClassDetail?> loadSeminarClassDetail(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) return null;

    SeminarClass? cls;
    for (final item in _seminarClasses) {
      if (item.id == id) {
        cls = item;
        break;
      }
    }
    if (cls == null) return null;

    final snap = createSeedSnapshot();
    final shop = snap.shop.id == cls.directorShopId
        ? snap.shop
        : snap.shop.copyWith(id: cls.directorShopId);

    CustomerChart? chart;
    final caseId = cls.targetCaseId?.trim();
    if (caseId != null && caseId.isNotEmpty) {
      for (final c in snap.charts) {
        if (c.id == caseId) {
          chart = c;
          break;
        }
      }
    }

    return SeminarClassDetail(
      seminarClass: cls,
      directorShop: shop,
      targetChart: chart,
    );
  }

  @override
  Future<String> enrollSeminarClass({
    required String classId,
    required String enrollorShopId,
  }) async {
    final id = classId.trim();
    final idx = _seminarClasses.indexWhere((c) => c.id == id);
    if (idx < 0) {
      throw StateError('class not found');
    }
    final cls = _seminarClasses[idx];
    if (!cls.isEnrollable) {
      throw StateError('class not enrollable');
    }
    if (cls.currentEnrollment >= cls.maxCapacity) {
      throw StateError('class full');
    }

    final nextEnrollment = cls.currentEnrollment + 1;
    _seminarClasses[idx] = cls.copyWith(
      currentEnrollment: nextEnrollment,
      status: nextEnrollment >= cls.maxCapacity
          ? SeminarClassStatus.held
          : cls.status,
    );

    _enrollmentSeq++;
    final enrollId = 'enroll-local-$_enrollmentSeq';
    _enrollments.add({
      'id': enrollId,
      'class_id': id,
      'enrollor_shop_id': enrollorShopId.trim(),
      'amount': cls.price,
      'status': 'held',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return enrollId;
  }

  static double _platformFeePct(ShopTierBadge tier) => tier.platformFeePct;

  @override
  Future<List<SeminarEnrollment>> loadMySeminarEnrollments(
    String enrollorShopId,
  ) async {
    final sid = enrollorShopId.trim();
    final out = <SeminarEnrollment>[];
    for (final raw in _enrollments) {
      if (DbMap.asText(raw['enrollor_shop_id']) != sid) continue;
      final classId = DbMap.asText(raw['class_id']);
      SeminarClass? cls;
      for (final c in _seminarClasses) {
        if (c.id == classId) {
          cls = c;
          break;
        }
      }
      out.add(
        SeminarEnrollment.fromMap({
          ...raw,
          if (cls != null)
            'seminar_classes': {
              'id': cls.id,
              'title': cls.title,
              'event_date': cls.eventDate?.toUtc().toIso8601String(),
            },
        }),
      );
    }
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  @override
  Future<void> submitSeminarEnrollmentReview({
    required String enrollmentId,
    required List<String> insightTags,
    String comment = '',
  }) async {
    final id = enrollmentId.trim();
    if (id.isEmpty) throw ArgumentError('enrollmentId required');
    final tags = insightTags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (tags.isEmpty) throw StateError('at least one insight tag required');

    final exists = _enrollments.any((e) => DbMap.asText(e['id']) == id);
    if (!exists) throw StateError('enrollment not found');

    _enrollmentReviews[id] = {
      'enrollment_id': id,
      'insight_tags': tags,
      'comment': comment.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final classId = DbMap.asText(
      _enrollments.firstWhere((e) => DbMap.asText(e['id']) == id)['class_id'],
    );
    await refreshSeminarFeedbackReport(classId);
  }

  @override
  Future<int> settleSeminarEnrollment(String enrollmentId) async {
    final id = enrollmentId.trim();
    final idx = _enrollments.indexWhere((e) => DbMap.asText(e['id']) == id);
    if (idx < 0) throw StateError('enrollment not found');
    if (_enrollmentReviews[id] == null) {
      throw StateError('review required before settlement');
    }

    final row = _enrollments[idx];
    if (DbMap.asText(row['status']) != 'held') {
      throw StateError('enrollment not in held status');
    }

    final classId = DbMap.asText(row['class_id']);
    SeminarClass? cls;
    for (final c in _seminarClasses) {
      if (c.id == classId) {
        cls = c;
        break;
      }
    }
    if (cls == null) throw StateError('class not found');

    final snap = createSeedSnapshot();
    final directorShop = snap.shop.id == cls.directorShopId
        ? snap.shop
        : snap.shop.copyWith(id: cls.directorShopId);

    final feePct = _platformFeePct(directorShop.tierBadge);
    final amount = DbMap.asInt(row['amount']);
    final net = (amount * (1 - feePct)).floor();

    _enrollments[idx] = {
      ...row,
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    _shopCashBalance[cls.directorShopId] =
        (_shopCashBalance[cls.directorShopId] ?? 0) + net;

    await refreshSeminarFeedbackReport(classId);

    return net;
  }

  void _ensureDemoFeedbackReports() {
    if (_seededDemoFeedback) return;
    _seededDemoFeedback = true;
    final snap = createSeedSnapshot();
    _feedbackReports.add({
      'id': 'feedback-demo-1',
      'class_id': 'class-demo-1',
      'shop_id': snap.shop.id,
      'class_title': '재생케어 관리 마스터 클래스',
      'event_date': DateTime(2026, 7, 12).toUtc().toIso8601String(),
      'completed_enrollment_count': 8,
      'top_insight_tags': [
        '#이해쏙쏙',
        '#실무적용도100%',
        '#케이스분석탁월',
      ],
      'ai_summary_strength':
          '수강생 8명의 피드백에서 #이해쏙쏙, #실무적용도100% 인사이트가 두드러졌습니다. '
          '현장 설명력과 관리 케이스 전달력이 높게 평가됐습니다.',
      'ai_summary_improvement':
          '다음 기수에서는 Q&A·실습 비중을 15~20% 늘리고, 초급·중급 맞춤 블록을 분리하면 '
          '만족도가 더 올라갈 것으로 보입니다.',
      'raw_feedback_count': 8,
      'positive_comments': [
        'Before/After 비교 설명이 현장에서 바로 써먹을 수 있었어요.',
        '케이스 흐름이 논리적이라 메모하기 좋았습니다.',
      ],
      'created_at': DateTime(2026, 7, 15).toUtc().toIso8601String(),
      'updated_at': DateTime(2026, 7, 15).toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> refreshSeminarFeedbackReport(String classId) async {
    final cid = classId.trim();
    if (cid.isEmpty) return;

    SeminarClass? cls;
    for (final c in _seminarClasses) {
      if (c.id == cid) {
        cls = c;
        break;
      }
    }
    if (cls == null) return;

    final tagCounts = <String, int>{};
    final comments = <String>[];
    var reviewCount = 0;
    var completedCount = 0;

    for (final row in _enrollments) {
      if (DbMap.asText(row['class_id']) != cid) continue;
      if (DbMap.asText(row['status']) == 'completed') {
        completedCount++;
      }
      final enrollId = DbMap.asText(row['id']);
      final review = _enrollmentReviews[enrollId];
      if (review == null) continue;
      reviewCount++;
      final tags = review['insight_tags'];
      if (tags is List) {
        for (final t in tags) {
          final tag = t.toString().trim();
          if (tag.isEmpty) continue;
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      final comment = DbMap.asText(review['comment']);
      if (comment.isNotEmpty) comments.add(comment);
    }

    if (reviewCount < 1) return;

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sortedTags.map((e) => e.key).take(8).toList();
    final top1 = topTags.isNotEmpty ? topTags.first : '#이해쏙쏙';
    final top2 = topTags.length > 1 ? topTags[1] : '#실무적용도100%';

    final report = {
      'id': 'feedback-$cid',
      'class_id': cid,
      'shop_id': cls.directorShopId,
      'class_title': cls.title,
      'event_date': cls.eventDate?.toUtc().toIso8601String(),
      'completed_enrollment_count':
          completedCount > 0 ? completedCount : reviewCount,
      'top_insight_tags': topTags,
      'ai_summary_strength':
          '수강생 $reviewCount명의 피드백에서 $top1, $top2 인사이트가 두드러졌습니다. '
          '현장 설명력과 관리 케이스 전달력이 높게 평가됐습니다.',
      'ai_summary_improvement':
          '다음 기수에서는 Q&A·실습 비중을 늘리고, 초급·중급 맞춤 블록을 분리하면 '
          '만족도가 더 올라갈 것으로 보입니다.',
      'raw_feedback_count': reviewCount,
      'positive_comments': comments,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final idx = _feedbackReports.indexWhere(
      (r) => DbMap.asText(r['class_id']) == cid,
    );
    if (idx >= 0) {
      report['id'] = _feedbackReports[idx]['id'];
      report['created_at'] = _feedbackReports[idx]['created_at'];
      _feedbackReports[idx] = report;
    } else {
      _feedbackReports.add(report);
    }
  }

  @override
  Future<List<SeminarFeedbackReport>> loadSeminarFeedbackReports(
    String shopId,
  ) async {
    _ensureDemoFeedbackReports();
    final sid = shopId.trim();
    return _feedbackReports
        .where((r) => DbMap.asText(r['shop_id']) == sid)
        .map((r) => SeminarFeedbackReport.fromMap(r))
        .toList()
      ..sort((a, b) {
        final ad = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
  }

  @override
  Future<SeminarFeedbackReport?> loadSeminarFeedbackReportDetail(
    String reportId,
  ) async {
    _ensureDemoFeedbackReports();
    final id = reportId.trim();
    for (final r in _feedbackReports) {
      if (DbMap.asText(r['id']) == id) {
        return SeminarFeedbackReport.fromMap(r);
      }
    }
    return null;
  }

  static final List<ShopGallerySlide> _gallery = [];
  static final List<ShopPost> _posts = [];

  @override
  Future<List<ShopGallerySlide>> loadShopGalleryItems(String shopId) async =>
      List.unmodifiable(_gallery);

  @override
  Future<ShopGallerySlide> insertShopGalleryItem({
    required String shopId,
    required String imageUrl,
    String title = '',
  }) async {
    if (_gallery.length >= 20) {
      throw StateError('샵 갤러리는 최대 20장까지 등록할 수 있습니다.');
    }
    final slide = ShopGallerySlide(
      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? '갤러리' : title.trim(),
      subtitle: '',
      kind: GalleryKind.shop,
      imageUrl: imageUrl,
      sortOrder: _gallery.length,
    );
    _gallery.add(slide);
    return slide;
  }

  @override
  Future<void> deleteShopGalleryItem(String itemId) async {
    _gallery.removeWhere((e) => e.id == itemId);
  }

  @override
  Future<List<ShopPost>> loadShopPosts(String shopId) async =>
      List.unmodifiable(_posts);

  @override
  Future<ShopPost> insertShopPost({
    required String shopId,
    required String body,
    String? authorUserId,
    List<String> imageUrls = const [],
    String postKind = 'note',
    String? seminarClassId,
  }) async {
    final post = ShopPost(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      authorUserId: authorUserId,
      body: body.trim(),
      imageUrls: imageUrls,
      postKind: postKind,
      seminarClassId: seminarClassId,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return post;
  }

  static final List<CommunityPost> _communityPosts = [];
  static final List<CommunityComment> _communityCommentsFlat = [];
  static final List<AffiliateCommission> _affiliateCommissions = [];
  static final List<AffiliateConversion> _affiliateConversions = [];
  static final Map<String, SoriPointWallet> _wallets = {};
  static final Map<String, SoriPointWallet> _customerWallets = {};
  static final List<PointTransaction> _pointTx = [];
  static final List<SettlementTransaction> _settlementTx = [];
  static final List<BoostPlacement> _boosts = [];
  static final List<PremiumOverlay> _premiumOverlays = [];
  static final List<Map<String, dynamic>> _shopNotifications = [];
  static final Set<String> _unlocks = {};
  static int _affiliateClicks = 0;

  /// 테스트 격리 — Fan-Boost / 알림 정적 상태 초기화.
  static void resetFanBoostStateForTest() {
    _boosts.clear();
    _premiumOverlays.clear();
    _shopNotifications.clear();
  }

  @override
  Future<void> deleteShopPost(String postId) async {
    _posts.removeWhere((e) => e.id == postId);
  }

  @override
  Future<List<CommunityPost>> loadCommunityPosts({
    CommunityPostType? type,
    int limit = 40,
  }) async {
    const viewer = 'memory-sender';
    var list = List<CommunityPost>.from(_communityPosts);
    list = list.where((p) {
      if (!p.isWhisper) return true;
      if (p.authorUserId == viewer) return true;
      return _whisperRecipients.any(
        (r) => r.postId == p.id && r.userId == viewer,
      );
    }).toList();
    if (type != null) {
      list = list.where((e) => e.postType == type && !e.isWhisper).toList();
    }
    return list.take(limit).toList(growable: false);
  }

  @override
  Future<CommunityPost> insertCommunityPost({
    required String shopId,
    required CommunityPostType postType,
    required String body,
    String title = '',
    String? authorUserId,
    List<String> imageUrls = const [],
    List<String> styleTags = const [],
    List<CommunityTagDraft> tagDrafts = const [],
    DeviceReviewDraft? deviceReview,
    MarketListingDraft? marketListing,
    CommunityVisibility visibility = CommunityVisibility.public,
    String? sourceChartId,
  }) async {
    final id = 'cp-${DateTime.now().millisecondsSinceEpoch}';
    final media = <CommunityPostMedia>[
      for (var i = 0; i < imageUrls.length; i++)
        CommunityPostMedia(
          id: '$id-m$i',
          postId: id,
          imageUrl: imageUrls[i],
          sortOrder: i,
        ),
    ];
    final tags = <CommunityPostTag>[
      for (final d in tagDrafts)
        if (d.mediaIndex >= 0 &&
            d.mediaIndex < media.length &&
            d.label.trim().isNotEmpty)
          CommunityPostTag(
            id: '$id-t${d.mediaIndex}-${d.label.hashCode}',
            mediaId: media[d.mediaIndex].id,
            label: d.label.trim(),
            tagKind: d.tagKind,
            normX: d.normX,
            normY: d.normY,
            vendorName: d.vendorName,
            externalUrl:
                d.externalUrl.trim().isEmpty ? null : d.externalUrl.trim(),
          ),
    ];
    DeviceReview? review;
    if (deviceReview != null && deviceReview.deviceName.trim().isNotEmpty) {
      review = DeviceReview(
        postId: id,
        deviceName: deviceReview.deviceName,
        brand: deviceReview.brand,
        model: deviceReview.model,
        usageMonths: deviceReview.usageMonths,
        rating: deviceReview.rating,
        pros: deviceReview.pros,
        cons: deviceReview.cons,
        wouldRecommend: deviceReview.wouldRecommend,
      );
    }
    MarketListing? listing;
    if (marketListing != null && marketListing.deviceName.trim().isNotEmpty) {
      listing = MarketListing(
        id: '$id-listing',
        postId: id,
        shopId: shopId,
        deviceName: marketListing.deviceName,
        brand: marketListing.brand,
        price: marketListing.price,
        condition: marketListing.condition,
        status: marketListing.status,
        contactPhone: marketListing.contactPhone.trim().isEmpty
            ? null
            : marketListing.contactPhone.trim(),
        contactNote: marketListing.contactNote,
      );
    }
    final post = CommunityPost(
      id: id,
      shopId: shopId,
      authorUserId: authorUserId,
      postType: postType,
      title: title,
      body: body.trim(),
      styleTags: styleTags,
      media: media,
      tags: tags,
      listing: listing,
      deviceReview: review,
      shopName: 'SORI 에스테틱',
      shopOwnerName: '김원장',
      tierBadge: ShopTierBadge.silver,
      businessVerified: true,
      visibility: visibility,
      sourceChartId: sourceChartId,
      createdAt: DateTime.now(),
    );
    _communityPosts.insert(0, post);
    return post;
  }

  @override
  Future<void> updateMarketListingStatus({
    required String listingId,
    required MarketListingStatus status,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) return;
    for (var i = 0; i < _communityPosts.length; i++) {
      final p = _communityPosts[i];
      final l = p.listing;
      if (l == null || l.id != id) continue;
      _communityPosts[i] = p.copyWith(listing: l.copyWith(status: status));
      break;
    }
  }

  @override
  Future<Map<String, bool>> loadShopBusinessVerified(
    List<String> shopIds,
  ) async {
    return {for (final id in shopIds) id: true};
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    _communityPosts.removeWhere((e) => e.id == postId);
    _communityCommentsFlat.removeWhere((e) => e.postId == postId);
  }

  @override
  Future<List<CommunityComment>> loadCommunityComments(String postId) async {
    final flat =
        _communityCommentsFlat.where((c) => c.postId == postId).toList();
    return CommunityComment.nest(flat);
  }

  @override
  Future<CommunityComment> insertCommunityComment({
    required String postId,
    required String content,
    String? authorUserId,
    String? authorShopId,
    String? parentId,
  }) async {
    final c = CommunityComment(
      id: 'cc-${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      content: content.trim(),
      authorUserId: authorUserId,
      authorShopId: authorShopId,
      parentId: parentId,
      authorName: '김원장',
      authorShopName: 'SORI 에스테틱',
      createdAt: DateTime.now(),
    );
    _communityCommentsFlat.add(c);
    return c;
  }

  @override
  Future<void> trackAffiliateClick({
    required String shopId,
    required String destinationUrl,
    String label = '',
    String? postId,
    String? postTagId,
    String? partnerId,
    String? clickedByUserId,
    String? clickedByShopId,
    int commissionPerClick = 500,
  }) async {
    _affiliateClicks += 1;
    _affiliateCommissions.insert(
      0,
      AffiliateCommission(
        id: 'ac-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        linkId: 'alink',
        amount: commissionPerClick,
        status: 'pending',
        createdAt: DateTime.now(),
        linkLabel: label,
        destinationUrl: destinationUrl,
      ),
    );
  }

  @override
  Future<AffiliateEarningsSummary> loadAffiliateEarnings(String shopId) async {
    final list =
        _affiliateCommissions.where((c) => c.shopId == shopId).toList();
    var pending = 0;
    var confirmed = 0;
    var paid = 0;
    for (final c in list) {
      switch (c.status) {
        case 'confirmed':
          confirmed += c.amount;
        case 'paid':
          paid += c.amount;
        default:
          pending += c.amount;
      }
    }
    final conversions =
        _affiliateConversions.where((c) => c.shopId == shopId).toList();
    return AffiliateEarningsSummary(
      clickCount: _affiliateClicks,
      pendingAmount: pending,
      confirmedAmount: confirmed,
      paidAmount: paid,
      recentCommissions: list.take(20).toList(),
      recentConversions: conversions.take(20).toList(),
    );
  }

  @override
  Future<CommunityPost?> saveChartAndPublishCase({
    required String chartId,
    required String shopId,
    bool publish = true,
    String? title,
    String? body,
    List<String> imageUrls = const [],
    String? authorUserId,
  }) async {
    if (!publish) return null;
    for (final p in _communityPosts) {
      if (p.sourceChartId == chartId &&
          p.postType == CommunityPostType.caseShare) {
        return p;
      }
    }
    return insertCommunityPost(
      shopId: shopId,
      postType: CommunityPostType.caseShare,
      title: title ?? '임상 케이스',
      body: body ?? '임상 기록 공유',
      imageUrls: imageUrls,
      authorUserId: authorUserId,
      styleTags: const ['케이스공유', '비식별'],
      sourceChartId: chartId,
    );
  }

  @override
  Future<AffiliateConversion?> recordAffiliateConversion({
    required String shopId,
    required int commissionAmount,
    String orderRef = '',
    int grossAmount = 0,
    String? linkId,
    String? clickId,
    String? postId,
    String note = '',
  }) async {
    final c = AffiliateConversion(
      id: 'aconv-${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      commissionAmount: commissionAmount,
      orderRef: orderRef,
      grossAmount: grossAmount,
      linkId: linkId,
      clickId: clickId,
      postId: postId,
      note: note,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _affiliateConversions.insert(0, c);
    return c;
  }

  @override
  Future<AffiliateConversion?> settleAffiliateConversion({
    required String conversionId,
    required String toStatus,
    String? actorUserId,
  }) async {
    final i = _affiliateConversions.indexWhere((c) => c.id == conversionId);
    if (i < 0) return null;
    final prev = _affiliateConversions[i];
    final next = AffiliateConversion(
      id: prev.id,
      shopId: prev.shopId,
      linkId: prev.linkId,
      clickId: prev.clickId,
      commissionId: prev.commissionId,
      postId: prev.postId,
      orderRef: prev.orderRef,
      grossAmount: prev.grossAmount,
      commissionAmount: prev.commissionAmount,
      status: toStatus,
      note: prev.note,
      createdAt: prev.createdAt,
      confirmedAt: toStatus == 'confirmed' ? DateTime.now() : prev.confirmedAt,
      paidAt: toStatus == 'paid' ? DateTime.now() : prev.paidAt,
    );
    _affiliateConversions[i] = next;
    if (toStatus == 'confirmed' || toStatus == 'paid') {
      _affiliateCommissions.insert(
        0,
        AffiliateCommission(
          id: 'ac-${DateTime.now().millisecondsSinceEpoch}',
          shopId: next.shopId,
          linkId: next.linkId ?? 'alink',
          amount: next.commissionAmount,
          status: toStatus,
          createdAt: DateTime.now(),
          linkLabel: next.orderRef.isEmpty ? '전환 정산' : next.orderRef,
        ),
      );
    }
    return next;
  }

  SoriPointWallet _walletOf(String shopId) {
    return _wallets.putIfAbsent(
      shopId,
      () => SoriPointWallet(
        id: 'w-$shopId',
        shopId: shopId,
        freeBalance: 20,
        paidBalance: 0,
        settlementBalance: 0,
      ),
    );
  }

  @override
  Future<SoriPointWallet> loadPointWallet(String shopId) async {
    return _walletOf(shopId);
  }

  @override
  Future<List<PointTransaction>> loadPointTransactions(
    String shopId, {
    int limit = 30,
  }) async {
    return _pointTx
        .where((t) => t.shopId == shopId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<SettlementTransaction>> loadSettlementTransactions(
    String shopId, {
    int limit = 30,
  }) async {
    return _settlementTx
        .where((t) => t.shopId == shopId)
        .take(limit)
        .toList(growable: false);
  }

  /// Test helper: credit KRW settlement without touching points.
  Future<SoriPointWallet> creditSettlementForTest({
    required String shopId,
    required int amount,
    String kind = 'market_sale',
    String note = '',
  }) async {
    final w = _walletOf(shopId);
    final next = w.copyWith(settlementBalance: w.settlementBalance + amount);
    _wallets[shopId] = next;
    _settlementTx.insert(
      0,
      SettlementTransaction(
        id: 'st-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        amount: amount,
        kind: kind,
        note: note,
        balanceAfter: next.settlementBalance,
        createdAt: DateTime.now(),
      ),
    );
    return next;
  }

  @override
  Future<Map<String, dynamic>?> requestSettlementWithdraw({
    required String shopId,
    required int amount,
    String bankAccountMask = '',
    String note = '',
  }) async {
    if (amount <= 0) throw StateError('withdraw amount must be > 0');
    final w = _walletOf(shopId);
    if (w.settlementBalance < amount) {
      throw StateError('insufficient settlement');
    }
    final next = w.copyWith(
      settlementBalance: w.settlementBalance - amount,
      settlementPending: w.settlementPending + amount,
    );
    _wallets[shopId] = next;
    final tx = SettlementTransaction(
      id: 'st-w-${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      amount: -amount,
      kind: 'withdraw_request',
      status: 'pending',
      note: note.isEmpty ? '계좌 환전 요청' : note,
      balanceAfter: next.settlementBalance,
      bankAccountMask: bankAccountMask,
      createdAt: DateTime.now(),
    );
    _settlementTx.insert(0, tx);
    return {
      'ok': true,
      'shop_id': shopId,
      'amount': amount,
      'settlement_balance': next.settlementBalance,
      'settlement_pending': next.settlementPending,
      'point_free_balance': next.freeBalance,
      'point_paid_balance': next.paidBalance,
      'tx_id': tx.id,
      'status': 'pending',
    };
  }

  @override
  Future<SoriPointWallet?> purchaseSoriPoints({
    required String shopId,
    required int amount,
    String sku = 'sori_points_pack',
    String orderRef = '',
  }) async {
    final w = _walletOf(shopId);
    final next = w.copyWith(paidBalance: w.paidBalance + amount);
    _wallets[shopId] = next;
    _pointTx.insert(
      0,
      PointTransaction(
        id: 'pt-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        amount: amount,
        bucket: 'paid',
        kind: 'purchase',
        note: orderRef.isEmpty ? sku : orderRef,
        createdAt: DateTime.now(),
        balanceFreeAfter: next.freeBalance,
        balancePaidAfter: next.paidBalance,
      ),
    );
    return next;
  }

  @override
  Future<PostUnlockResult> unlockCommunityPostWithPoints({
    required String postId,
    required String viewerShopId,
    int cost = 5,
  }) async {
    final key = '$postId::$viewerShopId';
    if (_unlocks.contains(key)) {
      return const PostUnlockResult(
        ok: true,
        alreadyUnlocked: true,
        creatorCurrency: 'point',
      );
    }
    var w = _walletOf(viewerShopId);
    if (w.pointTotal < cost) {
      throw StateError('insufficient points');
    }
    final settlementBeforeViewer = w.settlementBalance;
    var free = w.freeBalance;
    var paid = w.paidBalance;
    var need = cost;
    final fromFree = need <= free ? need : free;
    free -= fromFree;
    need -= fromFree;
    paid -= need;
    w = w.copyWith(freeBalance: free, paidBalance: paid);
    _wallets[viewerShopId] = w;
    _unlocks.add(key);

    CommunityPost? post;
    var creatorShare = 0;
    for (final p in _communityPosts) {
      if (p.id == postId) {
        post = p.copyWith(isBodyLocked: false);
        creatorShare = (cost * 70) ~/ 100;
        final cw = _walletOf(p.shopId);
        final settlementBeforeAuthor = cw.settlementBalance;
        // Creator share → points ONLY (never settlement).
        _wallets[p.shopId] = cw.copyWith(
          freeBalance: cw.freeBalance + creatorShare,
        );
        assert(
          _wallets[p.shopId]!.settlementBalance == settlementBeforeAuthor,
        );
        break;
      }
    }

    assert(_wallets[viewerShopId]!.settlementBalance == settlementBeforeViewer);

    return PostUnlockResult(
      ok: true,
      pointsSpent: cost,
      creatorShare: creatorShare,
      creatorCurrency: 'echo',
      post: post == null
          ? null
          : {
              'id': post.id,
              'shop_id': post.shopId,
              'title': post.title,
              'body': post.body,
              'visibility': post.visibility.dbValue,
              'is_body_locked': false,
              'post_type': post.postType.dbValue,
            },
    );
  }

  @override
  Future<List<PointShopItem>> loadPointShopItems({
    String category = 'booster',
  }) async {
    return PointShopItem.catalogBoosters
        .where((e) => e.category == category && e.isActive)
        .toList(growable: false);
  }

  @override
  Future<List<BoostPlacement>> loadActiveBoostPlacements({
    int limit = 40,
  }) async {
    final now = DateTime.now();
    final active = _boosts
        .where(
          (b) =>
              b.status == 'active' &&
              (b.endsAt == null || b.endsAt!.isAfter(now)),
        )
        .toList();
    if (active.length > limit) {
      return active.take(limit).toList(growable: false);
    }
    return active;
  }

  @override
  Future<BoostPurchaseResult> purchasePointShopItem({
    required String shopId,
    required String sku,
    required String targetType,
    required String targetId,
    String regionCode = '',
  }) async {
    PointShopItem? item;
    for (final e in PointShopItem.catalogBoosters) {
      if (e.sku == sku) {
        item = e;
        break;
      }
    }
    if (item == null) {
      return const BoostPurchaseResult(ok: false, message: 'item not found');
    }

    final w = _walletOf(shopId);
    final settlementBefore = w.settlementBalance;
    if (w.pointTotal < item.pricePoints) {
      return BoostPurchaseResult.insufficientPoints(
        have: w.pointTotal,
        need: item.pricePoints,
      );
    }

    var free = w.freeBalance;
    var paid = w.paidBalance;
    var need = item.pricePoints;
    final fromFree = need <= free ? need : free;
    free -= fromFree;
    need -= fromFree;
    paid -= need;
    final next = w.copyWith(freeBalance: free, paidBalance: paid);
    _wallets[shopId] = next;
    assert(next.settlementBalance == settlementBefore);

    _pointTx.insert(
      0,
      PointTransaction(
        id: 'pt-boost-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        amount: -item.pricePoints,
        bucket: fromFree > 0 ? 'free' : 'paid',
        kind: 'boost_spend',
        note: item.title,
        createdAt: DateTime.now(),
        balanceFreeAfter: next.freeBalance,
        balancePaidAfter: next.paidBalance,
      ),
    );

    BoostPlacement? placement;
    if (item.isBooster) {
      final starts = DateTime.now();
      final ends = starts.add(Duration(hours: item.durationHours));
      final type = targetType.trim().isEmpty ? 'chart' : targetType.trim();
      for (var i = 0; i < _boosts.length; i++) {
        final b = _boosts[i];
        if (b.status == 'active' &&
            b.targetType == type &&
            b.targetId == targetId) {
          _boosts[i] = BoostPlacement(
            id: b.id,
            shopId: b.shopId,
            targetType: b.targetType,
            targetId: b.targetId,
            itemSku: b.itemSku,
            chartId: b.chartId,
            postId: b.postId,
            regionCode: b.regionCode,
            startsAt: b.startsAt,
            endsAt: b.endsAt,
            status: 'cancelled',
            pointsSpent: b.pointsSpent,
            source: b.source,
            paidByCustomerId: b.paidByCustomerId,
            paidByWalletId: b.paidByWalletId,
            fanDisplayName: b.fanDisplayName,
          );
        }
      }
      placement = BoostPlacement(
        id: 'bp-${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        targetType: type,
        targetId: targetId,
        itemSku: item.sku,
        chartId: type == 'chart' ? targetId : null,
        postId: type == 'community_post' ? targetId : null,
        regionCode: regionCode,
        startsAt: starts,
        endsAt: ends,
        status: 'active',
        pointsSpent: item.pricePoints,
        source: 'shop_ad',
      );
      _boosts.insert(0, placement);
    }

    return BoostPurchaseResult(
      ok: true,
      sku: item.sku,
      pointsSpent: item.pricePoints,
      pointFreeBalance: next.freeBalance,
      pointPaidBalance: next.paidBalance,
      settlementBalance: next.settlementBalance,
      placement: placement,
    );
  }

  SoriPointWallet _customerWalletOf(String customerId) {
    return _customerWallets.putIfAbsent(
      customerId,
      () => SoriPointWallet(
        id: 'cw-$customerId',
        shopId: '',
        freeBalance: 20,
        paidBalance: 0,
        settlementBalance: 0,
      ),
    );
  }

  @override
  Future<SoriPointWallet> loadCustomerEchoWallet(String customerId) async {
    return _customerWalletOf(customerId);
  }

  @override
  Future<SoriPointWallet?> purchaseCustomerEcho({
    required String customerId,
    required int amount,
    String sku = 'sori_e_55',
    String orderRef = '',
  }) async {
    if (amount <= 0) return null;
    final w = _customerWalletOf(customerId);
    final next = w.copyWith(paidBalance: w.paidBalance + amount);
    _customerWallets[customerId] = next;
    return next;
  }

  @override
  Future<BoostPurchaseResult> purchaseFanBoost({
    required String customerId,
    required String sku,
    required String targetType,
    required String targetId,
    String targetShopId = '',
    String fanDisplayName = '',
    String regionCode = '',
  }) async {
    PointShopItem? item;
    for (final e in PointShopItem.catalogBoosters) {
      if (e.sku == sku) {
        item = e;
        break;
      }
    }
    if (item == null) {
      return const BoostPurchaseResult(ok: false, message: 'item not found');
    }

    var resolvedShop = targetShopId.trim();
    if (resolvedShop.isEmpty) {
      for (final b in _boosts) {
        if (b.targetId == targetId) resolvedShop = b.shopId;
      }
    }
    if (resolvedShop.isEmpty) {
      try {
        final hot = await loadCommunityHotCases(limit: 80);
        for (final c in hot) {
          if (c.chart.id == targetId) {
            resolvedShop = c.shop.id;
            break;
          }
        }
      } catch (_) {}
    }
    if (resolvedShop.isEmpty) {
      return const BoostPurchaseResult(ok: false, message: 'target shop missing');
    }

    final shopW = _walletOf(resolvedShop);
    final settlementBefore = shopW.settlementBalance;

    final cw = _customerWalletOf(customerId);
    if (cw.pointTotal < item.pricePoints) {
      return BoostPurchaseResult.insufficientPoints(
        have: cw.pointTotal,
        need: item.pricePoints,
      );
    }

    var free = cw.freeBalance;
    var paid = cw.paidBalance;
    var need = item.pricePoints;
    final fromFree = need <= free ? need : free;
    free -= fromFree;
    need -= fromFree;
    paid -= need;
    final nextCw = cw.copyWith(freeBalance: free, paidBalance: paid);
    _customerWallets[customerId] = nextCw;
    assert(nextCw.settlementBalance == 0);

    final type = targetType.trim().isEmpty ? 'chart' : targetType.trim();
    // Keep cancelled history for multi-supporter aggregation (do not delete).
    for (var i = 0; i < _boosts.length; i++) {
      final b = _boosts[i];
      if (b.status == 'active' &&
          b.targetType == type &&
          b.targetId == targetId) {
        _boosts[i] = BoostPlacement(
          id: b.id,
          shopId: b.shopId,
          targetType: b.targetType,
          targetId: b.targetId,
          itemSku: b.itemSku,
          chartId: b.chartId,
          postId: b.postId,
          regionCode: b.regionCode,
          startsAt: b.startsAt,
          endsAt: b.endsAt,
          status: 'cancelled',
          pointsSpent: b.pointsSpent,
          source: b.source,
          paidByCustomerId: b.paidByCustomerId,
          paidByWalletId: b.paidByWalletId,
          fanDisplayName: b.fanDisplayName,
        );
      }
    }
    final starts = DateTime.now();
    final ends = starts.add(Duration(hours: item.durationHours));
    final name = fanDisplayName.trim().isEmpty ? '후원자' : fanDisplayName.trim();
    final walletId = 'cw-$customerId';
    final placement = BoostPlacement(
      id: 'bp-fan-${DateTime.now().millisecondsSinceEpoch}',
      shopId: resolvedShop,
      targetType: type,
      targetId: targetId,
      itemSku: item.sku,
      chartId: type == 'chart' ? targetId : null,
      postId: type == 'community_post' ? targetId : null,
      regionCode: regionCode,
      startsAt: starts,
      endsAt: ends,
      status: 'active',
      pointsSpent: item.pricePoints,
      source: 'fan_boost',
      paidByCustomerId: customerId,
      paidByWalletId: walletId,
      fanDisplayName: name,
    );
    _boosts.insert(0, placement);

    final shopAfter = _walletOf(resolvedShop);
    assert(shopAfter.settlementBalance == settlementBefore);

    _shopNotifications.insert(0, {
      'id': 'n-${DateTime.now().millisecondsSinceEpoch}',
      'shop_id': resolvedShop,
      'kind': 'fan_boost',
      'title': '후원 알림',
      'body': '$name님이 부스터를 지원했습니다',
      'payload': {
        'placement_id': placement.id,
        'customer_id': customerId,
        'fan_name': name,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    return BoostPurchaseResult(
      ok: true,
      sku: item.sku,
      pointsSpent: item.pricePoints,
      pointFreeBalance: nextCw.freeBalance,
      pointPaidBalance: nextCw.paidBalance,
      settlementBalance: settlementBefore,
      placement: placement,
    );
  }

  @override
  Future<BoostPurchaseResult> purchaseSpecialSupporterGift({
    required String customerId,
    required String sku,
    required String targetType,
    required String targetId,
    String targetShopId = '',
    String fanDisplayName = '',
    String regionCode = '',
  }) async {
    PointShopItem? item;
    for (final e in PointShopItem.catalogSpecialGifts) {
      if (e.sku == sku) {
        item = e;
        break;
      }
    }
    if (item == null) {
      return const BoostPurchaseResult(ok: false, message: 'item not found');
    }

    var resolvedShop = targetShopId.trim();
    if (resolvedShop.isEmpty) {
      for (final o in _premiumOverlays) {
        if (o.targetId == targetId) resolvedShop = o.beneficiaryShopId;
      }
      for (final b in _boosts) {
        if (b.targetId == targetId) resolvedShop = b.shopId;
      }
    }
    if (resolvedShop.isEmpty) {
      try {
        final hot = await loadCommunityHotCases(limit: 80);
        for (final c in hot) {
          if (c.chart.id == targetId) {
            resolvedShop = c.shop.id;
            break;
          }
        }
      } catch (_) {}
    }
    if (resolvedShop.isEmpty) {
      return const BoostPurchaseResult(ok: false, message: 'target shop missing');
    }

    final shopW = _walletOf(resolvedShop);
    final settlementBefore = shopW.settlementBalance;

    final cw = _customerWalletOf(customerId);
    if (cw.pointTotal < item.pricePoints) {
      return BoostPurchaseResult.insufficientPoints(
        have: cw.pointTotal,
        need: item.pricePoints,
      );
    }

    var free = cw.freeBalance;
    var paid = cw.paidBalance;
    var need = item.pricePoints;
    final fromFree = need <= free ? need : free;
    free -= fromFree;
    need -= fromFree;
    paid -= need;
    final nextCw = cw.copyWith(freeBalance: free, paidBalance: paid);
    _customerWallets[customerId] = nextCw;

    final type = targetType.trim().isEmpty ? 'chart' : targetType.trim();
    final tier = item.sku.contains('platinum') ? 'platinum' : 'gold';
    final name = fanDisplayName.trim().isEmpty ? '후원자' : fanDisplayName.trim();
    final starts = DateTime.now();
    final ends = starts.add(Duration(hours: item.durationHours));

    for (var i = 0; i < _premiumOverlays.length; i++) {
      final o = _premiumOverlays[i];
      if (o.targetType == type &&
          o.targetId == targetId &&
          o.tier == tier &&
          o.isActive) {
        _premiumOverlays[i] = PremiumOverlay(
          id: o.id,
          targetType: o.targetType,
          targetId: o.targetId,
          chartId: o.chartId,
          beneficiaryShopId: o.beneficiaryShopId,
          tier: o.tier,
          sku: o.sku,
          fanCustomerId: o.fanCustomerId,
          fanDisplayName: o.fanDisplayName,
          echoSpent: o.echoSpent,
          startsAt: o.startsAt,
          endsAt: DateTime.now(),
        );
      }
    }

    final overlay = PremiumOverlay(
      id: 'ov-${DateTime.now().millisecondsSinceEpoch}',
      targetType: type,
      targetId: targetId,
      chartId: type == 'chart' ? targetId : null,
      beneficiaryShopId: resolvedShop,
      tier: tier,
      sku: item.sku,
      fanCustomerId: customerId,
      fanDisplayName: name,
      echoSpent: item.pricePoints,
      startsAt: starts,
      endsAt: ends,
    );
    _premiumOverlays.insert(0, overlay);

    final shopAfter = _walletOf(resolvedShop);
    assert(shopAfter.settlementBalance == settlementBefore);

    _shopNotifications.insert(0, {
      'id': 'n-${DateTime.now().millisecondsSinceEpoch}',
      'shop_id': resolvedShop,
      'kind': 'special_supporter',
      'title': '스페셜 후원 알림',
      'body': '$name님이 ${tier == 'platinum' ? '플래티넘' : '골드'} 스페셜 후원을 보냈습니다',
      'payload': {
        'overlay_id': overlay.id,
        'customer_id': customerId,
        'tier': tier,
        'fan_name': name,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    return BoostPurchaseResult(
      ok: true,
      sku: item.sku,
      pointsSpent: item.pricePoints,
      pointFreeBalance: nextCw.freeBalance,
      pointPaidBalance: nextCw.paidBalance,
      settlementBalance: settlementBefore,
      raw: {'tier': tier, 'overlay': overlay},
    );
  }

  @override
  Future<List<PremiumOverlay>> loadActivePremiumOverlays({int limit = 80}) async {
    final now = DateTime.now();
    return _premiumOverlays
        .where((o) => o.isActive && (o.endsAt == null || o.endsAt!.isAfter(now)))
        .take(limit)
        .toList();
  }

  @override
  Future<List<FanSupporterEntry>> loadFanBoostSupporters({
    required String targetId,
    String targetType = 'chart',
    int limit = 200,
  }) async {
    final type = targetType.trim().isEmpty ? 'chart' : targetType.trim();
    final tid = targetId.trim();
    final map = <String, FanSupporterEntry>{};
    for (final b in _boosts) {
      if (!b.isFanBoost) continue;
      if (b.targetType != type || b.targetId != tid) continue;
      final key = (b.paidByWalletId ?? b.paidByCustomerId ?? b.fanDisplayName)
          .trim();
      if (key.isEmpty) continue;
      final prev = map[key];
      if (prev == null) {
        map[key] = FanSupporterEntry(
          name: b.fanDisplayName.trim().isEmpty ? '후원자' : b.fanDisplayName.trim(),
          echoSpent: b.pointsSpent,
          customerId: b.paidByCustomerId,
          walletId: b.paidByWalletId,
          boostCount: 1,
        );
      } else {
        map[key] = FanSupporterEntry(
          name: prev.name,
          echoSpent: prev.echoSpent + b.pointsSpent,
          customerId: prev.customerId ?? b.paidByCustomerId,
          walletId: prev.walletId ?? b.paidByWalletId,
          boostCount: prev.boostCount + 1,
        );
      }
    }
    return FanSupporterEntry.ranked(map.values).take(limit).toList();
  }

  @override
  Future<Map<String, List<FanSupporterEntry>>> loadFanBoostSupportersBatch({
    required List<String> targetIds,
    String targetType = 'chart',
    int limitPerTarget = 50,
  }) async {
    final out = <String, List<FanSupporterEntry>>{};
    for (final id in targetIds) {
      final list = await loadFanBoostSupporters(
        targetId: id,
        targetType: targetType,
        limit: limitPerTarget,
      );
      if (list.isNotEmpty) out[id] = list;
    }
    return out;
  }

  @override
  Future<ShopSupporterHeader> loadShopSupporterHeader(String shopId) async {
    final supporters = await loadShopSupporters(shopId, limit: 3);
    final followers = await countShopFollowers(shopId);
    final all = await loadShopSupporters(shopId, limit: 200);
    return ShopSupporterHeader(
      followerCount: followers,
      supporterCount: all.length,
      facepile: supporters,
      topSupporter: supporters.isEmpty ? null : supporters.first,
    );
  }

  @override
  Future<List<FanSupporterEntry>> loadShopSupporters(
    String shopId, {
    String sort = 'echo_desc',
    int limit = 50,
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    final map = <String, FanSupporterEntry>{};
    for (final b in _boosts) {
      if (b.shopId != sid || !b.isFanBoost) continue;
      final cid = b.paidByCustomerId?.trim() ?? '';
      final key = cid.isNotEmpty ? cid : b.fanDisplayName.trim();
      if (key.isEmpty) continue;
      final name = b.fanDisplayName.trim().isEmpty ? '후원자' : b.fanDisplayName.trim();
      final prev = map[key];
      if (prev == null) {
        map[key] = FanSupporterEntry(
          name: name,
          echoSpent: b.pointsSpent,
          customerId: cid.isEmpty ? null : cid,
          boostCount: 1,
        );
      } else {
        map[key] = FanSupporterEntry(
          name: prev.name,
          echoSpent: prev.echoSpent + b.pointsSpent,
          customerId: prev.customerId,
          boostCount: prev.boostCount + 1,
        );
      }
    }
    return FanSupporterEntry.ranked(map.values).take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> loadBoostCandidatesScored({
    String segment = 'case',
    int limit = 200,
  }) async {
    final seg = FeedSegment.fromDb(segment);
    final now = DateTime.now();
    final fandomByTarget = <String, int>{};
    for (final b in _boosts) {
      if (!b.isFanBoost) continue;
      fandomByTarget[b.targetId] =
          (fandomByTarget[b.targetId] ?? 0) + b.pointsSpent;
    }
    final scored = <BoostScoreInput>[];
    for (final b in _boosts) {
      if (b.status != 'active') continue;
      if (b.endsAt != null && !b.endsAt!.isAfter(now)) continue;
      final bSeg = b.targetType == 'chart'
          ? FeedSegment.caseFeed
          : FeedSegment.fromDb(b.regionCode);
      if (bSeg != seg) continue;
      scored.add(
        BoostScoreInput(
          targetId: b.targetId,
          placementId: b.id,
          fandomEcho: fandomByTarget[b.targetId] ?? 0,
          paidRatio: b.isFanBoost ? 0.85 : 0.55,
          startsAt: b.startsAt,
          isFanBoost: b.isFanBoost,
          pointsSpent: b.pointsSpent,
        ),
      );
    }
    scored.sort((a, b) => b.score(now: now).compareTo(a.score(now: now)));
    return scored
        .take(limit)
        .map(
          (e) => {
            'placement_id': e.placementId,
            'target_id': e.targetId,
            'source': e.isFanBoost ? 'fan_boost' : 'shop_ad',
            'points_spent': e.pointsSpent,
            'fandom_echo': e.fandomEcho,
            'paid_ratio': e.paidRatio,
            'score': e.score(now: now),
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> loadInterleavedFeedIds({
    String segment = 'case',
    int limit = 20,
    int offset = 0,
    String viewerSeed = '',
  }) async {
    final seg = FeedSegment.fromDb(segment);
    final candidates = await loadBoostCandidatesScored(
      segment: segment,
      limit: 200,
    );
    final inputs = candidates
        .map(
          (m) => BoostScoreInput(
            targetId: '${m['target_id']}',
            placementId: '${m['placement_id']}',
            fandomEcho: DbMap.asInt(m['fandom_echo']),
            paidRatio: (m['paid_ratio'] as num?)?.toDouble() ?? 0.5,
            isFanBoost: m['source'] == 'fan_boost',
            pointsSpent: DbMap.asInt(m['points_spent']),
          ),
        )
        .toList();
    final seed = viewerSeed.trim().isEmpty
        ? feedViewerSeed(viewerId: 'anon', segment: seg)
        : viewerSeed;
    final slots = boostSlotsForPage(offset + limit);
    final picked = pickBoostSlots(
      candidates: inputs,
      slotCount: slots,
      viewerSeed: seed,
    );

    List<String> organic = const [];
    if (seg == FeedSegment.caseFeed) {
      final hot = await loadCommunityHotCases(limit: 200);
      organic = hot.map((e) => e.chart.id).toList();
    } else {
      final type = seg == FeedSegment.interior
          ? CommunityPostType.interior
          : CommunityPostType.deviceReview;
      final posts = await loadCommunityPosts(type: type, limit: 200);
      organic = posts.map((e) => e.id).toList();
    }

    final boostItems = picked.map((e) => e.targetId).toList();
    final organicObjs = organic.map((id) => id).toList();
    final interleaved = interleaveFeed<String>(
      organic: organicObjs,
      boosted: boostItems,
      idOf: (id) => id,
    );
    final page = interleaved.skip(offset).take(limit).toList();
    final boostSet = boostItems.toSet();
    final scoreBy = {for (final p in picked) p.targetId: p.score()};
    return [
      for (var i = 0; i < page.length; i++)
        {
          'target_id': page[i],
          'is_boost': boostSet.contains(page[i]),
          'feed_position': offset + i,
          'score': scoreBy[page[i]] ?? 0,
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadShopNotifications(
    String shopId, {
    int limit = 20,
  }) async {
    return _shopNotifications
        .where((n) => n['shop_id'] == shopId)
        .take(limit)
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  @override
  Future<List<SeminarClass>> loadSeminarClassesForShop(String shopId) async {
    return _seminarClasses
        .where((c) => c.directorShopId == shopId)
        .toList(growable: false);
  }
}

class _MemWhisperRecipient {
  _MemWhisperRecipient({
    required this.postId,
    required this.userId,
    required this.atomBits,
  });

  final String postId;
  final String userId;
  final int atomBits;
}
