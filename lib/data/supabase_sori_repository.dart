import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../services/supabase_client.dart';
import 'sori_repository.dart';

/// Supabase SDK 실연동 Repository.
class SupabaseSoriRepository implements SoriRepository {
  SupabaseSoriRepository();

  SupabaseClient get _db {
    final c = SoriSupabase.clientOrNull;
    if (c == null) {
      throw StateError('Supabase client is not initialized');
    }
    return c;
  }

  @override
  bool get isRemote => true;

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _customerWriteMap(Customer c, {bool includeId = true}) {
    // 차트 전용 메디컬 필드(allergy/home_care 등)는 customers payload에서 제외
    final map = <String, dynamic>{
      'shop_id': c.shopId,
      'name': c.name,
      'phone': c.phone,
      'last_treatment_date': _dateOnly(c.lastTreatmentDate),
      'treatment_type': c.treatmentType,
      'memo': c.memo,
      'membership_service_name': c.membershipServiceName,
      'membership_total_visits': c.membershipTotalVisits,
      'membership_used_visits': c.membershipUsedVisits,
      'gender': c.gender?.dbValue,
      'birth_date': c.birthDate == null ? null : _dateOnly(c.birthDate!),
      'address': c.address,
      'occupation': c.occupation,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && c.id.isNotEmpty && !_isTempId(c.id)) {
      map['id'] = c.id;
    }
    return map;
  }

  Map<String, dynamic> _chartWriteMap(CustomerChart c, {bool includeId = true}) {
    final map = <String, dynamic>{
      'shop_id': c.shopId,
      'customer_id': c.customerId,
      'visit_number': c.visitNumber,
      'custom_chart_no': c.customChartNo,
      'visit_checked': c.visitChecked,
      'visit_checked_at': c.visitCheckedAt?.toUtc().toIso8601String(),
      'before_image_url': c.beforeImageUrl,
      'after_image_url': c.afterImageUrl,
      'care_name': c.careName,
      'treatment_summary': c.treatmentSummary,
      'director_insight': c.directorInsight,
      'allergy_notes': c.allergyNotes,
      'skin_sensitivity': c.skinSensitivity,
      'side_effect_history': c.sideEffectHistory,
      'concern_chips': c.concernChips,
      'first_visit_fear_chips': c.firstVisitFearChips,
      'revisit_feedback_chips': c.revisitFeedbackChips,
      'feedback_token': c.feedbackToken,
      'feedback_line_opened_at':
          c.feedbackLineOpenedAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && c.id.isNotEmpty && !_isTempId(c.id)) {
      map['id'] = c.id;
    }
    return map;
  }

  bool _isTempId(String id) =>
      id.startsWith('chart-') ||
      id.startsWith('c-') ||
      id == 'shop-demo' ||
      RegExp(r'^\d+$').hasMatch(id);

  List<T> _mapRowsSafely<T>(
    List<dynamic> rows,
    T Function(Map<String, dynamic>) fromMap, {
    required String label,
  }) {
    final out = <T>[];
    for (final raw in rows) {
      try {
        if (raw is! Map) continue;
        out.add(fromMap(Map<String, dynamic>.from(raw)));
      } catch (e, st) {
        debugPrint('skip malformed $label row: $e\n$st');
      }
    }
    return out;
  }

  Future<List<dynamic>> _selectCustomers(String shopId) async {
    try {
      return await _db
          .from('customers')
          .select()
          .eq('shop_id', shopId)
          .order('updated_at', ascending: false);
    } catch (e) {
      debugPrint('customers order by updated_at failed, fallback: $e');
      return await _db.from('customers').select().eq('shop_id', shopId);
    }
  }

