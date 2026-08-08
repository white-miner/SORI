import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
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
        membershipServiceName: '',
        membershipTotalVisits: 0,
        membershipUsedVisits: 0,
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
      ),
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
      ),
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
      ),
      CustomerChart(
        id: 'chart-3',
        shopId: shop.id,
        customerId: '3',
        visitNumber: 4,
        careName: '재생케어',
        treatmentSummary: '회원권 4회차 재생케어',
        directorInsight: '트리트먼트 업셀 가능',
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
  Future<Shop> upsertShop(Shop shop) async => shop;

  @override
  Future<SaveChartResult> saveChartAndConfirmVisit(
    SaveChartRequest request,
  ) async {
    throw UnsupportedError('Use SoriStore.saveChartAndConfirmVisit for memory');
  }

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
}
