import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_reply.dart';
import '../models/care_diary_note.dart';
import '../models/chart_db_columns.dart';
import '../models/case_timeline_entry.dart';
import '../models/community_case_item.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/home_care_prescriptions.dart';
import '../models/kakao_alimtalk.dart';
import '../models/membership_ticket.dart';
import '../models/review_reply.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_post.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../models/affiliate_earnings.dart';
import '../models/sori_point_wallet.dart';
import '../models/point_shop.dart';
import '../models/fan_supporter.dart';
import '../models/seminar_class.dart';
import '../models/seminar_application.dart';
import '../models/seminar_class_detail.dart';
import '../models/seminar_education_insight.dart';
import '../models/seminar_feedback_report.dart';
import '../models/seminar_enrollment.dart';
import '../models/shop_highlight.dart';
import '../models/shop_tier_badge.dart';
import '../models/subscription.dart';
import '../services/supabase_client.dart';
import '../utils/db_map.dart';
import '../utils/storage_image_url.dart';
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

  /// 차트 SSOT: `chart_records` (customer_charts 미러 뷰) → 폴백 `customer_charts`.
  static const String _chartsPrimary = ChartDbColumns.relation;
  static const String _chartsFallback = ChartDbColumns.physicalTable;

  /// 쓰기 우선순위: 물리 테이블 먼저(트리거·지갑 연동), 이후 뷰/관계명.
  /// chart_records 가 BASE TABLE 인 환경에서 뷰만 읽고 물리만 쓰는 불일치를 막는다.
  static const List<String> _chartsWriteOrder = [
    _chartsFallback,
    _chartsPrimary,
  ];

  Future<T> _withChartsTable<T>(
    Future<T> Function(String table) run,
  ) async {
    try {
      return await run(_chartsPrimary);
    } catch (e) {
      debugPrint('$_chartsPrimary failed, fallback $_chartsFallback: $e');
      return run(_chartsFallback);
    }
  }

  /// 양 테이블/뷰를 병합해 차트 로드 (한쪽만 쓰인 행도 타임라인에 표시).
  Future<List<Map<String, dynamic>>> _loadMergedChartRows({
    required String shopId,
  }) async {
    final byId = <String, Map<String, dynamic>>{};
    for (final table in {_chartsPrimary, _chartsFallback}) {
      try {
        final rows = await _db
            .from(table)
            .select()
            .eq('shop_id', shopId)
            .order('visit_number', ascending: false);
        for (final raw in rows as List) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final id = map['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          byId.putIfAbsent(id, () => map);
        }
      } catch (e) {
        debugPrint('charts load via $table skipped: $e');
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) {
      final va = DbMap.asInt(a['visit_number']);
      final vb = DbMap.asInt(b['visit_number']);
      return vb.compareTo(va);
    });
    return list;
  }

  /// PGRST204 방어: 스키마에 없는 컬럼 키를 페이로드에서 제거 후 재시도.
  Map<String, dynamic> _stripUnknownColumn(
    Map<String, dynamic> payload,
    Object error, {
    Set<String> protectedKeys = const {},
  }) {
    final msg = error.toString();
    final match = RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(msg);
    if (match == null) return payload;
    final col = match.group(1);
    if (col == null || col.isEmpty) return payload;
    if (protectedKeys.contains(col)) {
      debugPrint(
        'Refusing to strip protected column "$col" (would cause null FK)',
      );
      return payload;
    }
    final next = Map<String, dynamic>.from(payload)..remove(col);
    debugPrint('Removed unknown column from payload: $col');
    return next;
  }

  Map<String, dynamic> _stripUnknownChartColumn(
    Map<String, dynamic> payload,
    Object error,
  ) =>
      _stripUnknownColumn(
        payload,
        error,
        protectedKeys: ChartDbColumns.protectedWriteKeys,
      );

  /// insert/update 직전 — customer_id / shop_id 강제 주입·검증.
  void _ensureChartFkPayload(
    Map<String, dynamic> payload, {
    required String customerId,
    required String shopId,
  }) {
    final cid = customerId.trim();
    final sid = shopId.trim();
    if (cid.isEmpty) {
      throw StateError('chart payload blocked: customer_id is empty');
    }
    if (sid.isEmpty) {
      throw StateError('chart payload blocked: shop_id is empty');
    }
    payload['customer_id'] = cid;
    payload['shop_id'] = sid;
  }

  bool _chartPayloadHasCustomerId(Map<String, dynamic> payload) {
    final raw = payload['customer_id'];
    if (raw == null) return false;
    return raw.toString().trim().isNotEmpty;
  }

  /// Postgres unique_violation (23505) — (customer_id, visit_number) 충돌 감지.
  bool _isVisitNumberUniqueViolation(Object e) {
    if (e is PostgrestException && e.code == '23505') return true;
    final s = '$e'.toLowerCase();
    return s.contains('23505') ||
        s.contains('duplicate key') ||
        s.contains('unique constraint') ||
        s.contains('customer_id_visit_number') ||
        (s.contains('visit_number') && s.contains('unique'));
  }

  /// 차트 insert — chart_records 우선. PGRST204 strip / 회차 유니크 충돌 시 재시도.
  Future<Map<String, dynamic>> _insertChartRow(
    Map<String, dynamic> payload, {
    required String customerId,
    required String shopId,
  }) async {
    var body = Map<String, dynamic>.from(payload);
    _ensureChartFkPayload(body, customerId: customerId, shopId: shopId);
    Object? lastError;
    var visitBumpBudget = 24;
    for (var attempt = 0; attempt < 40; attempt++) {
      var progressed = false;
      for (final table in _chartsWriteOrder) {
        try {
          _ensureChartFkPayload(
            body,
            customerId: customerId,
            shopId: shopId,
          );
          if (!_chartPayloadHasCustomerId(body)) {
            throw StateError('refusing chart insert without customer_id');
          }
          final row =
              await _db.from(table).insert(body).select().single();
          return Map<String, dynamic>.from(row);
        } catch (e) {
          lastError = e;
          final stripped = _stripUnknownChartColumn(body, e);
          if (stripped.length != body.length) {
            body = stripped;
            _ensureChartFkPayload(
              body,
              customerId: customerId,
              shopId: shopId,
            );
            progressed = true;
            debugPrint(
              'chart insert PGRST204 strip → retry ($table, keys=${body.length})',
            );
            break;
          }
          if (_isVisitNumberUniqueViolation(e) && visitBumpBudget > 0) {
            final current = DbMap.asInt(body['visit_number'], 1);
            final next = current < 1 ? 1 : current + 1;
            body['visit_number'] = next;
            visitBumpBudget -= 1;
            progressed = true;
            debugPrint(
              'chart insert unique(visit_number) → bump $current→$next ($table)',
            );
            break;
          }
          debugPrint('insert chart via $table failed: $e');
        }
      }
      if (!progressed) break;
    }
    throw lastError ?? StateError('chart insert failed');
  }

  Future<Map<String, dynamic>> _updateChartRow({
    required String chartId,
    required Map<String, dynamic> payload,
    String? customerId,
    String? shopId,
  }) async {
    var body = Map<String, dynamic>.from(payload);
    final cid = (customerId ?? body['customer_id']?.toString() ?? '').trim();
    final sid = (shopId ?? body['shop_id']?.toString() ?? '').trim();
    if (cid.isNotEmpty && sid.isNotEmpty) {
      _ensureChartFkPayload(body, customerId: cid, shopId: sid);
    }
    Object? lastError;
    for (var attempt = 0; attempt < 40; attempt++) {
      var progressed = false;
      for (final table in _chartsWriteOrder) {
        try {
          if (cid.isNotEmpty && sid.isNotEmpty) {
            _ensureChartFkPayload(body, customerId: cid, shopId: sid);
          }
          final row = await _db
              .from(table)
              .update(body)
              .eq('id', chartId)
              .select()
              .single();
          return Map<String, dynamic>.from(row);
        } catch (e) {
          lastError = e;
          final stripped = _stripUnknownChartColumn(body, e);
          if (stripped.length != body.length) {
            body = stripped;
            if (cid.isNotEmpty && sid.isNotEmpty) {
              _ensureChartFkPayload(body, customerId: cid, shopId: sid);
            }
            progressed = true;
            debugPrint(
              'chart update PGRST204 strip → retry ($table, keys=${body.length})',
            );
            break;
          }
          debugPrint('update chart via $table failed: $e');
        }
      }
      if (!progressed) break;
    }
    throw lastError ?? StateError('chart update failed');
  }

  Future<Map<String, dynamic>?> _selectChartById(String chartId) async {
    return _withChartsTable((table) async {
      final row = await _db.from(table).select().eq('id', chartId).maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    });
  }

  @override
  bool get isRemote => true;

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Before/After 미첨부·빈 문자열은 DB null로 고정.
  static String? _imageUrlOrNull(String? value) =>
      StorageImageUrl.resolve(DbMap.asTextOrNull(value));

  /// TEXT 컬럼용: null/공백 → '' (스키마 default '' 와 호환, 에러 방지).
  static String _textOrEmpty(String? value) =>
      (value ?? '').trim();

  static int? _communityAge(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      final v = raw.toInt();
      return v > 0 ? v : null;
    }
    return int.tryParse('$raw');
  }

  static int? _ageFromBirth(DateTime? birth) {
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  Future<Map<String, ({int? age, String? gender})>> _loadCustomerFeedPersona(
    Iterable<String> customerIds,
  ) async {
    final ids =
        customerIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final out = <String, ({int? age, String? gender})>{};
    if (ids.isEmpty) return out;
    try {
      final rows = await _db
          .from('customers')
          .select('id, gender, birth_date')
          .inFilter('id', ids.toList());
      for (final raw in rows as List) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = DbMap.asText(map['id']);
        if (id.isEmpty) continue;
        final gender = CustomerGenderX.fromDb(DbMap.asTextOrNull(map['gender']));
        out[id] = (
          age: _ageFromBirth(DbMap.asDateTime(map['birth_date'])),
          gender: gender?.label,
        );
      }
    } catch (e) {
      debugPrint('community customer persona join skipped: $e');
    }
    return out;
  }

  CustomerChart _chartFromSaveRequest(
    SaveChartRequest request,
    String shopId, {
    String id = '',
    bool visitChecked = false,
    DateTime? visitCheckedAt,
    String? feedbackToken,
    DateTime? feedbackLineOpenedAt,
  }) {
    return CustomerChart(
      id: id,
      shopId: shopId,
      customerId: request.customerId.trim(),
      visitNumber: request.visitNumber < 1 ? 1 : request.visitNumber,
      customChartNo: DbMap.asTextOrNull(request.customChartNo),
      visitChecked: visitChecked,
      visitCheckedAt: visitCheckedAt,
      beforeImageUrl: _imageUrlOrNull(request.beforeImageUrl),
      afterImageUrl: _imageUrlOrNull(request.afterImageUrl),
      careName: _textOrEmpty(request.careName),
      deviceInfo: DbMap.asTextOrNull(request.deviceInfo),
      treatmentSummary: _textOrEmpty(request.treatmentSummary),
      directorInsight: _textOrEmpty(request.directorInsight),
      allergyNotes: _textOrEmpty(request.allergyNotes),
      skinSensitivity: _textOrEmpty(request.skinSensitivity),
      sideEffectHistory: _textOrEmpty(request.sideEffectHistory),
      customerRequests: _textOrEmpty(request.customerRequests),
      concernChips: DbMap.sanitizeStringList(request.concernChips),
      firstVisitFearChips:
          DbMap.sanitizeStringList(request.firstVisitFearChips),
      revisitFeedbackChips:
          DbMap.sanitizeStringList(request.revisitFeedbackChips),
      feedbackToken: DbMap.asTextOrNull(feedbackToken),
      feedbackLineOpenedAt: feedbackLineOpenedAt,
      consentMandatory: request.consentMandatory,
      consentPhoto: request.consentPhoto,
      consentMarketing: request.consentMarketing,
      consentOfflineOnly: request.consentOfflineOnly,
      signatureUrl: _imageUrlOrNull(request.signatureUrl),
      homeCarePrescriptions:
          HomecareDictionary.sanitizeTagIds(request.homeCarePrescriptions),
      guardianPhone: () {
        final digits =
            (request.guardianPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        return digits.isEmpty ? null : digits;
      }(),
      infoViewConsent: request.infoViewConsent,
    );
  }

  Map<String, dynamic> _customerWriteMap(Customer c, {bool includeId = true}) {
    // 단일 소스: Customer.toDbWriteMap
    // 제외: allergy_notes / medication_history / home_care_habits (차트 SSOT)
    final map = c.toDbWriteMap(includeId: false);
    if (includeId && c.id.isNotEmpty && !_isTempId(c.id)) {
      map['id'] = c.id;
    }
    return map;
  }

  Future<Map<String, dynamic>> _upsertCustomerRow(
    Map<String, dynamic> payload, {
    required bool includeId,
  }) async {
    var body = Map<String, dynamic>.from(payload);
    Object? lastError;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final row = includeId
            ? await _db.from('customers').upsert(body).select().single()
            : await _db.from('customers').insert(body).select().single();
        return Map<String, dynamic>.from(row);
      } catch (e) {
        lastError = e;
        final stripped = _stripUnknownColumn(body, e);
        if (stripped.length != body.length) {
          body = stripped;
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? StateError('customers upsert failed');
  }

  Map<String, dynamic> _chartWriteMap(CustomerChart c, {bool includeId = true}) {
    // temp id는 DB에 보내지 않음
    final map = (includeId && c.id.isNotEmpty && !_isTempId(c.id))
        ? c.toDbWriteMap(includeId: true)
        : c.toDbWriteMap(includeId: false);
    // 빈 문자열 customer_id 가 JSON null 로 떨어지는 경로 차단
    final cid = c.customerId.trim();
    final sid = c.shopId.trim();
    if (cid.isNotEmpty) map['customer_id'] = cid;
    if (sid.isNotEmpty) map['shop_id'] = sid;
    assert(() {
      for (final key in map.keys) {
        if (!ChartDbColumns.writeKeys.contains(key)) {
          debugPrint('WARN chart payload unknown key vs ChartDbColumns: $key');
        }
      }
      return true;
    }());
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
    // 행 파싱·부분 테이블 실패는 흡수하고, shops 조회 실패 시에도 로컬 폴백으로 부트스트랩 유지.
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
      Shop? preferred;
      final uid = _db.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        try {
          final owned = await _db
              .from('shops')
              .select()
              .eq('owner_user_id', uid)
              .limit(1);
          final parsedOwned = _mapRowsSafely(
            owned as List,
            Shop.fromMap,
            label: 'shops.owned',
          );
          if (parsedOwned.isNotEmpty) preferred = parsedOwned.first;
        } catch (e) {
          debugPrint('owned shop lookup skipped: $e');
        }
      }

      if (preferred != null) {
        shop = preferred;
      } else {
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
      }
    } catch (e, st) {
      debugPrint(
        'SupabaseSoriRepository.loadInitialData shops failed, using fallback: $e\n$st',
      );
      shop = fallbackShop;
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
      final chartRows = await _loadMergedChartRows(shopId: shop.id);
      charts = _mapRowsSafely(
        chartRows,
        CustomerChart.fromMap,
        label: 'chart_records+customer_charts',
      );
    } catch (e, st) {
      debugPrint('charts load skipped: $e\n$st');
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

    List<CareDiaryNote> diaryNotes = const [];
    try {
      final diaryRows = await _db
          .from('care_diary_notes')
          .select()
          .eq('shop_id', shop.id)
          .order('note_date', ascending: false);
      diaryNotes = _mapRowsSafely(
        diaryRows as List,
        CareDiaryNote.fromMap,
        label: 'care_diary_notes',
      );
    } catch (e) {
      debugPrint('care_diary_notes load skipped: $e');
    }

    List<ShopGallerySlide> gallerySlides = const [];
    try {
      gallerySlides = await loadShopGalleryItems(shop.id);
    } catch (e) {
      debugPrint('shop_gallery_items load skipped: $e');
    }

    List<ShopPost> shopPosts = const [];
    try {
      shopPosts = await loadShopPosts(shop.id);
    } catch (e) {
      debugPrint('shop_posts load skipped: $e');
    }

    List<SeminarClass> seminarClasses = const [];
    try {
      seminarClasses = await loadSeminarClassesForShop(shop.id);
    } catch (e) {
      debugPrint('seminar_classes load skipped: $e');
    }

    return SoriSnapshot(
      shop: shop,
      customers: customers,
      charts: charts,
      reviews: reviews,
      aiReplies: aiReplies,
      diaryNotes: diaryNotes,
      gallerySlides: gallerySlides,
      shopPosts: shopPosts,
      seminarClasses: seminarClasses,
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
    final row = await _upsertCustomerRow(payload, includeId: includeId);
    final saved = Customer.fromMap(row);
    try {
      await syncMembershipTicketsForCustomer(saved.id);
    } catch (e) {
      debugPrint('syncMembershipTicketsForCustomer skipped: $e');
    }
    return saved;
  }

  @override
  Future<void> syncMembershipTicketsForCustomer(String customerId) async {
    if (customerId.isEmpty || _isTempId(customerId)) return;
    try {
      await _db.rpc(
        'sync_membership_tickets_for_customer',
        params: {'p_customer_id': customerId},
      );
    } catch (e) {
      // 마이그레이션 미적용 시 직접 upsert 폴백
      debugPrint('sync rpc failed, local upsert fallback: $e');
      await _fallbackSyncMembershipTickets(customerId);
    }
  }

  Future<void> _fallbackSyncMembershipTickets(String customerId) async {
    try {
      final row = await _db
          .from('customers')
          .select('id, shop_id, phone, memberships')
          .eq('id', customerId)
          .maybeSingle();
      if (row == null) return;
      final phone = _digits(DbMap.asText(row['phone']));
      final shopId = DbMap.asText(row['shop_id']);
      final memberships = <CustomerMembership>[];
      final raw = row['memberships'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            memberships.add(
              CustomerMembership.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      await _db.from('membership_tickets').delete().eq('customer_id', customerId);
      for (final m in memberships) {
        if (m.totalVisits <= 0) continue;
        await _db.from('membership_tickets').upsert({
          'id': m.id,
          'shop_id': shopId,
          'customer_id': customerId,
          'customer_phone_digits': phone,
          'ticket_name': m.serviceName,
          'total_visits': m.totalVisits,
          'used_visits': m.usedVisits,
          'expires_at': m.expiresAt == null
              ? null
              : '${m.expiresAt!.year.toString().padLeft(4, '0')}-${m.expiresAt!.month.toString().padLeft(2, '0')}-${m.expiresAt!.day.toString().padLeft(2, '0')}',
          'is_active': m.remainingVisits > 0,
          'paid_amount': m.paidAmount,
          'per_session_value': m.effectivePerSession,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('_fallbackSyncMembershipTickets skipped: $e');
    }
  }

  @override
  Future<List<MembershipTicket>> loadMembershipWallet({
    String? phone,
    String? authUserId,
  }) async {
    final digits = _digits(phone ?? '');
    try {
      var query = _db.from('membership_tickets').select(
            '*, shops(id, name, naver_place_url)',
          );
      if (digits.isNotEmpty) {
        query = query.eq('customer_phone_digits', digits);
      } else if (authUserId != null && authUserId.isNotEmpty) {
        final linked = await _db
            .from('customers')
            .select('id')
            .eq('user_id', authUserId);
        final ids = (linked as List)
            .map((e) => DbMap.asText((e as Map)['id']))
            .where((id) => id.isNotEmpty)
            .toList();
        if (ids.isEmpty) return const [];
        query = query.inFilter('customer_id', ids);
      } else {
        return const [];
      }

      final rows = await query.order('updated_at', ascending: false);
      final tickets = _mapRowsSafely(
        rows as List,
        MembershipTicket.fromMap,
        label: 'membership_tickets',
      );
      return tickets
          .where((t) => t.totalVisits > 0 && t.remainingVisits >= 0)
          .toList();
    } catch (e, st) {
      debugPrint('loadMembershipWallet failed, phone fallback: $e\n$st');
      return _walletFromCustomersFallback(digits: digits, authUserId: authUserId);
    }
  }

  Future<List<MembershipTicket>> _walletFromCustomersFallback({
    required String digits,
    String? authUserId,
  }) async {
    try {
      final rows = await _db
          .from('customers')
          .select(
            'id, shop_id, phone, user_id, memberships, membership_service_name, membership_total_visits, membership_used_visits, shops(id, name, naver_place_url)',
          )
          .limit(300);
      final out = <MembershipTicket>[];
      for (final raw in rows as List) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final phoneMatch =
            digits.isNotEmpty && _digits(DbMap.asText(map['phone'])) == digits;
        final uidMatch = authUserId != null &&
            authUserId.isNotEmpty &&
            DbMap.asText(map['user_id']) == authUserId;
        if (!phoneMatch && !uidMatch) continue;
        final customer = Customer.fromMap(map).withSyncedMembershipMirrors();
        Map<String, dynamic>? shop;
        final rawShop = map['shops'];
        if (rawShop is Map) shop = Map<String, dynamic>.from(rawShop);
        final shopName = DbMap.asText(shop?['name'], 'SORI 샵');
        final naver = DbMap.asText(shop?['naver_place_url']);
        for (final m in customer.memberships) {
          if (m.totalVisits <= 0) continue;
          out.add(
            MembershipTicket(
              id: m.id,
              shopId: customer.shopId,
              customerId: customer.id,
              customerPhoneDigits: _digits(customer.phone),
              shopName: shopName,
              ticketName: m.serviceName.isEmpty ? '회원권' : m.serviceName,
              totalVisits: m.totalVisits,
              usedVisits: m.usedVisits,
              expiresAt: m.expiresAt,
              naverPlaceUrl: naver,
              isActive: m.remainingVisits > 0,
            ),
          );
        }
      }
      return out;
    } catch (e) {
      debugPrint('_walletFromCustomersFallback failed: $e');
      return const [];
    }
  }

  @override
  Future<Customer> registerCustomer({
    required String shopId,
    required String name,
    required String phone,
    String memo = '',
  }) async {
    var payload = <String, dynamic>{
      'shop_id': shopId,
      'name': name.trim(),
      'phone': phone.replaceAll(RegExp(r'[^0-9]'), ''),
      'memo': memo.trim(),
    };
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final row =
            await _db.from('customers').insert(payload).select().single();
        return Customer.fromMap(Map<String, dynamic>.from(row));
      } catch (e) {
        lastError = e;
        final stripped = _stripUnknownColumn(payload, e);
        if (stripped.length != payload.length) {
          payload = stripped;
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? StateError('registerCustomer failed');
  }

  @override
  Future<BulkDeleteResult> bulkDeleteCustomers(List<String> customerIds) async {
    final ids = customerIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const BulkDeleteResult(deletedIds: [], failedIds: []);
    }

    try {
      final raw = await _db.rpc(
        'delete_shop_customers',
        params: {'p_ids': ids},
      );
      final deleted = <String>[];
      if (raw is List) {
        for (final item in raw) {
          final id = item?.toString().trim() ?? '';
          if (id.isNotEmpty) deleted.add(id);
        }
      }
      final deletedSet = deleted.toSet();
      final failed =
          ids.where((id) => !deletedSet.contains(id)).toList(growable: false);
      return BulkDeleteResult(deletedIds: deleted, failedIds: failed);
    } catch (e, st) {
      debugPrint('delete_shop_customers rpc failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<Shop> upsertShop(Shop shop) async {
    final basePayload = <String, dynamic>{
      'name': shop.name,
      'owner_name': shop.ownerName ?? '',
      'phone': shop.phone,
      'naver_place_url': shop.naverPlaceUrl,
      'address': shop.address,
      'service_menu': shop.serviceMenu.map((e) => e.toMap()).toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final includeId = shop.id.isNotEmpty && !_isTempId(shop.id);
    if (includeId) basePayload['id'] = shop.id;

    // operating_hours / SNS 컬럼이 아직 없는 스키마에도 대응
    final fullPayload = <String, dynamic>{
      ...basePayload,
      'operating_hours': shop.operatingHours,
      'business_hours':
          shop.businessHours.isEmpty ? <String, dynamic>{} : shop.businessHours.toJson(),
      'equipment_items': shop.equipmentItems.map((e) => e.toMap()).toList(),
      'sns_blog_url': shop.snsBlogUrl,
      'sns_instagram_url': shop.snsInstagramUrl,
      'monthly_capa': shop.monthlyCapa,
      'bio': shop.bio,
      'profile_image_url': shop.profileImageUrl,
      'cover_image_url': shop.coverImageUrl,
      'naver_review_write_url': shop.naverReviewWriteUrl,
      'naver_booking_url': shop.naverBookingUrl,
    };

    try {
      final row = includeId
          ? await _db.from('shops').upsert(fullPayload).select().single()
          : await _db.from('shops').insert(fullPayload).select().single();
      final map = Map<String, dynamic>.from(row as Map);
      final parsed = Shop.fromMap(map);
      return parsed.copyWith(
        operatingHours: shop.operatingHours,
        businessHours: shop.businessHours,
        snsBlogUrl: shop.snsBlogUrl,
        snsInstagramUrl: shop.snsInstagramUrl,
        bio: map.containsKey('bio') ? parsed.bio : shop.bio,
        profileImageUrl: map.containsKey('profile_image_url')
            ? parsed.profileImageUrl
            : shop.profileImageUrl,
        coverImageUrl: map.containsKey('cover_image_url')
            ? parsed.coverImageUrl
            : shop.coverImageUrl,
        naverReviewWriteUrl: map.containsKey('naver_review_write_url')
            ? parsed.naverReviewWriteUrl
            : shop.naverReviewWriteUrl,
        naverBookingUrl: map.containsKey('naver_booking_url')
            ? parsed.naverBookingUrl
            : shop.naverBookingUrl,
        serviceMenu: shop.serviceMenu,
        equipmentItems: shop.equipmentItems,
        kakaoPoint:
            map.containsKey('kakao_point') ? parsed.kakaoPoint : shop.kakaoPoint,
        isPro: map.containsKey('is_pro') ? parsed.isPro : shop.isPro,
        monthlyCapa: map.containsKey('monthly_capa')
            ? parsed.monthlyCapa
            : shop.monthlyCapa,
      );
    } catch (e) {
      debugPrint('upsertShop with hours/SNS/bio failed, retrying base: $e');
      // bio/profile 컬럼 미적용 환경 — 제외 후 재시도
      final midPayload = <String, dynamic>{
        ...basePayload,
        'operating_hours': shop.operatingHours,
        'sns_blog_url': shop.snsBlogUrl,
        'sns_instagram_url': shop.snsInstagramUrl,
        'monthly_capa': shop.monthlyCapa,
        'bio': shop.bio,
        'profile_image_url': shop.profileImageUrl,
        'cover_image_url': shop.coverImageUrl,
        'equipment_items': shop.equipmentItems.map((e) => e.toMap()).toList(),
      };
      try {
        final row = includeId
            ? await _db.from('shops').upsert(midPayload).select().single()
            : await _db.from('shops').insert(midPayload).select().single();
        final map = Map<String, dynamic>.from(row as Map);
        final parsed = Shop.fromMap(map);
        return parsed.copyWith(
          operatingHours: shop.operatingHours,
          snsBlogUrl: shop.snsBlogUrl,
          snsInstagramUrl: shop.snsInstagramUrl,
          bio: shop.bio,
          profileImageUrl: shop.profileImageUrl,
          coverImageUrl: shop.coverImageUrl,
          naverReviewWriteUrl: shop.naverReviewWriteUrl,
          serviceMenu: shop.serviceMenu,
          equipmentItems: shop.equipmentItems,
          kakaoPoint: map.containsKey('kakao_point')
              ? parsed.kakaoPoint
              : shop.kakaoPoint,
          isPro: map.containsKey('is_pro') ? parsed.isPro : shop.isPro,
          monthlyCapa: map.containsKey('monthly_capa')
              ? parsed.monthlyCapa
              : shop.monthlyCapa,
        );
      } catch (e2) {
        debugPrint('upsertShop mid failed, retrying base payload: $e2');
      }
      final row = includeId
          ? await _db.from('shops').upsert(basePayload).select().single()
          : await _db.from('shops').insert(basePayload).select().single();
      final map = Map<String, dynamic>.from(row as Map);
      final parsed = Shop.fromMap(map);
      return parsed.copyWith(
        operatingHours: shop.operatingHours,
        businessHours: shop.businessHours,
        snsBlogUrl: shop.snsBlogUrl,
        snsInstagramUrl: shop.snsInstagramUrl,
        bio: shop.bio,
        profileImageUrl: shop.profileImageUrl,
        coverImageUrl: shop.coverImageUrl,
        naverReviewWriteUrl: shop.naverReviewWriteUrl,
        serviceMenu: shop.serviceMenu,
        equipmentItems: shop.equipmentItems,
        kakaoPoint:
            map.containsKey('kakao_point') ? parsed.kakaoPoint : shop.kakaoPoint,
        isPro: map.containsKey('is_pro') ? parsed.isPro : shop.isPro,
        monthlyCapa: map.containsKey('monthly_capa')
            ? parsed.monthlyCapa
            : shop.monthlyCapa,
      );
    }
  }

  @override
  Future<Shop> patchShopFields(
    String shopId,
    Map<String, dynamic> fields,
  ) async {
    final id = shopId.trim();
    if (id.isEmpty || _isTempId(id)) {
      throw StateError('shop id is required');
    }
    final payload = <String, dynamic>{
      ...fields,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final row = await _db
          .from('shops')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return Shop.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      debugPrint('patchShopFields full failed, retrying stripped: $e');
      final slim = Map<String, dynamic>.from(payload);
      slim.remove('cover_image_url');
      slim.remove('equipment_items');
      slim.remove('business_hours');
      final row = await _db
          .from('shops')
          .update(slim)
          .eq('id', id)
          .select()
          .single();
      return Shop.fromMap(Map<String, dynamic>.from(row as Map));
    }
  }

  @override
  Future<SaveChartResult> saveChartAndConfirmVisit(
    SaveChartRequest request,
  ) async {
    final boundCustomerId = request.customerId.trim();
    if (boundCustomerId.isEmpty) {
      throw StateError('customer_id is required for chart save');
    }

    final existingCustomer = await _db
        .from('customers')
        .select()
        .eq('id', boundCustomerId)
        .maybeSingle();
    if (existingCustomer == null) {
      throw StateError('Customer not found: $boundCustomerId');
    }
    var customer =
        Customer.fromMap(Map<String, dynamic>.from(existingCustomer));

    if (request.memberships != null) {
      customer = customer
          .copyWith(memberships: request.memberships)
          .withSyncedMembershipMirrors();
    } else {
      final total =
          (request.membershipTotalVisits ?? customer.membershipTotalVisits)
              .clamp(0, 999);
      var used = (request.membershipUsedVisits ?? customer.membershipUsedVisits)
          .clamp(0, 999);
      if (total > 0 && used > total) used = total;
      customer = customer
          .copyWith(
            membershipServiceName:
                request.membershipServiceName ?? customer.membershipServiceName,
            membershipTotalVisits: total,
            membershipUsedVisits: used,
          )
          .withSyncedMembershipMirrors();
    }

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
    ).withSyncedMembershipMirrors();

    // 차트 upsert (방문 확인 전) — 물리 테이블 우선 기록
    CustomerChart chart;
    final existingChartId = request.chartId;
    var wasChecked = false;
    try {
      if (existingChartId != null && !_isTempId(existingChartId)) {
        final existing = await _selectChartById(existingChartId);
        if (existing != null) {
          wasChecked = (existing['visit_checked'] as bool?) ?? false;
          final base = CustomerChart.fromMap(existing);
          final draft = _chartFromSaveRequest(
            request,
            customer.shopId,
            id: base.id,
            visitChecked: base.visitChecked,
            visitCheckedAt: base.visitCheckedAt,
            feedbackToken: base.feedbackToken,
            feedbackLineOpenedAt: base.feedbackLineOpenedAt,
          );
          chart = draft.copyWith(
            signatureUrl: draft.signatureUrl ?? base.signatureUrl,
            caseShared: base.caseShared,
          );
          final updated = await _updateChartRow(
            chartId: chart.id,
            payload: _chartWriteMap(chart, includeId: false),
            customerId: boundCustomerId,
            shopId: customer.shopId,
          );
          chart = CustomerChart.fromMap(updated);
        } else {
          chart = await _insertChart(request, customer.shopId);
        }
      } else {
        chart = await _insertChart(request, customer.shopId);
      }

      // 방문 확인 → DB trigger가 feedback_token 발급
      if (!chart.visitChecked) {
        final opened = await _updateChartRow(
          chartId: chart.id,
          payload: {
            'visit_checked': true,
            'visit_checked_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          customerId: boundCustomerId,
          shopId: customer.shopId,
        );
        chart = CustomerChart.fromMap(opened);
      }
    } catch (e, st) {
      debugPrint('chart save/visit-check failed — membership untouched: $e\n$st');
      rethrow;
    }

    // 회원권 차감은 차트 저장 성공 후에만. 실패 시 차감분 롤백.
    var membershipDeducted = false;
    var feedbackMessage = '';
    final membershipBeforeDeduct = customer.memberships
        .map((m) => m.copyWith())
        .toList(growable: false);
    final shouldDeduct = request.deductMembership && !wasChecked;

    if (shouldDeduct) {
      final deductResult = _smartDeductMembership(
        customer.memberships,
        request.careName,
      );
      membershipDeducted = deductResult.deducted;
      feedbackMessage = deductResult.message;
      if (membershipDeducted) {
        customer = customer
            .copyWith(memberships: deductResult.memberships)
            .withSyncedMembershipMirrors();
      }
    }

    try {
      customer = await upsertCustomer(customer);
    } catch (e, st) {
      debugPrint('customer upsert after chart failed: $e\n$st');
      if (membershipDeducted) {
        try {
          final restored = customer
              .copyWith(memberships: membershipBeforeDeduct)
              .withSyncedMembershipMirrors();
          customer = await upsertCustomer(restored);
          debugPrint('membership deduct rolled back after customer upsert failure');
        } catch (rollbackError, rst) {
          debugPrint('membership rollback failed: $rollbackError\n$rst');
          customer = customer
              .copyWith(memberships: membershipBeforeDeduct)
              .withSyncedMembershipMirrors();
        }
        membershipDeducted = false;
      }
      feedbackMessage =
          '차트가 저장되었습니다. (고객/회원권 동기화 경고: $e)';
    }

    // 리뷰 초안 — 스키마 드리프트/PGRST204 시에도 차트 저장은 성공 유지
    CustomerReview? review;
    try {
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
    } catch (e, st) {
      debugPrint(
        'customer_reviews draft skipped (chart already saved): $e\n$st',
      );
      review = null;
    }

    return SaveChartResult(
      chart: chart,
      customer: customer,
      review: review,
      membershipDeducted: membershipDeducted,
      feedbackMessage: feedbackMessage,
    );
  }

  ({List<CustomerMembership> memberships, bool deducted, String message})
      _smartDeductMembership(
    List<CustomerMembership> memberships,
    String careName,
  ) {
    if (careName.trim().isEmpty) {
      return (
        memberships: memberships,
        deducted: false,
        message: '진행 서비스가 없어 회원권을 차감하지 않았습니다.',
      );
    }
    for (var i = 0; i < memberships.length; i++) {
      final m = memberships[i];
      if (!CustomerMembership.matchesService(m.serviceName, careName)) {
        continue;
      }
      if (m.remainingVisits <= 0) {
        return (
          memberships: memberships,
          deducted: false,
          message: '${m.serviceName} 회원권 잔여 횟수가 없습니다.',
        );
      }
      final updated = m.copyWith(usedVisits: m.usedVisits + 1);
      final next = List<CustomerMembership>.from(memberships)..[i] = updated;
      return (
        memberships: next,
        deducted: true,
        message:
            '${m.serviceName} 회원권 1회 차감 (잔여 ${updated.remainingVisits}회)',
      );
    }
    return (
      memberships: memberships,
      deducted: false,
      message:
          '진행 서비스($careName)와 일치하는 회원권이 없어 차감하지 않았습니다.',
    );
  }

  Future<CustomerChart> _insertChart(
    SaveChartRequest request,
    String shopId,
  ) async {
    final customerId = request.customerId.trim();
    final sid = shopId.trim();
    if (customerId.isEmpty) {
      throw StateError('customer_id is required for chart insert');
    }
    if (sid.isEmpty) {
      throw StateError('shop_id is required for chart insert');
    }
    final draft = _chartFromSaveRequest(request, sid);
    final payload = _chartWriteMap(draft, includeId: false);
    // 신규 insert 시 서버가 발급할 토큰/확인 필드는 보내지 않음
    payload.remove('feedback_token');
    payload.remove('feedback_line_opened_at');
    payload['visit_checked'] = false;
    payload['visit_checked_at'] = null;
    // SSOT: URL/요청의 customer_id 를 맵에 반드시 재주입
    _ensureChartFkPayload(payload, customerId: customerId, shopId: sid);
    // 동의 저장 매핑 보장
    payload['consent_mandatory'] = draft.consentMandatory;
    if ((draft.signatureUrl ?? '').trim().isNotEmpty) {
      payload['signature_url'] = draft.signatureUrl!.trim();
    }
    final row = await _insertChartRow(
      payload,
      customerId: customerId,
      shopId: sid,
    );
    return CustomerChart.fromMap(row);
  }

  @override
  Future<void> updateChartCaseShared({
    required String chartId,
    required bool shared,
  }) async {
    try {
      await _updateChartRow(
        chartId: chartId,
        payload: {
          'is_case_shared': shared,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      // 구 스키마 폴백
      try {
        await _updateChartRow(
          chartId: chartId,
          payload: {
            'case_shared': shared,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (e2) {
        debugPrint('updateChartCaseShared skipped: $e2');
      }
    }
  }

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
    final id = chartId.trim();
    if (id.isEmpty) throw ArgumentError('chartId required');

    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (careName != null) 'care_name': careName.trim(),
      if (treatmentSummary != null)
        'treatment_summary': treatmentSummary.trim(),
      if (directorInsight != null) 'director_insight': directorInsight.trim(),
      if (beforeImageUrl != null)
        'before_image_url': _imageUrlOrNull(beforeImageUrl),
      if (clearAfterImageUrl)
        'after_image_url': null
      else if (afterImageUrl != null)
        'after_image_url': _imageUrlOrNull(afterImageUrl),
      if (concernChips != null)
        'concern_chips': DbMap.sanitizeStringList(concernChips),
    };

    final row = await _updateChartRow(chartId: id, payload: payload);
    return CustomerChart.fromMap(row);
  }

  @override
  Future<void> updateChartConsentPdfUrl({
    required String chartId,
    required String consentPdfUrl,
  }) async {
    final url = consentPdfUrl.trim();
    if (chartId.isEmpty || url.isEmpty) return;
    try {
      await _updateChartRow(
        chartId: chartId,
        payload: {
          'consent_pdf_url': url,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('updateChartConsentPdfUrl skipped: $e');
    }
  }

  @override
  Future<void> updateHomeCareMissionChecks({
    required String chartId,
    required List<bool> checks,
  }) async {
    final payload = CustomerChart.normalizeMissionChecks(checks);
    try {
      // 좁은 RPC — 원장 차트 필드 오염 방지 + 멱등 패치
      await _db.rpc(
        'patch_home_care_mission_checks',
        params: {
          'p_chart_id': chartId,
          'p_checks': payload,
        },
      );
    } catch (e) {
      // 마이그레이션 미적용 시 컬럼 단위 폴백
      debugPrint('patch_home_care_mission_checks rpc failed, fallback: $e');
      try {
        await _updateChartRow(
          chartId: chartId,
          payload: {
            'home_care_mission_checks': payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (e2) {
        debugPrint('updateHomeCareMissionChecks skipped: $e2');
      }
    }
  }

  @override
  Future<CareDiaryNote> upsertCareDiaryNote(CareDiaryNote note) async {
    final payload = note.toDbWriteMap(includeId: false);
    try {
      final row = await _db
          .from('care_diary_notes')
          .upsert(payload, onConflict: 'customer_id,note_date')
          .select()
          .single();
      return CareDiaryNote.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('upsertCareDiaryNote failed: $e');
      rethrow;
    }
  }

  @override
  Future<CustomerReview> upsertReview(CustomerReview review) async {
    final payload = review.toMap();
    payload.remove('id');
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    // 구스키마에 rating/director_reply 없을 수 있어 단계적 재시도
    try {
      return await _upsertReviewPayload(review.id, payload);
    } catch (e) {
      debugPrint('upsertReview full payload failed, retry slim: $e');
      payload.remove('rating');
      payload.remove('director_reply');
      payload.remove('director_replied_at');
      return _upsertReviewPayload(review.id, payload);
    }
  }

  Future<CustomerReview> _upsertReviewPayload(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (id.isNotEmpty && !_isTempId(id)) {
      final row = await _db
          .from('customer_reviews')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return CustomerReview.fromMap(Map<String, dynamic>.from(row));
    }
    final row =
        await _db.from('customer_reviews').insert(payload).select().single();
    return CustomerReview.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerReview> saveDirectorReviewReply({
    required String reviewId,
    required String shopId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('답글 내용이 비어 있습니다.');
    }
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      await _db.from('review_replies').insert({
        'review_id': reviewId,
        'shop_id': shopId,
        'author_role': 'director',
        'body': trimmed,
        'created_at': now,
      });
    } catch (e, st) {
      debugPrint('review_replies insert skipped: $e\n$st');
    }

    try {
      final row = await _db
          .from('customer_reviews')
          .update({
            'director_reply': trimmed,
            'director_replied_at': now,
            'updated_at': now,
          })
          .eq('id', reviewId)
          .select()
          .single();
      return CustomerReview.fromMap(Map<String, dynamic>.from(row));
    } catch (e, st) {
      debugPrint('director_reply column update failed: $e\n$st');
      // 컬럼 미적용 환경: edited 메타 없이 기존 행 재조회
      final existing = await _db
          .from('customer_reviews')
          .select()
          .eq('id', reviewId)
          .maybeSingle();
      if (existing == null) rethrow;
      final review =
          CustomerReview.fromMap(Map<String, dynamic>.from(existing));
      return review.copyWith(
        directorReply: trimmed,
        directorRepliedAt: DateTime.now(),
      );
    }
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
      final chart = await _selectChartById(chartId);
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

  @override
  Future<AuthRoleResolution> resolveAuthRole(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const AuthRoleResolution.unknown();

    try {
      final owned = await _db
          .from('shops')
          .select()
          .eq('owner_user_id', uid)
          .limit(1);
      final shops = _mapRowsSafely(
        owned as List,
        Shop.fromMap,
        label: 'resolve.shops',
      );
      if (shops.isNotEmpty) {
        return AuthRoleResolution.director(shops.first);
      }
    } catch (e) {
      debugPrint('resolveAuthRole shops failed: $e');
    }

    try {
      final linked = await _db
          .from('customers')
          .select()
          .eq('user_id', uid)
          .limit(1);
      final customers = _mapRowsSafely(
        linked as List,
        Customer.fromMap,
        label: 'resolve.customers',
      );
      if (customers.isNotEmpty) {
        return AuthRoleResolution.customer(customers.first);
      }
    } catch (e) {
      debugPrint('resolveAuthRole customers failed: $e');
    }

    try {
      final profile = await _db
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (profile != null) {
        final role = '${profile['role'] ?? ''}'.toLowerCase();
        if (role == 'director') {
          // 프로필만 director면 소유 샵이 아직 없을 수 있음 → unknown으로 온보딩
          return const AuthRoleResolution.unknown();
        }
        if (role == 'customer') {
          return const AuthRoleResolution.unknown();
        }
      }
    } catch (e) {
      debugPrint('resolveAuthRole profile failed: $e');
    }

    return const AuthRoleResolution.unknown();
  }

  @override
  Future<void> linkShopOwner({
    required String shopId,
    required String userId,
  }) async {
    if (shopId.isEmpty || userId.isEmpty || _isTempId(shopId)) return;
    try {
      await _db.from('shops').update({
        'owner_user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', shopId);
      await _db.from('profiles').update({
        'role': 'director',
        'active_mode': 'director',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('linkShopOwner failed: $e');
    }
  }

  @override
  Future<void> linkCustomerUser({
    required String customerId,
    required String userId,
  }) async {
    if (customerId.isEmpty || userId.isEmpty || _isTempId(customerId)) return;
    try {
      await _db.from('customers').update({
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', customerId);
      await _db.from('profiles').update({
        'role': 'customer',
        'active_mode': 'customer',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('linkCustomerUser failed: $e');
    }
  }

  @override
  Future<void> upsertAuthProfile({
    required String userId,
    String name = '',
    String avatarUrl = '',
    String phone = '',
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    try {
      await _db.rpc(
        'upsert_my_profile',
        params: {
          'p_name': name.trim(),
          'p_avatar_url': avatarUrl.trim(),
          'p_phone': phone.trim(),
        },
      );
      return;
    } catch (e) {
      debugPrint('upsert_my_profile rpc skipped: $e');
    }
    try {
      await _db.from('profiles').upsert({
        'id': uid,
        if (name.trim().isNotEmpty) 'name': name.trim(),
        if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('profiles upsert fallback failed: $e');
    }
  }

  @override
  Future<List<ReviewReply>> loadReviewReplies(String reviewId) async {
    final id = reviewId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('review_replies')
          .select()
          .eq('review_id', id)
          .order('created_at', ascending: true);
      return _mapRowsSafely(
        rows as List,
        ReviewReply.fromMap,
        label: 'review_replies',
      );
    } catch (e) {
      debugPrint('loadReviewReplies failed: $e');
      return const [];
    }
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
    if (shopId.isEmpty || _isTempId(shopId)) {
      return KakaoAlimtalkSendResult.fail(
        errorCode: 'shop_not_found',
        message: '샵 정보가 없습니다.',
      );
    }

    try {
      final raw = await _db.rpc(
        'send_kakao_alimtalk_mock',
        params: {
          'p_shop_id': shopId,
          'p_customer_phone': customerPhone,
          'p_template_code': templateCode,
          'p_content': content,
          'p_cost': cost,
          'p_margin': marginAmount,
        },
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return KakaoAlimtalkSendResult.success(
        logId: DbMap.asText(map['log_id'], 'rpc'),
        remainingPoints: DbMap.asInt(map['kakao_point']),
      );
    } catch (e) {
      debugPrint('send_kakao_alimtalk_mock rpc failed, fallback insert: $e');
      final msg = e.toString();
      if (msg.contains('insufficient_kakao_point') ||
          msg.contains('P0001')) {
        return KakaoAlimtalkSendResult.fail(
          errorCode: 'insufficient_kakao_point',
          message: '알림톡 포인트가 부족합니다. 충전 후 이용해 주세요.',
        );
      }

      // 마이그레이션 미적용 환경: 로컬 MOCK 성공 경로 (포인트는 Store에서 차감)
      try {
        final row = await _db.from('kakao_msg_logs').insert({
          'shop_id': shopId,
          'customer_phone': customerPhone,
          'template_code': templateCode,
          'content': content,
          'status': 'SUCCESS',
          'margin_amount': marginAmount,
        }).select('id').maybeSingle();

        // shops.kakao_point 직접 차감 시도
        try {
          final shopRow = await _db
              .from('shops')
              .select('kakao_point')
              .eq('id', shopId)
              .maybeSingle();
          final current = DbMap.asInt(shopRow?['kakao_point']);
          if (current < cost) {
            return KakaoAlimtalkSendResult.fail(
              errorCode: 'insufficient_kakao_point',
              message: '알림톡 포인트가 부족합니다. 충전 후 이용해 주세요.',
              remainingPoints: current,
            );
          }
          final next = current - cost;
          await _db.from('shops').update({
            'kakao_point': next,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', shopId);
          return KakaoAlimtalkSendResult.success(
            logId: DbMap.asText(row?['id'], 'fallback'),
            remainingPoints: next,
          );
        } catch (e2) {
          debugPrint('kakao_point column update skipped: $e2');
          return KakaoAlimtalkSendResult.success(
            logId: DbMap.asText(row?['id'], 'fallback-local'),
            remainingPoints: -1,
          );
        }
      } catch (e3) {
        debugPrint('kakao_msg_logs insert failed: $e3');
        // 완전 MOCK — DB 없이 성공 처리 (뼈대 UX)
        return KakaoAlimtalkSendResult.success(
          logId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
          remainingPoints: -1,
        );
      }
    }
  }

  @override
  Future<PublicCareReport?> loadPublicCareReport(String chartId) async {
    final id = chartId.trim();
    if (id.isEmpty) return null;
    try {
      final chartRow = await _selectChartById(id);
      if (chartRow == null) return null;
      final chart = CustomerChart.fromMap(chartRow);

      Shop shop = Shop(
        id: chart.shopId,
        name: 'SORI 샵',
        naverPlaceUrl: '',
      );
      try {
        final shopRow = await _db
            .from('shops')
            .select()
            .eq('id', chart.shopId)
            .maybeSingle();
        if (shopRow != null) {
          shop = Shop.fromMap(Map<String, dynamic>.from(shopRow));
        }
      } catch (e) {
        debugPrint('loadPublicCareReport shop skipped: $e');
      }

      String? customerName;
      try {
        final customerRow = await _db
            .from('customers')
            .select('name')
            .eq('id', chart.customerId)
            .maybeSingle();
        customerName = DbMap.asTextOrNull(customerRow?['name']);
      } catch (_) {}

      return PublicCareReport(
        chart: chart,
        shop: shop,
        customerDisplayName: customerName,
      );
    } catch (e, st) {
      debugPrint('loadPublicCareReport failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<List<CommunityCaseItem>> loadCommunityHotCases({int limit = 40}) async {
    try {
      // Prefer PII-safe projection view (migration 029).
      try {
        final rows = await _db
            .from('community_shared_cases')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        final items = <CommunityCaseItem>[];
        for (final raw in rows as List) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final chartId = DbMap.asText(map['chart_id']);
          final shopId = DbMap.asText(map['shop_id']);
          if (chartId.isEmpty || shopId.isEmpty) continue;

          final chart = CustomerChart(
            id: chartId,
            shopId: shopId,
            customerId: '',
            visitNumber: DbMap.asInt(map['visit_number'], 1),
            careName: DbMap.asText(map['care_name']),
            treatmentSummary: '',
            concernChips: () {
              final tags = DbMap.asStringList(map['care_tags']);
              if (tags.isNotEmpty) return tags;
              return DbMap.asStringList(map['concern_chips']);
            }(),
            beforeImageUrl: StorageImageUrl.resolve(
              DbMap.asTextOrNull(map['before_image_url']),
            ),
            afterImageUrl: StorageImageUrl.resolve(
              DbMap.asTextOrNull(map['after_image_url']),
            ),
            caseShared: true,
            createdAt: DbMap.asDateTime(map['created_at']),
            consentMandatory: true,
            signatureUrl: 'signed',
            deviceInfo: DbMap.asTextOrNull(map['device_info']),
            skinSensitivity: DbMap.asText(map['skin_sensitivity']),
            feedAge: _communityAge(map['customer_age']),
            feedGenderLabel:
                DbMap.asTextOrNull(map['customer_gender_label']),
            authorId: DbMap.asTextOrNull(
              map['author_user_id'] ?? map['shop_owner_user_id'],
            ),
          );

          final shop = Shop(
            id: shopId,
            name: DbMap.asText(map['shop_name'], 'SORI 샵'),
            naverPlaceUrl: DbMap.asText(map['shop_naver_place_url']),
            naverBookingUrl: DbMap.asText(map['shop_naver_booking_url']),
            ownerName: DbMap.asTextOrNull(map['shop_owner_name']),
            profileImageUrl: DbMap.asTextOrNull(map['shop_profile_image_url']),
            ownerUserId: DbMap.asTextOrNull(map['shop_owner_user_id']),
            tierBadge: ShopTierBadge.fromDb(
              DbMap.asText(map['shop_tier_badge']),
            ),
            isOfficial: DbMap.asBool(map['shop_is_official']),
            slug: DbMap.asText(map['shop_slug']),
          );

          CustomerReview? review;
          final reviewId = DbMap.asText(map['review_id']);
          final reviewText = DbMap.asText(
            map['customer_review_text'] ??
                map['review_edited_text'] ??
                map['review_original_text'],
          );
          if (reviewId.isNotEmpty && reviewText.trim().isNotEmpty) {
            review = CustomerReview(
              id: reviewId,
              chartId: chartId,
              customerId: '',
              shopId: shopId,
              originalText: DbMap.asText(
                map['review_original_text'] ?? map['customer_review_text'],
              ),
              editedText: DbMap.asTextOrNull(map['review_edited_text']),
              status: ReviewStatusX.fromDb(DbMap.asText(map['review_status'])),
              rating: map['review_rating'] == null
                  ? null
                  : DbMap.asInt(map['review_rating']),
              directorReply: DbMap.asTextOrNull(map['director_reply']),
              directorRepliedAt: DbMap.asDateTime(map['director_replied_at']),
              acceptedAt: DbMap.asDateTime(map['review_accepted_at']),
              createdAt: DbMap.asDateTime(map['review_created_at']),
            );
          }

          final b = chart.beforeImageUrl?.trim() ?? '';
          final a = chart.afterImageUrl?.trim() ?? '';
          if (b.isEmpty && a.isEmpty) continue;
          items.add(
            CommunityCaseItem(
              chart: chart,
              shop: shop,
              review: review,
              careTags: chart.careTags,
              customerAge: chart.feedAge,
              customerGenderLabel: chart.feedGenderLabel,
              authorNickname: DbMap.asText(map['author_nickname']),
              authorAvatarUrl: DbMap.asText(map['author_avatar_url']),
            ),
          );
        }
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('community_shared_cases view skipped: $e');
      }

      List<dynamic> rows = const [];
      try {
        rows = await _db
            .from(_chartsPrimary)
            .select(
              'id, shop_id, customer_id, visit_number, care_name, concern_chips, '
              'before_image_url, after_image_url, is_case_shared, created_at, '
              'signature_url, consent_pdf_url, device_info, skin_sensitivity',
            )
            .eq('is_case_shared', true)
            .order('created_at', ascending: false)
            .limit(limit);
      } catch (_) {
        try {
          rows = await _db
              .from(_chartsFallback)
              .select(
                'id, shop_id, customer_id, visit_number, care_name, concern_chips, '
                'before_image_url, after_image_url, is_case_shared, created_at, '
                'signature_url, consent_pdf_url, device_info, skin_sensitivity',
              )
              .eq('is_case_shared', true)
              .order('created_at', ascending: false)
              .limit(limit);
        } catch (e) {
          rows = await _db
              .from(_chartsFallback)
              .select(
                'id, shop_id, customer_id, visit_number, care_name, concern_chips, '
                'before_image_url, after_image_url, case_shared, created_at, '
                'signature_url, consent_pdf_url, device_info, skin_sensitivity',
              )
              .eq('case_shared', true)
              .order('created_at', ascending: false)
              .limit(limit);
        }
      }

      final rawCharts = _mapRowsSafely(
        rows,
        CustomerChart.fromMap,
        label: 'community_charts',
      )
          .where((c) {
            final b = c.beforeImageUrl?.trim() ?? '';
            final a = c.afterImageUrl?.trim() ?? '';
            return c.caseShared &&
                c.isConsentSigned &&
                (b.isNotEmpty || a.isNotEmpty);
          })
          .toList();
      final personas = await _loadCustomerFeedPersona(
        rawCharts.map((c) => c.customerId),
      );
      final charts = rawCharts.map((c) {
        final p = personas[c.customerId];
        return c
            .copyWith(
              feedAge: p?.age,
              feedGenderLabel: p?.gender,
            )
            .asPublicFeedProjection();
      }).toList();

      final shopIds = charts.map((c) => c.shopId).toSet().toList();
      final shopById = <String, Shop>{};
      if (shopIds.isNotEmpty) {
        try {
          final shopRows = await _db.from('shops').select(
                'id, name, owner_name, profile_image_url, naver_place_url, '
                'naver_booking_url, tier_badge, sori_cash_balance, owner_user_id',
              ).inFilter('id', shopIds);
          for (final s in _mapRowsSafely(
            shopRows as List,
            Shop.fromMap,
            label: 'community_shops',
          )) {
            shopById[s.id] = s;
          }
        } catch (e) {
          debugPrint('community shops load skipped: $e');
        }
      }

      final chartIds = charts.map((c) => c.id).toList();
      final reviewByChart = <String, CustomerReview>{};
      if (chartIds.isNotEmpty) {
        try {
          final reviewRows = await _db
              .from('customer_reviews')
              .select(
                'id, chart_id, shop_id, original_text, edited_text, status, '
                'rating, director_reply, director_replied_at, accepted_at, created_at',
              )
              .inFilter('chart_id', chartIds);
          for (final r in _mapRowsSafely(
            reviewRows as List,
            CustomerReview.fromMap,
            label: 'community_reviews',
          )) {
            if (!r.isInboxVisible) continue;
            final publicReview = r.copyWith(customerId: '');
            final prev = reviewByChart[r.chartId];
            if (prev == null ||
                (r.acceptedAt ?? r.createdAt ?? DateTime(2000)).isAfter(
                  prev.acceptedAt ?? prev.createdAt ?? DateTime(2000),
                )) {
              reviewByChart[r.chartId] = publicReview;
            }
          }
        } catch (e) {
          debugPrint('community reviews load skipped: $e');
        }
      }

      return charts
          .map(
            (c) {
              final shop = shopById[c.shopId] ??
                  Shop(
                    id: c.shopId,
                    name: 'SORI 샵',
                    naverPlaceUrl: '',
                  );
              return CommunityCaseItem(
                chart: c.copyWith(authorId: c.authorId ?? shop.ownerUserId),
                shop: shop,
                review: reviewByChart[c.id],
                careTags: c.careTags,
                customerAge: c.feedAge,
                customerGenderLabel: c.feedGenderLabel,
              );
            },
          )
          .toList();
    } catch (e, st) {
      debugPrint('loadCommunityHotCases failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<ShopHighlight>> loadShopHighlights(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('shop_highlights')
          .select()
          .eq('shop_id', id)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => ShopHighlight.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('loadShopHighlights failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<int> countShopFollowers(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return 0;
    try {
      final rows = await _db
          .from('shop_followers')
          .select('id')
          .eq('shop_id', id);
      return (rows as List).length;
    } catch (e, st) {
      debugPrint('countShopFollowers failed: $e\n$st');
      return 0;
    }
  }

  @override
  Future<bool> isShopFollowed({
    required String shopId,
    required String customerId,
  }) async {
    final sid = shopId.trim();
    final cid = customerId.trim();
    if (sid.isEmpty || cid.isEmpty) return false;
    try {
      final rows = await _db
          .from('shop_followers')
          .select('id')
          .eq('shop_id', sid)
          .eq('customer_id', cid)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e, st) {
      debugPrint('isShopFollowed failed: $e\n$st');
      return false;
    }
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
    try {
      if (following) {
        await _db.from('shop_followers').upsert(
          {
            'shop_id': sid,
            'customer_id': cid,
          },
          onConflict: 'shop_id,customer_id',
        );
      } else {
        await _db
            .from('shop_followers')
            .delete()
            .eq('shop_id', sid)
            .eq('customer_id', cid);
      }
    } catch (e, st) {
      debugPrint('setShopFollow failed: $e\n$st');
      rethrow;
    }
  }

  List<CommunityPost> _parseCommunityPostList(dynamic raw) {
    final list = <CommunityPost>[];
    final rows = raw is List
        ? raw
        : (raw is Map && raw['data'] is List)
            ? raw['data'] as List
            : const [];
    for (final e in rows) {
      if (e is! Map) continue;
      list.add(CommunityPost.fromMap(Map<String, dynamic>.from(e)));
    }
    return list;
  }

  @override
  Future<List<Subscription>> loadMySubscriptions({int limit = 200}) async {
    try {
      final raw = await _db.rpc(
        'list_my_subscriptions',
        params: {'p_limit': limit},
      );
      final rows = raw is List ? raw : const [];
      return [
        for (final e in rows)
          if (e is Map)
            Subscription.fromMap(Map<String, dynamic>.from(e)),
      ];
    } catch (e, st) {
      debugPrint('loadMySubscriptions failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> setSubscription({
    required SubscriptionTargetType targetType,
    String? targetShopId,
    String? targetUserId,
    required bool following,
    String source = 'discover',
  }) async {
    try {
      await _db.rpc(
        'set_subscription',
        params: {
          'p_target_type':
              targetType == SubscriptionTargetType.director ? 'director' : 'shop',
          'p_target_shop_id': targetShopId,
          'p_target_user_id': targetUserId,
          'p_following': following,
          'p_source': source,
        },
      );
    } catch (e, st) {
      debugPrint('setSubscription failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<CommunityPost>> loadFollowingFeed({int limit = 40}) async {
    try {
      final raw = await _db.rpc(
        'list_following_feed',
        params: {'p_limit': limit},
      );
      final list = _parseCommunityPostList(raw);
      final shopIds = list
          .map((p) => p.shopId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final verified = await loadShopBusinessVerified(shopIds);
      return [
        for (final p in list)
          p.copyWith(businessVerified: verified[p.shopId] == true),
      ];
    } catch (e, st) {
      debugPrint('loadFollowingFeed failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<DiscoverDirector>> loadDiscoverDirectors({
    int limit = 40,
    String query = '',
  }) async {
    try {
      final raw = await _db.rpc(
        'list_discover_directors',
        params: {
          'p_limit': limit,
          'p_query': query,
        },
      );
      final rows = raw is List ? raw : const [];
      return [
        for (final e in rows)
          if (e is Map)
            DiscoverDirector.fromMap(Map<String, dynamic>.from(e)),
      ];
    } catch (e, st) {
      debugPrint('loadDiscoverDirectors failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<CaseTimelineEntry>> loadCaseTimelineGroup(String chartId) async {
    final id = chartId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db.rpc(
        'get_case_timeline_group',
        params: {'p_chart_id': id},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((e) => CaseTimelineEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('loadCaseTimelineGroup failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<int> insertSeminarRequest({
    required String caseId,
    String? requestorShopId,
    String? requestorUserId,
  }) async {
    final cid = caseId.trim();
    final sid = requestorShopId?.trim() ?? '';
    final uid = requestorUserId?.trim() ?? '';
    if (cid.isEmpty) {
      throw ArgumentError('caseId required');
    }
    if (sid.isEmpty && uid.isEmpty) {
      throw ArgumentError('requestorShopId or requestorUserId required');
    }

    try {
      final raw = await _db.rpc(
        'request_seminar_interest',
        params: {
          'p_case_id': cid,
          'p_requestor_shop_id': sid.isEmpty ? null : sid,
          'p_requestor_user_id': uid.isEmpty ? null : uid,
        },
      );
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse('$raw') ?? 0;
    } catch (e, st) {
      debugPrint(
        'request_seminar_interest RPC failed, fallback upsert: $e\n$st',
      );
      final row = <String, dynamic>{
        'case_id': cid,
        if (sid.isNotEmpty) 'requestor_shop_id': sid,
        if (uid.isNotEmpty) 'requestor_user_id': uid,
      };
      if (sid.isNotEmpty) {
        await _db.from('seminar_requests').upsert(
              row,
              onConflict: 'case_id,requestor_shop_id',
            );
      } else {
        await _db.from('seminar_requests').insert(row);
      }
      return 0;
    }
  }

  @override
  Future<SeminarEducationInsight> loadSeminarEducationInsight(
    String directorShopId,
  ) async {
    final sid = directorShopId.trim();
    if (sid.isEmpty) {
      return const SeminarEducationInsight(
        totalRequests: 0,
        requestsByCase: {},
      );
    }
    try {
      final chartRows = await _db
          .from('customer_charts')
          .select('id')
          .eq('shop_id', sid);
      final chartIds = (chartRows as List)
          .map((e) => DbMap.asText((e as Map)['id']))
          .where((e) => e.isNotEmpty)
          .toList();

      final byCase = <String, int>{};
      if (chartIds.isNotEmpty) {
        final reqRows = await _db
            .from('seminar_requests')
            .select('case_id')
            .inFilter('case_id', chartIds);
        for (final raw in reqRows as List) {
          final caseId = DbMap.asText((raw as Map)['case_id']);
          if (caseId.isEmpty) continue;
          byCase[caseId] = (byCase[caseId] ?? 0) + 1;
        }
      }

      int cash = 0;
      String tier = '';
      int seminarCount = 0;
      int fundingAmount = 0;
      int likes = 0;
      int shared = 0;
      int requests = 0;
      int completed = 0;
      int followers = 0;
      try {
        final shopRow = await _db
            .from('shops')
            .select(
              'sori_cash_balance, tier_badge, total_seminar_count, '
              'total_funding_amount, total_likes, shared_case_count, '
              'seminar_request_count, completed_seminar_count, follower_count',
            )
            .eq('id', sid)
            .maybeSingle();
        if (shopRow != null) {
          final map = Map<String, dynamic>.from(shopRow as Map);
          cash = DbMap.asInt(map['sori_cash_balance']);
          tier = DbMap.asText(map['tier_badge']);
          seminarCount = DbMap.asInt(map['total_seminar_count']);
          fundingAmount = DbMap.asInt(map['total_funding_amount']);
          likes = DbMap.asInt(map['total_likes']);
          shared = DbMap.asInt(map['shared_case_count']);
          requests = DbMap.asInt(map['seminar_request_count']);
          completed = DbMap.asInt(map['completed_seminar_count']);
          followers = DbMap.asInt(map['follower_count']);
        }
      } catch (_) {}

      return SeminarEducationInsight(
        totalRequests: byCase.values.fold(0, (a, b) => a + b),
        requestsByCase: byCase,
        soriCashBalance: cash,
        tierBadgeLabel: tier,
        totalSeminarCount: seminarCount,
        totalFundingAmount: fundingAmount,
        totalLikes: likes,
        sharedCaseCount: shared,
        seminarRequestCount: requests,
        completedSeminarCount: completed,
        followerCount: followers,
      );
    } catch (e, st) {
      debugPrint('loadSeminarEducationInsight failed: $e\n$st');
      return const SeminarEducationInsight(
        totalRequests: 0,
        requestsByCase: {},
      );
    }
  }

  @override
  Future<SeminarClass> createSeminarClass(SeminarClass draft) async {
    final row = await _db
        .from('seminar_classes')
        .insert(draft.toInsertMap())
        .select()
        .single();
    return SeminarClass.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<SeminarApplication> submitSeminarApplication(
    SeminarApplication draft,
  ) async {
    final row = await _db
        .from('seminar_applications')
        .insert(draft.toInsertMap())
        .select()
        .single();
    return SeminarApplication.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<SeminarClassDetail?> loadSeminarClassDetail(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) return null;

    try {
      final row = await _db
          .from('seminar_classes')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;

      final cls = SeminarClass.fromMap(Map<String, dynamic>.from(row as Map));

      final shopRow = await _db
          .from('shops')
          .select()
          .eq('id', cls.directorShopId)
          .maybeSingle();
      if (shopRow == null) return null;
      final shop = Shop.fromMap(Map<String, dynamic>.from(shopRow as Map));

      CustomerChart? chart;
      final caseId = cls.targetCaseId?.trim();
      if (caseId != null && caseId.isNotEmpty) {
        try {
          final chartRow = await _db
              .from('customer_charts')
              .select()
              .eq('id', caseId)
              .maybeSingle();
          if (chartRow != null) {
            chart = CustomerChart.fromMap(
              Map<String, dynamic>.from(chartRow as Map),
            );
          }
        } catch (e, st) {
          debugPrint('loadSeminarClassDetail chart failed: $e\n$st');
        }
      }

      return SeminarClassDetail(
        seminarClass: cls,
        directorShop: shop,
        targetChart: chart,
      );
    } catch (e, st) {
      debugPrint('loadSeminarClassDetail failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<String> enrollSeminarClass({
    required String classId,
    required String enrollorShopId,
  }) async {
    final result = await _db.rpc(
      'enroll_seminar_class',
      params: {
        'p_class_id': classId.trim(),
        'p_enrollor_shop_id': enrollorShopId.trim(),
      },
    );
    return DbMap.asText(result);
  }

  @override
  Future<int> settleSeminarEnrollment(String enrollmentId) async {
    final result = await _db.rpc(
      'settle_seminar_enrollment',
      params: {'p_enrollment_id': enrollmentId.trim()},
    );
    if (result is Map) {
      return DbMap.asInt(result['net_amount']);
    }
    return 0;
  }

  @override
  Future<List<SeminarEnrollment>> loadMySeminarEnrollments(
    String enrollorShopId,
  ) async {
    final sid = enrollorShopId.trim();
    if (sid.isEmpty) return const [];

    try {
      final rows = await _db
          .from('seminar_enrollments')
          .select(
            'id, class_id, enrollor_shop_id, amount, status, created_at, '
            'seminar_classes(id, title, event_date)',
          )
          .eq('enrollor_shop_id', sid)
          .eq('status', 'held')
          .order('created_at', ascending: false);

      return (rows as List)
          .map(
            (e) => SeminarEnrollment.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('loadMySeminarEnrollments failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> submitSeminarEnrollmentReview({
    required String enrollmentId,
    required List<String> insightTags,
    String comment = '',
  }) async {
    final tags = insightTags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (tags.isEmpty) {
      throw ArgumentError('at least one insight tag required');
    }

    await _db.rpc(
      'submit_seminar_enrollment_review',
      params: {
        'p_enrollment_id': enrollmentId.trim(),
        'p_insight_tags': tags,
        'p_comment': comment.trim(),
      },
    );
  }

  @override
  Future<void> refreshSeminarFeedbackReport(String classId) async {
    final cid = classId.trim();
    if (cid.isEmpty) return;
    try {
      await _db.rpc(
        'refresh_seminar_feedback_report',
        params: {'p_class_id': cid},
      );
    } catch (e, st) {
      debugPrint('refreshSeminarFeedbackReport failed: $e\n$st');
    }
  }

  @override
  Future<List<SeminarFeedbackReport>> loadSeminarFeedbackReports(
    String shopId,
  ) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];

    try {
      final rows = await _db
          .from('seminar_feedback_reports')
          .select(
            'id, class_id, shop_id, top_insight_tags, ai_summary_strength, '
            'ai_summary_improvement, raw_feedback_count, created_at, updated_at, '
            'seminar_classes(title, event_date)',
          )
          .eq('shop_id', sid)
          .order('updated_at', ascending: false);

      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final cls = map['seminar_classes'];
        final classMap = cls is Map ? Map<String, dynamic>.from(cls) : <String, dynamic>{};
        classMap['completed_enrollment_count'] = map['raw_feedback_count'];
        map['seminar_classes'] = classMap;
        return SeminarFeedbackReport.fromMap(map);
      }).toList(growable: false);
    } catch (e, st) {
      debugPrint('loadSeminarFeedbackReports failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<SeminarFeedbackReport?> loadSeminarFeedbackReportDetail(
    String reportId,
  ) async {
    final id = reportId.trim();
    if (id.isEmpty) return null;

    try {
      final row = await _db
          .from('seminar_feedback_reports')
          .select(
            'id, class_id, shop_id, top_insight_tags, ai_summary_strength, '
            'ai_summary_improvement, raw_feedback_count, created_at, updated_at, '
            'seminar_classes(title, event_date)',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;

      final map = Map<String, dynamic>.from(row as Map);
      final classId = DbMap.asText(map['class_id']);

      final enrollRows = await _db
          .from('seminar_enrollments')
          .select('id')
          .eq('class_id', classId);
      final enrollIds = (enrollRows as List)
          .map((e) => DbMap.asText((e as Map)['id']))
          .where((e) => e.isNotEmpty)
          .toList();

      final comments = <String>[];
      if (enrollIds.isNotEmpty) {
        final commentRows = await _db
            .from('seminar_enrollment_reviews')
            .select('comment')
            .inFilter('enrollment_id', enrollIds);
        for (final raw in commentRows as List) {
          final c = DbMap.asText((raw as Map)['comment']).trim();
          if (c.isNotEmpty) comments.add(c);
        }
      }
      map['positive_comments'] = comments;
      map['completed_enrollment_count'] = map['raw_feedback_count'];

      return SeminarFeedbackReport.fromMap(map);
    } catch (e, st) {
      debugPrint('loadSeminarFeedbackReportDetail failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<List<ShopGallerySlide>> loadShopGalleryItems(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('shop_gallery_items')
          .select()
          .eq('shop_id', id)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => ShopGallerySlide.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('loadShopGalleryItems failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<ShopGallerySlide> insertShopGalleryItem({
    required String shopId,
    required String imageUrl,
    String title = '',
  }) async {
    final countRows = await _db
        .from('shop_gallery_items')
        .select('id')
        .eq('shop_id', shopId);
    final sortOrder = (countRows as List).length;
    final row = await _db
        .from('shop_gallery_items')
        .insert({
          'shop_id': shopId,
          'image_url': imageUrl,
          'title': title.trim().isEmpty ? '갤러리' : title.trim(),
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ShopGallerySlide.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> deleteShopGalleryItem(String itemId) async {
    final id = itemId.trim();
    if (id.isEmpty) return;
    await _db.from('shop_gallery_items').delete().eq('id', id);
  }

  @override
  Future<List<ShopPost>> loadShopPosts(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('shop_posts')
          .select()
          .eq('shop_id', id)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((e) => ShopPost.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('loadShopPosts failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<ShopPost> insertShopPost({
    required String shopId,
    required String body,
    String? authorUserId,
    List<String> imageUrls = const [],
    String postKind = 'note',
    String? seminarClassId,
  }) async {
    final payload = <String, dynamic>{
      'shop_id': shopId,
      'body': body.trim(),
      'image_urls': imageUrls,
      'post_kind': postKind.trim().isEmpty ? 'note' : postKind.trim(),
    };
    final author = authorUserId?.trim() ?? '';
    if (author.isNotEmpty) payload['author_user_id'] = author;
    final sid = seminarClassId?.trim() ?? '';
    if (sid.isNotEmpty) payload['seminar_class_id'] = sid;

    Future<ShopPost> insert(Map<String, dynamic> body) async {
      final row =
          await _db.from('shop_posts').insert(body).select().single();
      return ShopPost.fromMap(Map<String, dynamic>.from(row));
    }

    try {
      return await insert(payload);
    } catch (e) {
      debugPrint('insertShopPost full failed, retrying slim: $e');
      final slim = Map<String, dynamic>.from(payload);
      slim.remove('seminar_class_id');
      slim.remove('post_kind');
      slim.remove('author_user_id');
      try {
        return await insert(slim);
      } catch (e2) {
        debugPrint('insertShopPost slim failed: $e2');
        slim.remove('image_urls');
        return insert(slim);
      }
    }
  }

  @override
  Future<void> deleteShopPost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return;
    await _db.from('shop_posts').delete().eq('id', id);
  }

  @override
  Future<List<CommunityPost>> loadCommunityPosts({
    CommunityPostType? type,
    int limit = 40,
  }) async {
    // Prefer server-masked feed (052) so gold_plus body cannot be client-fetched.
    try {
      final raw = await _db.rpc(
        'list_community_posts_safe',
        params: {
          'p_post_type': type?.dbValue,
          'p_limit': limit,
        },
      );
      final list = <CommunityPost>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          list.add(CommunityPost.fromMap(Map<String, dynamic>.from(e)));
        }
      }
      final shopIds = list
          .map((p) => p.shopId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final verified = await loadShopBusinessVerified(shopIds);
      return [
        for (final p in list)
          p.copyWith(businessVerified: verified[p.shopId] == true),
      ];
    } catch (e, st) {
      debugPrint('list_community_posts_safe failed: $e\n$st');
    }

    const select =
        '*, post_media(*, post_tags(*)), market_listings(*), '
        'device_reviews(*), shops(id, name, owner_name, tier_badge, profile_image_url)';
    try {
      final rows = type == null
          ? await _db
              .from('community_posts')
              .select(select)
              .eq('status', 'published')
              .order('created_at', ascending: false)
              .limit(limit)
          : await _db
              .from('community_posts')
              .select(select)
              .eq('status', 'published')
              .eq('post_type', type.dbValue)
              .order('created_at', ascending: false)
              .limit(limit);

      final posts = (rows as List)
          .map(
            (e) => CommunityPost.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final shopIds = posts
          .map((p) => p.shopId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final verified = await loadShopBusinessVerified(shopIds);
      return [
        for (final p in posts)
          p.copyWith(businessVerified: verified[p.shopId] == true),
      ];
    } catch (e, st) {
      debugPrint('loadCommunityPosts failed: $e\n$st');
      try {
        final rows = type == null
            ? await _db
                .from('community_posts')
                .select('*, post_media(*), market_listings(*)')
                .eq('status', 'published')
                .order('created_at', ascending: false)
                .limit(limit)
            : await _db
                .from('community_posts')
                .select('*, post_media(*), market_listings(*)')
                .eq('status', 'published')
                .eq('post_type', type.dbValue)
                .order('created_at', ascending: false)
                .limit(limit);
        return (rows as List)
            .map(
              (e) =>
                  CommunityPost.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (e2, st2) {
        debugPrint('loadCommunityPosts fallback failed: $e2\n$st2');
        return const [];
      }
    }
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
    final payload = <String, dynamic>{
      'shop_id': shopId,
      'post_type': postType.dbValue,
      'title': title.trim(),
      'body': body.trim(),
      'style_tags': styleTags,
      'status': 'published',
      'visibility': visibility.dbValue,
    };
    final chartSrc = sourceChartId?.trim() ?? '';
    if (chartSrc.isNotEmpty) payload['source_chart_id'] = chartSrc;
    final author = authorUserId?.trim() ?? '';
    if (author.isNotEmpty) payload['author_user_id'] = author;

    final row =
        await _db.from('community_posts').insert(payload).select().single();
    final post = CommunityPost.fromMap(Map<String, dynamic>.from(row as Map));

    final media = <CommunityPostMedia>[];
    for (var i = 0; i < imageUrls.length; i++) {
      final url = imageUrls[i].trim();
      if (url.isEmpty) continue;
      final mRow = await _db
          .from('post_media')
          .insert({
            'post_id': post.id,
            'image_url': url,
            'sort_order': i,
          })
          .select()
          .single();
      media.add(
        CommunityPostMedia.fromMap(Map<String, dynamic>.from(mRow as Map)),
      );
    }

    final tags = <CommunityPostTag>[];
    for (final draft in tagDrafts) {
      if (draft.mediaIndex < 0 || draft.mediaIndex >= media.length) continue;
      final label = draft.label.trim();
      if (label.isEmpty) continue;
      final tag = CommunityPostTag(
        id: '',
        mediaId: media[draft.mediaIndex].id,
        label: label,
        tagKind: draft.tagKind,
        normX: draft.normX,
        normY: draft.normY,
        vendorName: draft.vendorName,
        externalUrl: draft.externalUrl.trim().isEmpty
            ? null
            : draft.externalUrl.trim(),
      );
      final tRow = await _db
          .from('post_tags')
          .insert(tag.toInsertMap())
          .select()
          .single();
      tags.add(
        CommunityPostTag.fromMap(Map<String, dynamic>.from(tRow as Map)),
      );
    }

    DeviceReview? review;
    if (deviceReview != null && deviceReview.deviceName.trim().isNotEmpty) {
      final rRow = await _db
          .from('device_reviews')
          .insert({
            'post_id': post.id,
            ...DeviceReview(
              postId: post.id,
              deviceName: deviceReview.deviceName,
              brand: deviceReview.brand,
              model: deviceReview.model,
              usageMonths: deviceReview.usageMonths,
              rating: deviceReview.rating,
              pros: deviceReview.pros,
              cons: deviceReview.cons,
              wouldRecommend: deviceReview.wouldRecommend,
            ).toInsertMap(),
          })
          .select()
          .single();
      review = DeviceReview.fromMap(Map<String, dynamic>.from(rRow as Map));
    }

    MarketListing? listing;
    if (marketListing != null && marketListing.deviceName.trim().isNotEmpty) {
      final lRow = await _db
          .from('market_listings')
          .insert({
            'post_id': post.id,
            'shop_id': shopId,
            'device_name': marketListing.deviceName.trim(),
            'brand': marketListing.brand.trim(),
            'price': marketListing.price,
            'condition': marketListing.condition,
            'listing_status': marketListing.status.dbValue,
            if (marketListing.contactPhone.trim().isNotEmpty)
              'contact_phone': marketListing.contactPhone.trim(),
            'contact_note': marketListing.contactNote.trim(),
          })
          .select()
          .single();
      listing = MarketListing.fromMap(Map<String, dynamic>.from(lRow as Map));
    }

    return CommunityPost(
      id: post.id,
      shopId: post.shopId,
      authorUserId: post.authorUserId,
      postType: post.postType,
      title: post.title,
      body: post.body,
      styleTags: post.styleTags,
      regionCode: post.regionCode,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      saveCount: post.saveCount,
      media: media,
      tags: tags,
      listing: listing,
      deviceReview: review,
      createdAt: post.createdAt,
      visibility: visibility,
      sourceChartId: chartSrc.isEmpty ? null : chartSrc,
    );
  }

  @override
  Future<void> updateMarketListingStatus({
    required String listingId,
    required MarketListingStatus status,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) return;
    final payload = <String, dynamic>{
      'listing_status': status.dbValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == MarketListingStatus.sold) {
      payload['sold_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _db.from('market_listings').update(payload).eq('id', id);
  }

  @override
  Future<Map<String, bool>> loadShopBusinessVerified(
    List<String> shopIds,
  ) async {
    final ids = shopIds.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _db
          .from('shop_verifications')
          .select('shop_id, status')
          .inFilter('shop_id', ids);
      final out = <String, bool>{};
      for (final e in rows as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final sid = (m['shop_id'] ?? '').toString();
        final st = (m['status'] ?? '').toString();
        if (sid.isEmpty) continue;
        out[sid] = st == 'business_verified';
      }
      return out;
    } catch (e, st) {
      debugPrint('loadShopBusinessVerified failed: $e\n$st');
      return const {};
    }
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return;
    await _db.from('community_posts').delete().eq('id', id);
  }

  @override
  Future<List<CommunityComment>> loadCommunityComments(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('community_comments')
          .select(
            '*, shops:author_shop_id(name, owner_name)',
          )
          .eq('post_id', id)
          .eq('status', 'published')
          .order('created_at', ascending: true)
          .limit(200);
      final flat = <CommunityComment>[];
      for (final e in rows as List) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final shop = m['shops'];
        if (shop is Map) {
          m['author_shop_name'] = shop['name'];
          m['author_name'] = shop['owner_name'] ?? shop['name'];
        }
        flat.add(CommunityComment.fromMap(m));
      }
      return CommunityComment.nest(flat);
    } catch (e, st) {
      debugPrint('loadCommunityComments failed: $e\n$st');
      try {
        final rows = await _db
            .from('community_comments')
            .select()
            .eq('post_id', id)
            .order('created_at', ascending: true)
            .limit(200);
        final flat = (rows as List)
            .map(
              (e) => CommunityComment.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        return CommunityComment.nest(flat);
      } catch (e2, st2) {
        debugPrint('loadCommunityComments fallback failed: $e2\n$st2');
        return const [];
      }
    }
  }

  @override
  Future<CommunityComment> insertCommunityComment({
    required String postId,
    required String content,
    String? authorUserId,
    String? authorShopId,
    String? parentId,
  }) async {
    final text = content.trim();
    if (text.isEmpty) throw StateError('comment content required');
    final payload = <String, dynamic>{
      'post_id': postId.trim(),
      'content': text,
      'status': 'published',
    };
    final uid = authorUserId?.trim() ?? '';
    if (uid.isNotEmpty) payload['author_user_id'] = uid;
    final sid = authorShopId?.trim() ?? '';
    if (sid.isNotEmpty) payload['author_shop_id'] = sid;
    final parent = parentId?.trim() ?? '';
    if (parent.isNotEmpty) payload['parent_id'] = parent;

    final row = await _db
        .from('community_comments')
        .insert(payload)
        .select()
        .single();
    return CommunityComment.fromMap(Map<String, dynamic>.from(row as Map));
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
    final sid = shopId.trim();
    final url = destinationUrl.trim();
    if (sid.isEmpty || url.isEmpty) return;
    try {
      // Upsert link by shop+url
      Map<String, dynamic>? linkRow;
      final existing = await _db
          .from('affiliate_links')
          .select()
          .eq('shop_id', sid)
          .eq('destination_url', url)
          .maybeSingle();
      if (existing != null) {
        linkRow = Map<String, dynamic>.from(existing);
      } else {
        final insert = <String, dynamic>{
          'shop_id': sid,
          'destination_url': url,
          'label': label.trim(),
          'commission_per_click': commissionPerClick,
          'status': 'active',
        };
        final pid = postId?.trim() ?? '';
        if (pid.isNotEmpty) insert['post_id'] = pid;
        final tid = postTagId?.trim() ?? '';
        if (tid.isNotEmpty) insert['post_tag_id'] = tid;
        final partner = partnerId?.trim() ?? '';
        if (partner.isNotEmpty) insert['partner_id'] = partner;
        final created = await _db
            .from('affiliate_links')
            .insert(insert)
            .select()
            .single();
        linkRow = Map<String, dynamic>.from(created as Map);
      }

      final linkId = DbMap.asText(linkRow['id']);
      if (linkId.isEmpty) return;
      final perClick = DbMap.asInt(
        linkRow['commission_per_click'],
        commissionPerClick,
      );

      final clickPayload = <String, dynamic>{
        'link_id': linkId,
        'shop_id': sid,
        'referrer': 'community',
      };
      final byUser = clickedByUserId?.trim() ?? '';
      if (byUser.isNotEmpty) clickPayload['clicked_by_user_id'] = byUser;
      final byShop = clickedByShopId?.trim() ?? '';
      if (byShop.isNotEmpty) clickPayload['clicked_by_shop_id'] = byShop;

      final clickRow = await _db
          .from('affiliate_clicks')
          .insert(clickPayload)
          .select()
          .single();
      final clickId = DbMap.asText(
        Map<String, dynamic>.from(clickRow as Map)['id'],
      );

      await _db.from('affiliate_commissions').insert({
        'shop_id': sid,
        'link_id': linkId,
        if (clickId.isNotEmpty) 'click_id': clickId,
        'amount': perClick,
        'status': 'pending',
        'note': 'auto from click',
      });
    } catch (e, st) {
      debugPrint('trackAffiliateClick failed: $e\n$st');
    }
  }

  @override
  Future<AffiliateEarningsSummary> loadAffiliateEarnings(String shopId) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const AffiliateEarningsSummary();
    try {
      final clicks = await _db
          .from('affiliate_clicks')
          .select('id')
          .eq('shop_id', sid);
      final clickCount = (clicks as List).length;

      final rows = await _db
          .from('affiliate_commissions')
          .select('*, affiliate_links(label, destination_url)')
          .eq('shop_id', sid)
          .order('created_at', ascending: false)
          .limit(40);

      var pending = 0;
      var confirmed = 0;
      var paid = 0;
      final recent = <AffiliateCommission>[];
      for (final e in rows as List) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final link = m['affiliate_links'];
        if (link is Map) {
          m['link_label'] = link['label'];
          m['destination_url'] = link['destination_url'];
        }
        final c = AffiliateCommission.fromMap(m);
        recent.add(c);
        switch (c.status) {
          case 'confirmed':
            confirmed += c.amount;
          case 'paid':
            paid += c.amount;
          default:
            pending += c.amount;
        }
      }

      final conversions = <AffiliateConversion>[];
      try {
        final convRows = await _db
            .from('affiliate_conversions')
            .select()
            .eq('shop_id', sid)
            .order('created_at', ascending: false)
            .limit(40);
        for (final e in convRows as List) {
          if (e is! Map) continue;
          conversions.add(
            AffiliateConversion.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      } catch (e, st) {
        debugPrint('load affiliate_conversions failed: $e\n$st');
      }

      return AffiliateEarningsSummary(
        clickCount: clickCount,
        pendingAmount: pending,
        confirmedAmount: confirmed,
        paidAmount: paid,
        recentCommissions: recent,
        recentConversions: conversions,
      );
    } catch (e, st) {
      debugPrint('loadAffiliateEarnings failed: $e\n$st');
      return const AffiliateEarningsSummary();
    }
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
    final cid = chartId.trim();
    final sid = shopId.trim();
    if (cid.isEmpty || sid.isEmpty) return null;
    try {
      final raw = await _db.rpc(
        'save_chart_and_publish_case',
        params: {
          'p_chart_id': cid,
          'p_shop_id': sid,
          'p_publish': publish,
          'p_title': title,
          'p_body': body,
          'p_image_urls': imageUrls,
          'p_author_user_id': authorUserId,
        },
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final postId = DbMap.asText(map['post_id']);
      if (postId.isEmpty) return null;
      final rows = await _db
          .from('community_posts')
          .select(
            '*, post_media(*), shops(id, name, owner_name, tier_badge, profile_image_url)',
          )
          .eq('id', postId)
          .maybeSingle();
      if (rows == null) {
        return CommunityPost(
          id: postId,
          shopId: sid,
          postType: CommunityPostType.caseShare,
          title: title ?? '',
          body: body ?? '',
          sourceChartId: cid,
          authorUserId: authorUserId,
        );
      }
      return CommunityPost.fromMap(Map<String, dynamic>.from(rows));
    } catch (e, st) {
      debugPrint('saveChartAndPublishCase failed: $e\n$st');
      rethrow;
    }
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
    final sid = shopId.trim();
    if (sid.isEmpty) return null;
    try {
      final raw = await _db.rpc(
        'record_affiliate_conversion',
        params: {
          'p_shop_id': sid,
          'p_commission_amount': commissionAmount,
          'p_order_ref': orderRef,
          'p_gross_amount': grossAmount,
          'p_link_id': linkId,
          'p_click_id': clickId,
          'p_post_id': postId,
          'p_note': note,
        },
      );
      if (raw is! Map) return null;
      return AffiliateConversion.fromMap(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      debugPrint('recordAffiliateConversion failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<AffiliateConversion?> settleAffiliateConversion({
    required String conversionId,
    required String toStatus,
    String? actorUserId,
  }) async {
    final id = conversionId.trim();
    if (id.isEmpty) return null;
    try {
      final raw = await _db.rpc(
        'settle_affiliate_conversion',
        params: {
          'p_conversion_id': id,
          'p_to_status': toStatus,
          'p_actor_user_id': actorUserId,
        },
      );
      if (raw is! Map) return null;
      return AffiliateConversion.fromMap(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      debugPrint('settleAffiliateConversion failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<SoriPointWallet> loadPointWallet(String shopId) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return SoriPointWallet.empty;
    try {
      final raw = await _db.rpc('get_shop_wallet', params: {'p_shop_id': sid});
      if (raw is Map) {
        return SoriPointWallet.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e, st) {
      debugPrint('loadPointWallet failed: $e\n$st');
    }
    return SoriPointWallet(id: '', shopId: sid);
  }

  @override
  Future<List<PointTransaction>> loadPointTransactions(
    String shopId, {
    int limit = 30,
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    try {
      final rows = await _db
          .from('point_transactions')
          .select()
          .eq('shop_id', sid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map>()
          .map((e) => PointTransaction.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('loadPointTransactions failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<SettlementTransaction>> loadSettlementTransactions(
    String shopId, {
    int limit = 30,
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    try {
      final rows = await _db
          .from('settlement_transactions')
          .select()
          .eq('shop_id', sid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map>()
          .map(
            (e) => SettlementTransaction.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e, st) {
      debugPrint('loadSettlementTransactions failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<Map<String, dynamic>?> requestSettlementWithdraw({
    required String shopId,
    required int amount,
    String bankAccountMask = '',
    String note = '',
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty || amount <= 0) return null;
    try {
      final raw = await _db.rpc(
        'request_settlement_withdraw',
        params: {
          'p_shop_id': sid,
          'p_amount': amount,
          'p_bank_account_mask': bankAccountMask,
          'p_note': note,
        },
      );
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (e, st) {
      debugPrint('requestSettlementWithdraw failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<SoriPointWallet?> purchaseSoriPoints({
    required String shopId,
    required int amount,
    String sku = 'sori_points_pack',
    String orderRef = '',
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty || amount <= 0) return null;
    try {
      await _db.rpc(
        'purchase_sori_points',
        params: {
          'p_shop_id': sid,
          'p_amount': amount,
          'p_sku': sku,
          'p_order_ref': orderRef,
        },
      );
      return loadPointWallet(sid);
    } catch (e, st) {
      debugPrint('purchaseSoriPoints failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<PostUnlockResult> unlockCommunityPostWithPoints({
    required String postId,
    required String viewerShopId,
    int cost = 5,
  }) async {
    final pid = postId.trim();
    final sid = viewerShopId.trim();
    if (pid.isEmpty || sid.isEmpty) {
      return const PostUnlockResult(ok: false);
    }
    final raw = await _db.rpc(
      'unlock_community_post_with_points',
      params: {
        'p_post_id': pid,
        'p_viewer_shop_id': sid,
        'p_cost': cost,
        'p_creator_share_pct': 70,
      },
    );
    if (raw is! Map) return const PostUnlockResult(ok: false);
    return PostUnlockResult.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<List<PointShopItem>> loadPointShopItems({
    String category = 'booster',
  }) async {
    try {
      final rows = await _db
          .from('point_shop_items')
          .select()
          .eq('is_active', true)
          .eq('category', category)
          .order('sort_order', ascending: true);
      return (rows as List)
          .whereType<Map>()
          .map((e) => PointShopItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('loadPointShopItems failed: $e\n$st');
      return PointShopItem.catalogBoosters
          .where((e) => e.category == category)
          .toList(growable: false);
    }
  }

  @override
  Future<List<BoostPlacement>> loadActiveBoostPlacements({
    int limit = 40,
  }) async {
    try {
      final raw = await _db.rpc(
        'list_active_boost_placements',
        params: {'p_limit': limit},
      );
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => BoostPlacement.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('loadActiveBoostPlacements failed: $e\n$st');
      try {
        final rows = await _db
            .from('boost_placements')
            .select()
            .eq('status', 'active')
            .gt('ends_at', DateTime.now().toUtc().toIso8601String())
            .order('ends_at', ascending: false)
            .limit(limit);
        return (rows as List)
            .whereType<Map>()
            .map((e) => BoostPlacement.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  @override
  Future<BoostPurchaseResult> purchasePointShopItem({
    required String shopId,
    required String sku,
    required String targetType,
    required String targetId,
    String regionCode = '',
  }) async {
    final sid = shopId.trim();
    final sk = sku.trim();
    final tid = targetId.trim();
    if (sid.isEmpty || sk.isEmpty || tid.isEmpty) {
      return const BoostPurchaseResult(ok: false, message: 'invalid args');
    }
    try {
      final raw = await _db.rpc(
        'purchase_point_shop_item',
        params: {
          'p_shop_id': sid,
          'p_sku': sk,
          'p_target_type': targetType,
          'p_target_id': tid,
          'p_region_code': regionCode,
        },
      );
      if (raw is! Map) {
        return const BoostPurchaseResult(ok: false, message: 'empty response');
      }
      return BoostPurchaseResult.fromMap(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      debugPrint('purchasePointShopItem failed: $e\n$st');
      final msg = e.toString();
      final insufficient = msg.contains('insufficient points');
      if (insufficient) {
        final haveMatch = RegExp(r'have (\d+)').firstMatch(msg);
        final needMatch = RegExp(r'need (\d+)').firstMatch(msg);
        return BoostPurchaseResult.insufficientPoints(
          have: int.tryParse(haveMatch?.group(1) ?? '') ?? 0,
          need: int.tryParse(needMatch?.group(1) ?? '') ?? 0,
        );
      }
      rethrow;
    }
  }

  @override
  Future<SoriPointWallet> loadCustomerEchoWallet(String customerId) async {
    final cid = customerId.trim();
    if (cid.isEmpty) return SoriPointWallet.empty;
    try {
      final raw = await _db.rpc(
        'get_customer_wallet',
        params: {'p_customer_id': cid},
      );
      if (raw is Map) {
        return SoriPointWallet.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e, st) {
      debugPrint('loadCustomerEchoWallet failed: $e\n$st');
    }
    return SoriPointWallet(id: '', shopId: '', freeBalance: 0);
  }

  @override
  Future<SoriPointWallet?> purchaseCustomerEcho({
    required String customerId,
    required int amount,
    String sku = 'sori_e_55',
    String orderRef = '',
  }) async {
    final cid = customerId.trim();
    if (cid.isEmpty || amount <= 0) return null;
    try {
      await _db.rpc(
        'purchase_sori_points_customer',
        params: {
          'p_customer_id': cid,
          'p_amount': amount,
          'p_sku': sku,
          'p_order_ref': orderRef,
        },
      );
      return loadCustomerEchoWallet(cid);
    } catch (e, st) {
      debugPrint('purchaseCustomerEcho failed: $e\n$st');
      rethrow;
    }
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
    final cid = customerId.trim();
    final tid = targetId.trim();
    if (cid.isEmpty || tid.isEmpty) {
      return const BoostPurchaseResult(ok: false, message: 'invalid args');
    }
    try {
      final raw = await _db.rpc(
        'purchase_fan_boost',
        params: {
          'p_customer_id': cid,
          'p_sku': sku.trim(),
          'p_target_type': targetType,
          'p_target_id': tid,
          'p_fan_display_name': fanDisplayName,
          'p_region_code': regionCode,
        },
      );
      if (raw is! Map) {
        return const BoostPurchaseResult(ok: false, message: 'empty response');
      }
      return BoostPurchaseResult.fromMap(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      debugPrint('purchaseFanBoost failed: $e\n$st');
      final msg = e.toString();
      if (msg.contains('insufficient points')) {
        final haveMatch = RegExp(r'have (\d+)').firstMatch(msg);
        final needMatch = RegExp(r'need (\d+)').firstMatch(msg);
        return BoostPurchaseResult.insufficientPoints(
          have: int.tryParse(haveMatch?.group(1) ?? '') ?? 0,
          need: int.tryParse(needMatch?.group(1) ?? '') ?? 0,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<FanSupporterEntry>> loadFanBoostSupporters({
    required String targetId,
    String targetType = 'chart',
    int limit = 200,
  }) async {
    final tid = targetId.trim();
    if (tid.isEmpty) return const [];
    try {
      final raw = await _db.rpc(
        'list_fan_boost_supporters',
        params: {
          'p_target_type': targetType,
          'p_target_id': tid,
          'p_limit': limit,
        },
      );
      if (raw is! List) return const [];
      return FanSupporterEntry.ranked(
        raw
            .whereType<Map>()
            .map((e) => FanSupporterEntry.fromMap(Map<String, dynamic>.from(e))),
      );
    } catch (e, st) {
      debugPrint('loadFanBoostSupporters failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<Map<String, List<FanSupporterEntry>>> loadFanBoostSupportersBatch({
    required List<String> targetIds,
    String targetType = 'chart',
    int limitPerTarget = 50,
  }) async {
    final ids = targetIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final raw = await _db.rpc(
        'list_fan_boost_supporters_batch',
        params: {
          'p_target_type': targetType,
          'p_target_ids': ids,
          'p_limit_per_target': limitPerTarget,
        },
      );
      if (raw is! List) return const {};
      final out = <String, List<FanSupporterEntry>>{};
      for (final row in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final tid = DbMap.asText(map['target_id']);
        if (tid.isEmpty) continue;
        out.putIfAbsent(tid, () => []).add(FanSupporterEntry.fromMap(map));
      }
      return {
        for (final e in out.entries) e.key: FanSupporterEntry.ranked(e.value),
      };
    } catch (e, st) {
      debugPrint('loadFanBoostSupportersBatch failed: $e\n$st');
      // Fallback: single RPCs for a small set
      final out = <String, List<FanSupporterEntry>>{};
      for (final id in ids.take(12)) {
        out[id] = await loadFanBoostSupporters(
          targetId: id,
          targetType: targetType,
          limit: limitPerTarget,
        );
      }
      return out;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadBoostCandidatesScored({
    String segment = 'case',
    int limit = 200,
  }) async {
    try {
      final raw = await _db.rpc(
        'list_boost_candidates_scored',
        params: {
          'p_segment': segment,
          'p_limit': limit,
        },
      );
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e, st) {
      debugPrint('loadBoostCandidatesScored failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadInterleavedFeedIds({
    String segment = 'case',
    int limit = 20,
    int offset = 0,
    String viewerSeed = '',
  }) async {
    try {
      final rpc = segment == 'case' ? 'get_home_feed' : 'get_community_feed';
      final params = segment == 'case'
          ? {
              'p_limit': limit,
              'p_offset': offset,
              'p_viewer_seed': viewerSeed,
            }
          : {
              'p_segment': segment,
              'p_limit': limit,
              'p_offset': offset,
              'p_viewer_seed': viewerSeed,
            };
      final raw = await _db.rpc(rpc, params: params);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e, st) {
      debugPrint('loadInterleavedFeedIds failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadShopNotifications(
    String shopId, {
    int limit = 20,
  }) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    try {
      final rows = await _db
          .from('shop_notifications')
          .select()
          .eq('shop_id', sid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e, st) {
      debugPrint('loadShopNotifications failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<SeminarClass>> loadSeminarClassesForShop(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return const [];
    try {
      final rows = await _db
          .from('seminar_classes')
          .select()
          .eq('director_shop_id', id)
          .order('created_at', ascending: false)
          .limit(40);
      return (rows as List)
          .map((e) => SeminarClass.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('loadSeminarClassesForShop failed: $e\n$st');
      return const [];
    }
  }
}