  @override
  Future<SoriSnapshot> loadInitialData() async {
    // 행 파싱·부분 테이블 실패는 흡수하고, shops 쿼리 자체 장애만 상위로 전달한다.
    const fallbackShop = Shop(
      id: '',
      name: 'SORI 에스테틱',
      ownerName: '김원장',
      phone: '02-1234-5678',
      naverPlaceUrl: 'https://m.place.naver.com/place/sori-demo',
      address: '서울시 강남구',
    );

    late final Shop shop;
    try {
      final shops = await _db
          .from('shops')
          .select()
          .order('created_at', ascending: true)
          .limit(1);
      final parsedShops = _mapRowsSafely(
        shops as List,
        Shop.fromMap,
        label: 'shops',
      );
      if (parsedShops.isNotEmpty) {
        shop = parsedShops.first;
      } else {
        try {
          shop = await upsertShop(fallbackShop);
        } catch (e) {
          debugPrint('shops upsert fallback kept local shop: $e');
          shop = fallbackShop;
        }
      }
    } catch (e, st) {
      debugPrint('SupabaseSoriRepository.loadInitialData shops failed: $e\n$st');
      rethrow;
    }

    List<Customer> customers = const [];
    try {
      final customerRows = await _selectCustomers(shop.id);
      customers = _mapRowsSafely(
        customerRows,
        Customer.fromMap,
        label: 'customers',
      );
    } catch (e, st) {
      debugPrint('customers load skipped: $e\n$st');
    }

    List<CustomerChart> charts = const [];
    try {
      final chartRows = await _db
          .from('customer_charts')
          .select()
          .eq('shop_id', shop.id)
          .order('visit_number', ascending: false);
      charts = _mapRowsSafely(
        chartRows as List,
        CustomerChart.fromMap,
        label: 'customer_charts',
      );
    } catch (e, st) {
      debugPrint('customer_charts load skipped: $e\n$st');
    }

    List<CustomerReview> reviews = const [];
    try {
      final reviewRows = await _db
          .from('customer_reviews')
          .select()
          .eq('shop_id', shop.id)
          .order('created_at', ascending: false);
      reviews = _mapRowsSafely(
        reviewRows as List,
        CustomerReview.fromMap,
        label: 'customer_reviews',
      );
    } catch (e, st) {
      debugPrint('customer_reviews load skipped: $e\n$st');
    }

    List<AiReply> aiReplies = const [];
    try {
      final aiRows = await _db.from('ai_replies').select().limit(100);
      aiReplies = _mapRowsSafely(
        aiRows as List,
        AiReply.fromMap,
        label: 'ai_replies',
      );
    } catch (e) {
      debugPrint('ai_replies load skipped: $e');
    }

    return SoriSnapshot(
      shop: shop,
      customers: customers,
      charts: charts,
      reviews: reviews,
      aiReplies: aiReplies,
      gallerySlides: const [
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
      ],
    );
  }

