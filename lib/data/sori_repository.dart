import '../models/ai_reply.dart';
import '../models/care_diary_note.dart';
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
import '../models/shop_highlight.dart';
import 'auth_role_resolution.dart';

export 'auth_role_resolution.dart';

/// 앱 초기 로드용 스냅샷 (Repository → Store).
class SoriSnapshot {
  const SoriSnapshot({
    required this.shop,
    required this.customers,
    required this.charts,
    required this.reviews,
    required this.aiReplies,
    required this.gallerySlides,
    this.diaryNotes = const [],
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
  final List<CareDiaryNote> diaryNotes;
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
    this.skinSensitivity,
    this.sideEffectHistory,
    this.memberships,
    this.customerRequests,
    this.membershipServiceName,
    this.membershipTotalVisits,
    this.membershipUsedVisits,
    this.deductMembership = true,
    this.consentMandatory = false,
    this.consentPhoto = false,
    this.consentMarketing = false,
    this.consentOfflineOnly = false,
    this.signatureUrl,
    this.homeCarePrescriptions = const [],
    this.guardianPhone,
    this.infoViewConsent = false,
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
  /// 차트(customer_charts)에 저장되는 메디컬 필드.
  final String? allergyNotes;
  final String? skinSensitivity;
  final String? sideEffectHistory;
  final List<CustomerMembership>? memberships;
  final String? customerRequests;
  /// @deprecated — prefer [memberships].
  final String? membershipServiceName;
  /// @deprecated — prefer [memberships].
  final int? membershipTotalVisits;
  /// @deprecated — prefer [memberships].
  final int? membershipUsedVisits;
  final bool deductMembership;

  /// 전자 동의서 (미작성 시 전부 false / signatureUrl null).
  final bool consentMandatory;
  final bool consentPhoto;
  final bool consentMarketing;
  final bool consentOfflineOnly;
  final String? signatureUrl;

  final List<String> homeCarePrescriptions;
  final String? guardianPhone;
  final bool infoViewConsent;
}

class SaveChartResult {
  const SaveChartResult({
    required this.chart,
    required this.customer,
    this.review,
    this.membershipDeducted = false,
    this.feedbackMessage = '',
  });

  final CustomerChart chart;
  final Customer customer;
  final CustomerReview? review;
  final bool membershipDeducted;
  final String feedbackMessage;
}

/// 데이터 소스 추상화 (Memory | Supabase).
abstract class SoriRepository {
  bool get isRemote;

  Future<SoriSnapshot> loadInitialData();

  Future<Customer?> findCustomerByPhone(String phone, {String? shopId});

  Future<Customer> upsertCustomer(Customer customer);

  /// 고객 등록 전용 — customers 테이블에 name/phone/memo/shop_id 만 insert.
  Future<Customer> registerCustomer({
    required String shopId,
    required String name,
    required String phone,
    String memo = '',
  });

  Future<Shop> upsertShop(Shop shop);

  Future<SaveChartResult> saveChartAndConfirmVisit(SaveChartRequest request);

  /// 관리 케이스 공개 공유 플래그 갱신.
  Future<void> updateChartCaseShared({
    required String chartId,
    required bool shared,
  });

  /// 전자 동의서 PDF URL 갱신.
  Future<void> updateChartConsentPdfUrl({
    required String chartId,
    required String consentPdfUrl,
  });

  /// 홈케어 3일 미션 체크 갱신.
  Future<void> updateHomeCareMissionChecks({
    required String chartId,
    required List<bool> checks,
  });

  /// 케어 다이어리 메모 upsert (customer_id + note_date).
  Future<CareDiaryNote> upsertCareDiaryNote(CareDiaryNote note);

  /// 스마트 회원권 지갑 — 전화번호(숫자) 또는 UID 기준, 샵 Join.
  Future<List<MembershipTicket>> loadMembershipWallet({
    String? phone,
    String? authUserId,
  });

  /// customers.memberships → membership_tickets 동기화.
  Future<void> syncMembershipTicketsForCustomer(String customerId);

  Future<CustomerReview> upsertReview(CustomerReview review);

  /// 원장 답글 저장 — review_replies insert + customer_reviews 미러 컬럼 갱신.
  Future<CustomerReview> saveDirectorReviewReply({
    required String reviewId,
    required String shopId,
    required String body,
  });

  /// 네이버 리뷰 등록 트래킹.
  Future<CustomerReview?> markNaverRegistered({
    required String chartId,
    String? composedText,
  });

  /// Auth user id로 원장(shops.owner_user_id) / 고객(customers.user_id) 판별.
  Future<AuthRoleResolution> resolveAuthRole(String userId);

  /// 샵 소유자(원장) Auth 연결.
  Future<void> linkShopOwner({
    required String shopId,
    required String userId,
  });

  /// 고객 Auth 연결.
  Future<void> linkCustomerUser({
    required String customerId,
    required String userId,
  });

  /// Auth metadata → public.profiles upsert (이름/아바타).
  Future<void> upsertAuthProfile({
    required String userId,
    String name = '',
    String avatarUrl = '',
    String phone = '',
  });

  /// 리뷰 답글 히스토리 (review_id 스레드).
  Future<List<ReviewReply>> loadReviewReplies(String reviewId);

  /// 카카오 알림톡 MOCK 발송 — 포인트 차감 + kakao_msg_logs Insert.
  Future<KakaoAlimtalkSendResult> sendKakaoAlimtalkMock({
    required String shopId,
    required String customerPhone,
    required String templateCode,
    required String content,
    int cost = KakaoAlimtalkPricing.sendCostPoint,
    int marginAmount = KakaoAlimtalkPricing.defaultMarginAmount,
  });

  /// 로그인 없이 chartId로 케어 리포트 조회.
  Future<PublicCareReport?> loadPublicCareReport(String chartId);

  /// 전국 공유 B/A 핫 케이스 (오픈 커뮤니티 피드).
  Future<List<CommunityCaseItem>> loadCommunityHotCases({int limit = 40});

  /// 샵 스토리 하이라이트.
  Future<List<ShopHighlight>> loadShopHighlights(String shopId);

  /// 샵 단골 팬 수.
  Future<int> countShopFollowers(String shopId);

  /// 고객이 해당 샵을 팔로우 중인지.
  Future<bool> isShopFollowed({
    required String shopId,
    required String customerId,
  });

  /// 단골 팬 등록/해제.
  Future<void> setShopFollow({
    required String shopId,
    required String customerId,
    required bool following,
  });
}
