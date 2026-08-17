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
      serviceMenu: [
        ShopServiceItem(
          name: '재생케어',
          description: '피부 장벽을 편안하게 회복시키는 집중 케어예요.',
        ),
        ShopServiceItem(
          name: '수분케어',
          description: '건조한 피부에 촉촉함을 더하는 수분 충전 케어예요.',
        ),
        ShopServiceItem(
          name: 'EMS 윤곽케어',
          description: '탄력과 라인 정리를 돕는 EMS 기반 윤곽 케어예요.',
        ),
        ShopServiceItem(
          name: '테라노바 복부관리',
          description: '복부 순환과 컨디션을 가볍게 풀어주는 관리예요.',
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

    final out = <CommunityCaseItem>[];
    for (final chart in snap.charts) {
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      out.add(
        CommunityCaseItem(
          chart: chart.asPublicFeedProjection(),
          shop: snap.shop,
          review: byChartReview[chart.id]?.copyWith(customerId: ''),
        ),
      );
    }
    out.add(
      CommunityCaseItem(
        chart: partnerChart,
        shop: partnerShop,
        review: partnerReview,
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
          beforeImageUrl: 'https://picsum.photos/seed/sori-hot-body-b/600/800',
          afterImageUrl: 'https://picsum.photos/seed/sori-hot-body-a/600/800',
          signatureUrl: 'https://example.com/sig-hot-2.png',
          consentPhoto: true,
          caseShared: true,
          visitCheckedAt: DateTime.now().subtract(const Duration(days: 3)),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        shop: bodyShop,
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
  Future<void> insertSeminarRequest({
    required String caseId,
    required String requestorShopId,
  }) async {
    final key = caseId.trim();
    final req = requestorShopId.trim();
    if (key.isEmpty || req.isEmpty) return;
    _seminarRequestsByCase.putIfAbsent(key, () => <String>{}).add(req);
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
      tierBadgeLabel: ShopTierBadge.silver.label,
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
    return 'enroll-local-$_enrollmentSeq';
  }

  @override
  Future<int> settleSeminarEnrollment(String enrollmentId) async {
    return 0;
  }
}