  @override
  Future<Customer?> findCustomerByPhone(String phone, {String? shopId}) async {
    final digits = _digits(phone);
    if (digits.length < 10) return null;

    late final List<dynamic> rows;
    if (shopId != null && shopId.isNotEmpty && !_isTempId(shopId)) {
      rows = await _db
          .from('customers')
          .select()
          .eq('shop_id', shopId)
          .limit(200);
    } else {
      rows = await _db.from('customers').select().limit(200);
    }
    final list = _mapRowsSafely(
      rows,
      Customer.fromMap,
      label: 'customers',
    );
    try {
      return list.firstWhere((c) => _digits(c.phone) == digits);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) async {
    final includeId = customer.id.isNotEmpty && !_isTempId(customer.id);
    final payload = _customerWriteMap(customer, includeId: includeId);
    final row = includeId
        ? await _db
            .from('customers')
            .upsert(payload)
            .select()
            .single()
        : await _db.from('customers').insert(payload).select().single();
    return Customer.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<Customer> registerCustomer({
    required String shopId,
    required String name,
    required String phone,
    String memo = '',
  }) async {
    final payload = <String, dynamic>{
      'shop_id': shopId,
      'name': name.trim(),
      'phone': phone.trim(),
      'memo': memo.trim(),
    };
    final row =
        await _db.from('customers').insert(payload).select().single();
    return Customer.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<Shop> upsertShop(Shop shop) async {
    final payload = <String, dynamic>{
      'name': shop.name,
      'owner_name': shop.ownerName ?? '',
      'phone': shop.phone,
      'naver_place_url': shop.naverPlaceUrl,
      'address': shop.address,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final includeId = shop.id.isNotEmpty && !_isTempId(shop.id);
    if (includeId) payload['id'] = shop.id;

    final row = includeId
        ? await _db.from('shops').upsert(payload).select().single()
        : await _db.from('shops').insert(payload).select().single();
    return Shop.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<SaveChartResult> saveChartAndConfirmVisit(
    SaveChartRequest request,
  ) async {
    final existingCustomer = await _db
        .from('customers')
        .select()
        .eq('id', request.customerId)
        .maybeSingle();
    if (existingCustomer == null) {
      throw StateError('Customer not found: ${request.customerId}');
    }
    var customer =
        Customer.fromMap(Map<String, dynamic>.from(existingCustomer));

    final total =
        (request.membershipTotalVisits ?? customer.membershipTotalVisits)
            .clamp(0, 999);
    var used = (request.membershipUsedVisits ?? customer.membershipUsedVisits)
        .clamp(0, 999);
    if (total > 0 && used > total) used = total;

    customer = customer.copyWith(
      name: request.customerName?.trim().isNotEmpty == true
          ? request.customerName!.trim()
          : customer.name,
      phone: request.customerPhone?.trim().isNotEmpty == true
          ? request.customerPhone!.trim()
          : customer.phone,
      gender: request.gender,
      birthDate: request.birthDate,
      address: request.address ?? customer.address,
      occupation: request.occupation ?? customer.occupation,
      lastTreatmentDate: DateTime.now(),
      treatmentType: request.careName.isNotEmpty
          ? request.careName
          : customer.treatmentType,
      membershipServiceName:
          request.membershipServiceName ?? customer.membershipServiceName,
      membershipTotalVisits: total,
      membershipUsedVisits: used,
    );

    // 차트 upsert (방문 확인 전)
    CustomerChart chart;
    final existingChartId = request.chartId;
    var wasChecked = false;
    if (existingChartId != null && !_isTempId(existingChartId)) {
      final existing = await _db
          .from('customer_charts')
          .select()
          .eq('id', existingChartId)
          .maybeSingle();
      if (existing != null) {
        wasChecked =
            (existing['visit_checked'] as bool?) ?? false;
        final base =
            CustomerChart.fromMap(Map<String, dynamic>.from(existing));
        chart = base.copyWith(
          visitNumber: request.visitNumber,
          customChartNo: request.customChartNo,
          careName: request.careName,
          treatmentSummary: request.treatmentSummary,
          directorInsight: request.directorInsight,
          allergyNotes: request.allergyNotes ?? base.allergyNotes,
          skinSensitivity: request.skinSensitivity ?? base.skinSensitivity,
          sideEffectHistory:
              request.sideEffectHistory ?? base.sideEffectHistory,
          concernChips: request.concernChips,
          firstVisitFearChips: request.firstVisitFearChips,
          revisitFeedbackChips: request.revisitFeedbackChips,
          beforeImageUrl: request.beforeImageUrl,
          afterImageUrl: request.afterImageUrl,
          clearCustomChartNo: request.customChartNo == null ||
              request.customChartNo!.trim().isEmpty,
        );
        final updated = await _db
            .from('customer_charts')
            .update(_chartWriteMap(chart, includeId: false))
            .eq('id', chart.id)
            .select()
            .single();
        chart = CustomerChart.fromMap(Map<String, dynamic>.from(updated));
      } else {
        chart = await _insertChart(request, customer.shopId);
      }
    } else {
      chart = await _insertChart(request, customer.shopId);
    }

    // 방문 확인 → DB trigger가 feedback_token 발급
    if (!chart.visitChecked) {
      final opened = await _db
          .from('customer_charts')
          .update({
            'visit_checked': true,
            'visit_checked_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', chart.id)
          .select()
          .single();
      chart = CustomerChart.fromMap(Map<String, dynamic>.from(opened));
    }

    // 회원권 차감 (방문 첫 확인 시에만)
    if (request.deductMembership &&
        !wasChecked &&
        customer.isMembershipCustomer &&
        customer.membershipUsedVisits < customer.membershipTotalVisits) {
      customer = customer.copyWith(
        membershipUsedVisits: customer.membershipUsedVisits + 1,
      );
    }

    customer = await upsertCustomer(customer);

    // 리뷰 초안
    CustomerReview? review;
    final existingReview = await _db
        .from('customer_reviews')
        .select()
        .eq('chart_id', chart.id)
        .maybeSingle();
    if (existingReview == null) {
      final draftText =
          '${customer.name}님, ${chart.careName.isNotEmpty ? chart.careName : customer.treatmentType} 후기 초안';
      final inserted = await _db
          .from('customer_reviews')
          .insert({
            'chart_id': chart.id,
            'customer_id': customer.id,
            'shop_id': customer.shopId,
            'puzzle_selections': const [
              '피부 톤이 밝아졌어요',
              '시술 후 자극이 적었어요',
            ],
            'original_text': draftText,
            'status': 'draft',
            'naver_registered': false,
          })
          .select()
          .single();
      review =
          CustomerReview.fromMap(Map<String, dynamic>.from(inserted));
    } else {
      review =
          CustomerReview.fromMap(Map<String, dynamic>.from(existingReview));
    }

    return SaveChartResult(chart: chart, customer: customer, review: review);
  }

  Future<CustomerChart> _insertChart(
    SaveChartRequest request,
    String shopId,
  ) async {
    final payload = <String, dynamic>{
      'shop_id': shopId,
      'customer_id': request.customerId,
      'visit_number': request.visitNumber,
      'custom_chart_no': request.customChartNo?.trim().isEmpty == true
          ? null
          : request.customChartNo?.trim(),
      'visit_checked': false,
      'before_image_url': request.beforeImageUrl,
      'after_image_url': request.afterImageUrl,
      'care_name': request.careName,
      'treatment_summary': request.treatmentSummary,
      'director_insight': request.directorInsight,
      'allergy_notes': request.allergyNotes ?? '',
      'skin_sensitivity': request.skinSensitivity ?? '',
      'side_effect_history': request.sideEffectHistory ?? '',
      'concern_chips': request.concernChips,
      'first_visit_fear_chips': request.firstVisitFearChips,
      'revisit_feedback_chips': request.revisitFeedbackChips,
    };
    final row =
        await _db.from('customer_charts').insert(payload).select().single();
    return CustomerChart.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerReview> upsertReview(CustomerReview review) async {
    final payload = review.toMap();
    payload.remove('id');
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (review.id.isNotEmpty && !_isTempId(review.id)) {
      final row = await _db
          .from('customer_reviews')
          .update(payload)
          .eq('id', review.id)
          .select()
          .single();
      return CustomerReview.fromMap(Map<String, dynamic>.from(row));
    }
    final row =
        await _db.from('customer_reviews').insert(payload).select().single();
    return CustomerReview.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerReview?> markNaverRegistered({
    required String chartId,
    String? composedText,
  }) async {
    final existing = await _db
        .from('customer_reviews')
        .select()
        .eq('chart_id', chartId)
        .maybeSingle();

    final now = DateTime.now().toUtc().toIso8601String();
    if (existing == null) {
      // 차트만 있고 리뷰 행이 없으면 최소 행 생성
      final chart = await _db
          .from('customer_charts')
          .select()
          .eq('id', chartId)
          .maybeSingle();
      if (chart == null) return null;
      final inserted = await _db
          .from('customer_reviews')
          .insert({
            'chart_id': chartId,
            'customer_id': chart['customer_id'],
            'shop_id': chart['shop_id'],
            'puzzle_selections': const <String>[],
            'original_text': composedText ?? '',
            'edited_text': composedText,
            'status': 'published',
            'naver_registered': true,
            'naver_registered_at': now,
          })
          .select()
          .single();
      return CustomerReview.fromMap(Map<String, dynamic>.from(inserted));
    }

    final updated = await _db
        .from('customer_reviews')
        .update({
          'naver_registered': true,
          'naver_registered_at': now,
          if (composedText != null && composedText.trim().isNotEmpty)
            'edited_text': composedText.trim(),
          'status': 'published',
          'updated_at': now,
        })
        .eq('id', existing['id'])
        .select()
        .single();
    return CustomerReview.fromMap(Map<String, dynamic>.from(updated));
  }
}
