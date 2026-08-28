import '../models/ai_reply.dart';
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
import '../models/fan_supporter.dart';
import '../models/shop_supporter_header.dart';
import '../models/seminar_application.dart';
import '../models/seminar_class.dart';
import '../models/seminar_class_detail.dart';
import '../models/seminar_education_insight.dart';
import '../models/seminar_feedback_report.dart';
import '../models/seminar_enrollment.dart';
import '../models/shop_highlight.dart';
import '../models/subscription.dart';
import '../models/whisper.dart';
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
    this.shopPosts = const [],
    this.seminarClasses = const [],
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
  final List<ShopPost> shopPosts;
  final List<SeminarClass> seminarClasses;
  final String todayHomecareTip;
  final Set<String> reviewRequestedCustomerIds;
}

/// 고객 일괄 삭제 결과.
class BulkDeleteResult {
  const BulkDeleteResult({
    required this.deletedIds,
    this.failedIds = const [],
  });

  final List<String> deletedIds;
  final List<String> failedIds;

  bool get hasFailures => failedIds.isNotEmpty;
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
    this.deviceInfo,
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
  final String? deviceInfo;
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

  /// 고객 일괄 삭제. CASCADE/FK에 따라 차트·리뷰도 함께 제거되는 환경 전제.
  /// 부분 실패 시 [BulkDeleteResult.failedIds]에 남긴다.
  Future<BulkDeleteResult> bulkDeleteCustomers(List<String> customerIds);

  /// 중복 고객 병합 — Primary 유지, Secondary 삭제.
  Future<CustomerMergeResult> mergeShopCustomers({
    required String primaryId,
    required List<String> sourceIds,
  });

  Future<Shop> upsertShop(Shop shop);

  /// shops 컬럼만 부분 업데이트 (아바타·간판·기기 JSON). 성공 시 최신 행.
  Future<Shop> patchShopFields(String shopId, Map<String, dynamic> fields);

  Future<SaveChartResult> saveChartAndConfirmVisit(SaveChartRequest request);

  /// 관리 케이스 공개 공유 플래그 갱신.
  Future<void> updateChartCaseShared({
    required String chartId,
    required bool shared,
  });

