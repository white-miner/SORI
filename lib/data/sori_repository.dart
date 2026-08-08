import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';

/// 앱 초기 로드용 스냅샷 (Repository → Store).
class SoriSnapshot {
  const SoriSnapshot({
    required this.shop,
    required this.customers,
    required this.charts,
    required this.reviews,
    required this.aiReplies,
    required this.gallerySlides,
    this.todayHomecareTip =
        '미지근한 물로 가볍게 클렌징하고, 보습 세럼을 손바닥 온기로 펴 발라 주세요.',
    this.reviewRequestedCustomerIds = const {},
  });

  final Shop shop;
  final List<Customer> customers;
  final List<CustomerChart> charts;
  final List<CustomerReview> reviews;
  final List<AiReply> aiReplies;
  final List<ShopGallerySlide> gallerySlides;
  final String todayHomecareTip;
  final Set<String> reviewRequestedCustomerIds;
}

/// 차트 저장 + 방문 확인 요청 페이로드.
class SaveChartRequest {
  const SaveChartRequest({
    required this.customerId,
    required this.visitNumber,
    required this.careName,
    required this.treatmentSummary,
    required this.directorInsight,
    required this.concernChips,
    required this.firstVisitFearChips,
    required this.revisitFeedbackChips,
    this.customChartNo,
    this.chartId,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.customerName,
    this.customerPhone,
    this.gender,
    this.birthDate,
    this.address,
    this.occupation,
    this.allergyNotes,
    this.medicationHistory,
    this.homeCareHabits,
    this.membershipServiceName,
    this.membershipTotalVisits,
    this.membershipUsedVisits,
    this.deductMembership = true,
  });

  final String customerId;
  final int visitNumber;
  final String? customChartNo;
  final String? chartId;
  final String careName;
  final String treatmentSummary;
  final String directorInsight;
  final List<String> concernChips;
  final List<String> firstVisitFearChips;
  final List<String> revisitFeedbackChips;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String? customerName;
  final String? customerPhone;
  final CustomerGender? gender;
  final DateTime? birthDate;
  final String? address;
  final String? occupation;
  final String? allergyNotes;
  final String? medicationHistory;
  final String? homeCareHabits;
  final String? membershipServiceName;
  final int? membershipTotalVisits;
  final int? membershipUsedVisits;
  final bool deductMembership;
}

class SaveChartResult {
  const SaveChartResult({
    required this.chart,
    required this.customer,
    this.review,
  });

  final CustomerChart chart;
  final Customer customer;
  final CustomerReview? review;
}

/// 데이터 소스 추상화 (Memory | Supabase).
abstract class SoriRepository {
  bool get isRemote;

  Future<SoriSnapshot> loadInitialData();

  Future<Customer?> findCustomerByPhone(String phone, {String? shopId});

  Future<Customer> upsertCustomer(Customer customer);

  Future<Shop> upsertShop(Shop shop);

  Future<SaveChartResult> saveChartAndConfirmVisit(SaveChartRequest request);

  Future<CustomerReview> upsertReview(CustomerReview review);
}
