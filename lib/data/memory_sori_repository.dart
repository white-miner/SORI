import '../models/care_diary_note.dart';
import '../models/case_timeline_entry.dart';
import '../models/community_case_item.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/kakao_alimtalk.dart';
import '../models/membership_ticket.dart';
import '../models/review_reply.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/seminar_class.dart';
import '../models/seminar_class_detail.dart';
import '../models/seminar_education_insight.dart';
import '../models/seminar_feedback_report.dart';
import '../models/seminar_enrollment.dart';
import '../utils/db_map.dart';
import '../models/shop_highlight.dart';
import '../models/shop_tier_badge.dart';
import '../models/shop_service_item.dart';
import 'sori_repository.dart';

/// 로컬 더미 데이터 (UI 하드코딩 분리용).
class MemorySoriRepository implements SoriRepository {
  /// shopId → customerIds 팔로우 셋 (프로세스 내 유지).
  static final Map<String, Set<String>> _followersByShop = {};
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
  Future<Shop> upsertShop(Shop shop) async => shop;

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
    );
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
        ),
        shop: partnerShop,
        review: partnerReview,
        customerAge: 38,
        customerGenderLabel: '여성',
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
      createdAt: DateTime.now(),
    );
    _seminarClasses.add(created);
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
}