  /// 차트 본문/사진 부분 업데이트 (수정 모드·After 패치).
  Future<CustomerChart> updateCustomerChartFields({
    required String chartId,
    String? careName,
    String? treatmentSummary,
    String? directorInsight,
    String? beforeImageUrl,
    String? afterImageUrl,
    List<String>? concernChips,
    bool clearAfterImageUrl = false,
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

  Future<CustomerReview?> setReviewNaverPublishStatus({
    required String reviewId,
    required String status,
  });

  /// Review ops P1 — request events.
  Future<List<ReviewRequestEvent>> loadReviewRequestEvents({
    String? shopId,
    int limit = 80,
  });

  Future<ReviewRequestEvent> insertReviewRequestEvent({
    required String customerId,
    String? chartId,
    String channel = 'qr',
    String? shopId,
    int remindHours = 24,
  });

  Future<int> convertReviewRequestEvents({
    required String customerId,
    required String reviewId,
    String? shopId,
  });

  Future<bool> markReviewRequestReminded(String eventId);

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

  /// Phase 11 — subscriptions (user→shop|director).
  Future<List<Subscription>> loadMySubscriptions({int limit = 200});

  Future<void> setSubscription({
    required SubscriptionTargetType targetType,
    String? targetShopId,
    String? targetUserId,
    required bool following,
    String source = 'discover',
  });

  /// 팔로잉 탭 피드 (구독한 원장/샵 포스트만).
  Future<List<CommunityPost>> loadFollowingFeed({int limit = 40});

  /// 탐색 디렉터리.
  Future<List<DiscoverDirector>> loadDiscoverDirectors({
    int limit = 40,
    String query = '',
  });

  /// Phase 12 — Whisper as community_posts (composable audience).
  Future<WhisperAudiencePreview> previewWhisperAudience(
    WhisperAudienceSpec spec,
  );

  Future<WhisperSendResult> sendWhisper({
    required String body,
    required WhisperAudienceSpec spec,
  });

  Future<List<WhisperAudiencePreset>> loadWhisperPresets();

  Future<WhisperAudiencePreset> saveWhisperPreset({
    required String name,
    required WhisperAudienceSpec spec,
  });

  Future<void> deleteWhisperPreset(String presetId);

  /// 동일 고객·관리 태그 회차 타임라인 (RPC).
  Future<List<CaseTimelineEntry>> loadCaseTimelineGroup(String chartId);

  /// B2B 세미나 관심(요청) — 결제/수강 아님. 작성자 샵 카운트 증가.
  Future<int> insertSeminarRequest({
    required String caseId,
    String? requestorShopId,
    String? requestorUserId,
  });

  /// 내 샵 케이스에 쌓인 세미나 요청 인사이트.
  Future<SeminarEducationInsight> loadSeminarEducationInsight(String directorShopId);

  /// 세미나 클래스 등록.
  Future<SeminarClass> createSeminarClass(SeminarClass draft);

  /// 세미나 수강 신청서 제출.
  Future<SeminarApplication> submitSeminarApplication(SeminarApplication draft);

  /// 세미나 클래스 랜딩 상세 (강사·근원 차트 포함).
  Future<SeminarClassDetail?> loadSeminarClassDetail(String classId);

  /// 세미나 수강 등록 — 에스크로 held.
  Future<String> enrollSeminarClass({
    required String classId,
    required String enrollorShopId,
  });

  /// 수강 완료 정산 — 원장 sori_cash_balance 적립.
  Future<int> settleSeminarEnrollment(String enrollmentId);

  /// 내 샵(수강생) held 세미나 등록 목록.
  Future<List<SeminarEnrollment>> loadMySeminarEnrollments(String enrollorShopId);

  /// 인사이트 태그 리뷰 제출 (정산 전 필수).
  Future<void> submitSeminarEnrollmentReview({
    required String enrollmentId,
    required List<String> insightTags,
    String comment = '',
  });

  /// 클래스 리뷰 집계 → AI 피드백 리포트 갱신.
  Future<void> refreshSeminarFeedbackReport(String classId);

  /// 원장 샵 AI 세미나 피드백 보관함 목록.
  Future<List<SeminarFeedbackReport>> loadSeminarFeedbackReports(String shopId);

  /// 리포트 상세 (긍정 코멘트 포함).
  Future<SeminarFeedbackReport?> loadSeminarFeedbackReportDetail(String reportId);

  /// 샵 갤러리 로드 (sort_order ASC).
  Future<List<ShopGallerySlide>> loadShopGalleryItems(String shopId);

  /// 갤러리 항목 추가 (샵당 최대 20).
  Future<ShopGallerySlide> insertShopGalleryItem({
    required String shopId,
    required String imageUrl,
    String title = '',
  });

  Future<void> deleteShopGalleryItem(String itemId);

  /// 샵 소식 쓰레드 로드.
  Future<List<ShopPost>> loadShopPosts(String shopId);

  Future<ShopPost> insertShopPost({
    required String shopId,
    required String body,
    String? authorUserId,
    List<String> imageUrls = const [],
    String postKind = 'note',
    String? seminarClassId,
  });

  Future<void> deleteShopPost(String postId);

  /// B2B Community 포스트 로드 (유형 필터 선택).
  Future<List<CommunityPost>> loadCommunityPosts({
    CommunityPostType? type,
    int limit = 40,
  });

  /// 인테리어/기기리뷰 Community 포스트 생성 + 미디어(+태그/리뷰/중고).
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
  });

  Future<void> updateMarketListingStatus({
    required String listingId,
    required MarketListingStatus status,
  });

  /// shop_id → 사업자 인증 여부 (`business_verified`).
  Future<Map<String, bool>> loadShopBusinessVerified(List<String> shopIds);

  Future<void> deleteCommunityPost(String postId);

  Future<List<CommunityComment>> loadCommunityComments(String postId);

  Future<CommunityComment> insertCommunityComment({
    required String postId,
    required String content,
    String? authorUserId,
    String? authorShopId,
    String? parentId,
  });

