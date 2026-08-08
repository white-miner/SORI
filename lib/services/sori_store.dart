import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import 'visit_trigger_service.dart';

/// 로컬 인메모리 스토어 (Supabase 스키마와 동일 도메인).
class SoriStore {
  SoriStore({VisitTriggerService? visitTrigger})
      : _visitTrigger = visitTrigger ?? VisitTriggerService() {
    _seed();
  }

  static final SoriStore instance = SoriStore();

  final VisitTriggerService _visitTrigger;

  late Shop shop;
  SessionUser? session;
  bool shopRegisteredByUser = false;
  final List<Customer> customers = [];
  final List<CustomerChart> charts = [];
  final List<CustomerReview> reviews = [];
  final List<AiReply> aiReplies = [];
  final List<String> skinJournalEntries = [];

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

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  static String phoneLast4(String phone) {
    final d = normalizePhone(phone);
    if (d.length < 4) return d;
    return d.substring(d.length - 4);
  }

  void _seed() {
    shop = const Shop(
      id: 'shop-demo',
      name: 'SORI 에스테틱',
      ownerName: '김원장',
      phone: '02-1234-5678',
      naverPlaceUrl: 'https://m.place.naver.com/place/sori-demo',
      address: '서울시 강남구',
    );

    customers.addAll([
      Customer(
        id: '1',
        shopId: shop.id,
        name: '김민지',
        phone: '010-1234-5678',
        lastTreatmentDate: DateTime(2026, 8, 5),
        treatmentType: '재생케어',
        memo: '두피 민감, 자연 펌 선호',
        membershipTotalVisits: 0,
      ),
      Customer(
        id: '2',
        shopId: shop.id,
        name: '이수진',
        phone: '010-2345-6789',
        lastTreatmentDate: DateTime(2026, 8, 3),
        treatmentType: '수분케어',
        memo: '정기 예약 고객',
        membershipTotalVisits: 5,
      ),
      Customer(
        id: '3',
        shopId: shop.id,
        name: '박서연',
        phone: '010-3456-7890',
        lastTreatmentDate: DateTime(2026, 7, 28),
        treatmentType: '재생케어',
        memo: '트리트먼트 관심 많음',
        membershipTotalVisits: 3,
      ),
    ]);

    charts.addAll([
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
    ]);
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

  /// 소셜 로그인 시뮬레이터 — 이름·전화 필수 수집 후 온보딩으로 연결.
  SessionUser beginSocialLogin({
    required SocialProvider provider,
    required String name,
    required String phone,
  }) {
    session = SessionUser(
      role: UserRole.guest,
      name: name.trim(),
      phone: phone.trim(),
      provider: provider,
      onboardingComplete: false,
      shopSetupComplete: false,
      activeMode: UserRole.customer,
    );
    _notify();
    return session!;
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
  }) {
    shop = shop.copyWith(
      name: name.trim(),
      naverPlaceUrl: naverPlaceUrl.trim(),
      address: address?.trim(),
      phone: phone?.trim(),
    );
    _notify();
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

  AiReply? aiReplyForReview(String reviewId) {
    try {
      return aiReplies.firstWhere((r) => r.reviewId == reviewId);
    } catch (_) {
      return null;
    }
  }

  /// Hash routing용 고객 딥링크: `/#/review?token=...` (GitHub Pages 404 방지)
  static String buildCustomerReviewUrl(String token) {
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
    final encoded = Uri.encodeQueryComponent(token);
    return '$origin$path#/review?token=$encoded';
  }

  void addCustomer(Customer customer) {
    customers.insert(0, customer);
    _notify();
  }

  /// 차트 저장 + visit_checked 트리거 → 토큰/리뷰 초안 생성.
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
  }) {
    final customer = findCustomer(customerId);
    if (customer == null) {
      throw StateError('Customer not found');
    }

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
        concernChips: concernChips,
        firstVisitFearChips: firstVisitFearChips,
        revisitFeedbackChips: revisitFeedbackChips,
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
      );
      charts.insert(0, chart);
    }

    final custIndex = customers.indexWhere((c) => c.id == customerId);
    customers[custIndex] = customers[custIndex].copyWith(
      lastTreatmentDate: DateTime.now(),
      treatmentType: careName.isNotEmpty ? careName : customer.treatmentType,
      membershipTotalVisits: visitNumber > 1
          ? visitNumber
          : customers[custIndex].membershipTotalVisits,
    );

    return confirmVisit(chartId: chart.id);
  }

  CustomerChart confirmVisit({
    required String chartId,
    List<String> puzzleSelections = const [
      '피부 톤이 밝아졌어요',
      '시술 후 자극이 적었어요',
    ],
  }) {
    final index = charts.indexWhere((c) => c.id == chartId);
    if (index < 0) {
      throw StateError('Chart not found: $chartId');
    }

    final opened = _visitTrigger.markVisitChecked(charts[index]);
    charts[index] = opened;

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
