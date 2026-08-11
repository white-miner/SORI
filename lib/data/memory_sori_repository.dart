import '../models/care_diary_note.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/membership_ticket.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_service_item.dart';
import 'sori_repository.dart';

/// 로컬 더미 데이터 (UI 하드코딩 분리용).
class MemorySoriRepository implements SoriRepository {
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
        memberships: [
          CustomerMembership(
            id: 'm-regen',
            serviceName: '재생 케어 10회권',
            totalVisits: 10,
            usedVisits: 4,
            expiresAt: DateTime.now().add(const Duration(days: 200)),
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
        treatmentSummary: '첫 방문 재생케어',
        directorInsight: '두피 민감 — 저자극 제품 권장',
        beforeImageUrl: 'https://picsum.photos/seed/sori-b1/600/800',
        afterImageUrl: 'https://picsum.photos/seed/sori-a1/600/800',
        signatureUrl: 'https://example.com/sig-1.png',
        consentPhoto: true,
        caseShared: true,
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
        treatmentSummary: '회원권 6회차 수분케어',
        directorInsight: '보습 유지 양호, 홈케어 루틴 점검',
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
        beforeImageUrl: 'https://picsum.photos/seed/sori-b3/600/800',
        afterImageUrl: 'https://picsum.photos/seed/sori-a3/600/800',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ];

    return SoriSnapshot(
      shop: shop,
      customers: customers,
      charts: charts,
      reviews: const [],
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
}