  /// Affiliate: URL 탭 시 링크 upsert + 클릭/수수료 적립.
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
  });

  Future<AffiliateEarningsSummary> loadAffiliateEarnings(String shopId);

  /// 차트 공유 플래그 + case_share 발행 (DB 트랜잭션 RPC).
  Future<CommunityPost?> saveChartAndPublishCase({
    required String chartId,
    required String shopId,
    bool publish = true,
    String? title,
    String? body,
    List<String> imageUrls = const [],
    String? authorUserId,
  });

  /// 구매 전환 기록 (pending).
  Future<AffiliateConversion?> recordAffiliateConversion({
    required String shopId,
    required int commissionAmount,
    String orderRef = '',
    int grossAmount = 0,
    String? linkId,
    String? clickId,
    String? postId,
    String note = '',
  });

  /// Admin 정산: pending→confirmed→paid.
  Future<AffiliateConversion?> settleAffiliateConversion({
    required String conversionId,
    required String toStatus,
    String? actorUserId,
  });

  Future<SoriPointWallet> loadPointWallet(String shopId);

  Future<List<PointTransaction>> loadPointTransactions(
    String shopId, {
    int limit = 30,
  });

  Future<List<SettlementTransaction>> loadSettlementTransactions(
    String shopId, {
    int limit = 30,
  });

  /// IAP 브릿지 — 영수증 검증 전 MVP 충전 스텁 (포인트만).
  Future<SoriPointWallet?> purchaseSoriPoints({
    required String shopId,
    required int amount,
    String sku = 'sori_points_pack',
    String orderRef = '',
  });

  /// 정산금 계좌 환전 요청 (settlement_balance만).
  Future<Map<String, dynamic>?> requestSettlementWithdraw({
    required String shopId,
    required int amount,
    String bankAccountMask = '',
    String note = '',
  });

  /// 잠금 게시물 Echo 열람 + 작성자 수익분배(Echo만).
  Future<PostUnlockResult> unlockCommunityPostWithPoints({
    required String postId,
    required String viewerShopId,
    int cost = 5,
  });

  /// 포인트 상점 부스터 등 상품 목록.
  Future<List<PointShopItem>> loadPointShopItems({
    String category = 'booster',
  });

  /// 활성 부스터 배치 (Home 핀용).
  Future<List<BoostPlacement>> loadActiveBoostPlacements({int limit = 40});

  /// 포인트 상점 구매 — settlement 미차감. 부족 시 BoostPurchaseResult.insufficient.
  Future<BoostPurchaseResult> purchasePointShopItem({
    required String shopId,
    required String sku,
    required String targetType,
    required String targetId,
    String regionCode = '',
  });

  /// 고객 지갑 로드.
  Future<SoriPointWallet> loadCustomerEchoWallet(String customerId);

  /// 고객 IAP Echo 충전 스텁.
  Future<SoriPointWallet?> purchaseCustomerEcho({
    required String customerId,
    required int amount,
    String sku = 'sori_e_55',
    String orderRef = '',
  });

  /// Fan-Boost — 고객 Echo 소각 → 원장 케이스 핀. settlement 불변.
  Future<BoostPurchaseResult> purchaseFanBoost({
    required String customerId,
    required String sku,
    required String targetType,
    required String targetId,
    String targetShopId = '',
    String fanDisplayName = '',
    String regionCode = '',
  });

  /// 게시물별 Fan-Boost 서포터 랭킹 (누적 Echo DESC).
  Future<List<FanSupporterEntry>> loadFanBoostSupporters({
    required String targetId,
    String targetType = 'chart',
    int limit = 200,
  });

  /// 피드용 배치 집계 — targetId → ranked supporters.
  Future<Map<String, List<FanSupporterEntry>>> loadFanBoostSupportersBatch({
    required List<String> targetIds,
    String targetType = 'chart',
    int limitPerTarget = 50,
  });

  /// 샵 단위 후원자 헤더 (마이페이지 Facepile).
  Future<ShopSupporterHeader> loadShopSupporterHeader(String shopId);

  /// 샵 후원자 목록 — echo_desc | recent | count_desc.
  Future<List<FanSupporterEntry>> loadShopSupporters(
    String shopId, {
    String sort = 'echo_desc',
    int limit = 50,
  });

  /// 세그먼트별 스코어 부스터 후보 (059).
  Future<List<Map<String, dynamic>>> loadBoostCandidatesScored({
    String segment = 'case',
    int limit = 200,
  });

  /// 인터리브 피드 target id 페이지 (059 get_home_feed / get_community_feed).
  Future<List<Map<String, dynamic>>> loadInterleavedFeedIds({
    String segment = 'case',
    int limit = 20,
    int offset = 0,
    String viewerSeed = '',
  });

  /// 원장 인박스 알림 (Fan-Boost 등).
  Future<List<Map<String, dynamic>>> loadShopNotifications(
    String shopId, {
    int limit = 20,
  });

  /// 원장 샵 세미나 클래스 목록 (최신순).
  Future<List<SeminarClass>> loadSeminarClassesForShop(String shopId);
}
