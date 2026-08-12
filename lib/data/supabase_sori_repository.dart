import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_reply.dart';
import '../models/care_diary_note.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_membership.dart';
import '../models/customer_review.dart';
import '../models/home_care_prescriptions.dart';
import '../models/membership_ticket.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';
import '../services/supabase_client.dart';
import '../utils/db_map.dart';
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

  /// 차트 저장/조회 테이블 — chart_records(뷰) 우선, 실패 시 customer_charts.
  static const String _chartsPrimary = 'chart_records';
  static const String _chartsFallback = 'customer_charts';

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

  /// PGRST204 방어: 스키마에 없는 컬럼 키를 페이로드에서 제거 후 재시도.
  Map<String, dynamic> _stripUnknownColumn(
    Map<String, dynamic> payload,
    Object error,
  ) {
    final msg = error.toString();
    final match = RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(msg);
    if (match == null) return payload;
    final col = match.group(1);
    if (col == null || col.isEmpty) return payload;
    final next = Map<String, dynamic>.from(payload)..remove(col);
    debugPrint('Removed unknown column from payload: $col');
    return next;
  }

  Map<String, dynamic> _stripUnknownChartColumn(
    Map<String, dynamic> payload,
    Object error,
  ) =>
      _stripUnknownColumn(payload, error);

  Future<Map<String, dynamic>> _insertChartRow(
    Map<String, dynamic> payload,
  ) async {
    var body = Map<String, dynamic>.from(payload);
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      for (final table in [_chartsPrimary, _chartsFallback]) {
        try {
          final row =
              await _db.from(table).insert(body).select().single();
          return Map<String, dynamic>.from(row);
        } catch (e) {
          lastError = e;
          final stripped = _stripUnknownChartColumn(body, e);
          if (stripped.length != body.length) {
            body = stripped;
            break; // retry same attempt with stripped payload
          }
          debugPrint('insert chart via $table failed: $e');
        }
      }
    }
    throw lastError ?? StateError('chart insert failed');
  }

  Future<Map<String, dynamic>> _updateChartRow({
    required String chartId,
    required Map<String, dynamic> payload,
  }) async {
    var body = Map<String, dynamic>.from(payload);
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      for (final table in [_chartsPrimary, _chartsFallback]) {
        try {
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
            break;
          }
          debugPrint('update chart via $table failed: $e');
        }
      }
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
  static String? _imageUrlOrNull(String? value) => DbMap.asTextOrNull(value);

  /// TEXT 컬럼용: null/공백 → '' (스키마 default '' 와 호환, 에러 방지).
  static String _textOrEmpty(String? value) =>
      value == null ? '' : value.trim();

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
      customerId: request.customerId,
      visitNumber: request.visitNumber < 1 ? 1 : request.visitNumber,
      customChartNo: DbMap.asTextOrNull(request.customChartNo),
      visitChecked: visitChecked,
      visitCheckedAt: visitCheckedAt,
      beforeImageUrl: _imageUrlOrNull(request.beforeImageUrl),
      afterImageUrl: _imageUrlOrNull(request.afterImageUrl),
      careName: _textOrEmpty(request.careName),
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
    if (includeId && c.id.isNotEmpty && !_isTempId(c.id)) {
      return c.toDbWriteMap(includeId: true);
    }
    return c.toDbWriteMap(includeId: false);
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
      final chartRows = await _withChartsTable(
        (table) => _db
            .from(table)
            .select()
            .eq('shop_id', shop.id)
            .order('visit_number', ascending: false),
      );
      charts = _mapRowsSafely(
        chartRows as List,
        CustomerChart.fromMap,
        label: 'chart_records',
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

    return SoriSnapshot(
      shop: shop,
      customers: customers,
      charts: charts,
      reviews: reviews,
      aiReplies: aiReplies,
      diaryNotes: diaryNotes,
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
      'sns_blog_url': shop.snsBlogUrl,
      'sns_instagram_url': shop.snsInstagramUrl,
    };

    try {
      final row = includeId
          ? await _db.from('shops').upsert(fullPayload).select().single()
          : await _db.from('shops').insert(fullPayload).select().single();
      return Shop.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('upsertShop with hours/SNS failed, retrying base payload: $e');
      final row = includeId
          ? await _db.from('shops').upsert(basePayload).select().single()
          : await _db.from('shops').insert(basePayload).select().single();
      // 원격에 hours/SNS가 없어도 로컬 값은 유지
      return Shop.fromMap(Map<String, dynamic>.from(row)).copyWith(
        operatingHours: shop.operatingHours,
        snsBlogUrl: shop.snsBlogUrl,
        snsInstagramUrl: shop.snsInstagramUrl,
        serviceMenu: shop.serviceMenu,
      );
    }
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

    // 차트 upsert (방문 확인 전) — chart_records 우선
    CustomerChart chart;
    final existingChartId = request.chartId;
    var wasChecked = false;
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
        // 서명 미갱신 시 기존 signature_url 유지
        chart = draft.copyWith(
          signatureUrl: draft.signatureUrl ?? base.signatureUrl,
          caseShared: base.caseShared,
        );
        final updated = await _updateChartRow(
          chartId: chart.id,
          payload: _chartWriteMap(chart, includeId: false),
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
      );
      chart = CustomerChart.fromMap(opened);
    }

    // 회원권 차감 (방문 첫 확인 시에만, careName 매칭)
    var membershipDeducted = false;
    var feedbackMessage = '';
    if (request.deductMembership && !wasChecked) {
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

    customer = await upsertCustomer(customer);
    // upsertCustomer → sync_membership_tickets_for_customer 로 티켓 지갑 동기화

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
    final draft = _chartFromSaveRequest(request, shopId);
    final payload = _chartWriteMap(draft, includeId: false);
    // 신규 insert 시 서버가 발급할 토큰/확인 필드는 보내지 않음
    payload.remove('feedback_token');
    payload.remove('feedback_line_opened_at');
    payload['visit_checked'] = false;
    payload['visit_checked_at'] = null;
    final row = await _insertChartRow(payload);
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
}
