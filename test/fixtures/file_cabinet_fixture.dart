/// 파일 위계 메모리 fixture (DB/Storage/SoriStore 없음).
///
/// Today = [seoulToday] 과 같은 visitDate 를 가진 VisitChart 의 표시 라벨.
/// Consent 는 VisitChart 와 별 컬렉션이다.
library;

import 'file_cabinet_models.dart';

export 'file_cabinet_models.dart';

/// fixture 시계. 테스트가 날짜에 흔들리지 않게 고정.
final DateTime kFileCabinetSeoulToday = DateTime(2026, 9, 14);

const int kFileCabinetConsentValidDays = 365;

/// 신규 1×1 PNG. 라이브 서명/사진 data URL 이 아니다.
const String kFixturePngBefore =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';
const String kFixturePngAfter =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
const String kFixturePngSignature =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

DateTime _day(int daysBeforeToday) =>
    kFileCabinetSeoulToday.subtract(Duration(days: daysBeforeToday));

bool isSameSeoulDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isConsentValid(FixtureConsent c, {DateTime? today}) {
  final clock = today ?? kFileCabinetSeoulToday;
  final until = c.signedAt.add(const Duration(days: kFileCabinetConsentValidDays));
  return !until.isBefore(clock);
}

String visitDisplayLabel(FixtureVisitChart visit, {DateTime? today}) {
  final clock = today ?? kFileCabinetSeoulToday;
  if (isSameSeoulDay(visit.visitDate, clock)) return 'Today';
  return 'v${visit.visitNumber}';
}

FixtureVisitChart? todayVisit(FixtureCustomer customer, {DateTime? today}) {
  final clock = today ?? kFileCabinetSeoulToday;
  final matches = customer.visits
      .where((v) => isSameSeoulDay(v.visitDate, clock))
      .toList(growable: false);
  if (matches.isEmpty) return null;
  return matches.single;
}

class FileCabinetFixture {
  FileCabinetFixture({
    required this.shop,
    required this.drawers,
    required this.customers,
  });

  final FixtureShop shop;
  final List<FixtureDrawer> drawers;
  final List<FixtureCustomer> customers;

  static FileCabinetFixture load() => _build();

  List<FixtureDrawer> get drawersSortedByRangeStart {
    final copy = [...drawers];
    copy.sort((a, b) => a.rangeStart.compareTo(b.rangeStart));
    return copy;
  }

  FixtureDrawer? drawerForFileNo(int fileNo) {
    for (final d in drawersSortedByRangeStart) {
      if (d.containsFileNo(fileNo)) return d;
    }
    return null;
  }

  FixtureCustomer? customerByFileNo(int fileNo) {
    for (final c in customers) {
      if (c.fileNo == fileNo) return c;
    }
    return null;
  }

  /// 실제 앱 INSERT / Supabase 없이 서랍 가드만 시뮬한다.
  FixtureCreateFailure? simulateCreateCustomer({required int fileNo}) {
    if (drawerForFileNo(fileNo) == null) {
      return FixtureCreateFailure.drawerNotFound;
    }
    return null;
  }

  /// 동의를 추가해도 visit_number 목록은 그대로다.
  FileCabinetFixture withAddedConsent(int fileNo, FixtureConsent consent) {
    final next = customers.map((c) {
      if (c.fileNo != fileNo) return c;
      return c.copyWith(consents: [...c.consents, consent]);
    }).toList(growable: false);
    return FileCabinetFixture(shop: shop, drawers: drawers, customers: next);
  }

  /// 규칙 위반 메시지. 비어 있으면 fixture 가 목표 모델을 지킨다.
  List<String> validate() {
    final issues = <String>[];
    final sorted = drawersSortedByRangeStart;
    for (final d in sorted) {
      if (d.rangeStart > d.rangeEnd) {
        issues.add('drawer ${d.id} range inverted');
      }
    }
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].rangeStart <= sorted[i - 1].rangeEnd) {
        issues.add('drawer ranges overlap');
      }
    }

    final nos = <int>{};
    for (final c in customers) {
      if (!nos.add(c.fileNo)) {
        issues.add('duplicate customer_file_no ${c.fileNo}');
      }
      if (drawerForFileNo(c.fileNo) == null) {
        issues.add('No${c.fileNo} has no drawer');
      }
      final visitNos = c.visits.map((v) => v.visitNumber).toList();
      final expected = [for (var i = 1; i <= visitNos.length; i++) i];
      final sortedNos = [...visitNos]..sort();
      if (sortedNos.join(',') != expected.join(',')) {
        issues.add('No${c.fileNo} visit_number not 1..N contiguous: $visitNos');
      }
      for (var i = 1; i < sortedNos.length; i++) {
        if (sortedNos[i] <= sortedNos[i - 1]) {
          issues.add('No${c.fileNo} visit_number not strictly increasing');
        }
      }
      final days = <String>{};
      for (final v in c.visits) {
        final key =
            '${v.visitDate.year}-${v.visitDate.month}-${v.visitDate.day}';
        if (!days.add(key)) {
          issues.add('No${c.fileNo} duplicate visitDate $key');
        }
        if (c.consents.any((con) => con.id == v.id)) {
          issues.add('consent id collides with visit id ${v.id}');
        }
        if (v.customerId != c.id) {
          issues.add('visit ${v.id} customer mismatch');
        }
      }
      for (final con in c.consents) {
        if (con.customerId != c.id) {
          issues.add('consent ${con.id} customer mismatch');
        }
        if (c.visits.any((v) => v.id == con.id)) {
          issues.add('consent id ${con.id} equals a visit id');
        }
      }
      final todays =
          c.visits.where((v) => isSameSeoulDay(v.visitDate, kFileCabinetSeoulToday));
      if (todays.length > 1) {
        issues.add('No${c.fileNo} has more than one Today visit');
      }
    }
    if (customers.any((c) => c.fileNo == 301)) {
      issues.add('No301 customer must not exist');
    }
    return issues;
  }
}

FileCabinetFixture _build() {
  const shop = FixtureShop(id: 'fx-shop-file-cabinet', name: 'Fixture Shop');
  const drawers = [
    FixtureDrawer(id: 'fx-drawer-a', label: 'A', rangeStart: 1, rangeEnd: 100),
    FixtureDrawer(id: 'fx-drawer-b', label: 'B', rangeStart: 101, rangeEnd: 200),
    FixtureDrawer(id: 'fx-drawer-c', label: 'C', rangeStart: 201, rangeEnd: 300),
  ];

  FixtureConsent consent({
    required String id,
    required String customerId,
    required int daysAgo,
    bool photo = false,
  }) {
    return FixtureConsent(
      id: id,
      customerId: customerId,
      signedAt: _day(daysAgo),
      photoConsent: photo,
      signatureDataUrl: kFixturePngSignature,
      pdfBytesMarker: 'fixture-pdf-$id',
    );
  }

  FixtureVisitChart visit({
    required String id,
    required String customerId,
    required int n,
    required int daysAgo,
    String care = '픽스처 케어',
    String memo = '',
    String? before,
    String? after,
  }) {
    return FixtureVisitChart(
      id: id,
      customerId: customerId,
      visitNumber: n,
      visitDate: _day(daysAgo),
      careName: care,
      memo: memo,
      beforeImageDataUrl: before,
      afterImageDataUrl: after,
    );
  }

  const id1 = 'fx-cust-no1';
  const id25 = 'fx-cust-no25';
  const id98 = 'fx-cust-no98';
  const id100 = 'fx-cust-no100';
  const id101 = 'fx-cust-no101';
  const id147 = 'fx-cust-no147';
  const id199 = 'fx-cust-no199';
  const id200 = 'fx-cust-no200';
  const id201 = 'fx-cust-no201';

  final customers = <FixtureCustomer>[
    FixtureCustomer(
      id: id1,
      fileNo: 1,
      name: '픽스처 신규',
      phone: '010-0001-0001',
      visits: [
        visit(
          id: 'fx-visit-no1-v1',
          customerId: id1,
          n: 1,
          daysAgo: 0,
          memo: '오늘 첫 방문 · 같은 날 메모는 이 chart_id에만',
        ),
      ],
    ),
    FixtureCustomer(
      id: id25,
      fileNo: 25,
      name: '픽스처 이력',
      phone: '010-0001-0025',
      consents: [
        consent(id: 'fx-consent-no25-old', customerId: id25, daysAgo: 400),
        consent(id: 'fx-consent-no25-mid', customerId: id25, daysAgo: 200),
        consent(id: 'fx-consent-no25-now', customerId: id25, daysAgo: 10),
      ],
      visits: [
        visit(id: 'fx-visit-no25-v1', customerId: id25, n: 1, daysAgo: 90),
        visit(id: 'fx-visit-no25-v2', customerId: id25, n: 2, daysAgo: 60),
        visit(id: 'fx-visit-no25-v3', customerId: id25, n: 3, daysAgo: 30),
        visit(
          id: 'fx-visit-no25-v4',
          customerId: id25,
          n: 4,
          daysAgo: 0,
          memo: 'Today v4 · 시술/메모/사진은 이 row',
          before: kFixturePngBefore,
        ),
      ],
    ),
    FixtureCustomer(
      id: id98,
      fileNo: 98,
      name: '픽스처 만료',
      phone: '010-0001-0098',
      consents: [
        consent(id: 'fx-consent-no98', customerId: id98, daysAgo: 400),
      ],
      visits: [
        visit(id: 'fx-visit-no98-v1', customerId: id98, n: 1, daysAgo: 50),
      ],
    ),
    const FixtureCustomer(
      id: id100,
      fileNo: 100,
      name: '픽스처 에이끝',
      phone: '010-0001-0100',
    ),
    FixtureCustomer(
      id: id101,
      fileNo: 101,
      name: '픽스처 비시작',
      phone: '010-0001-0101',
      visits: [
        visit(id: 'fx-visit-no101-v1', customerId: id101, n: 1, daysAgo: 0),
      ],
    ),
    FixtureCustomer(
      id: id147,
      fileNo: 147,
      name: '픽스처 장문',
      phone: '010-0001-0147',
      consents: [
        consent(id: 'fx-consent-no147', customerId: id147, daysAgo: 20),
      ],
      // 최신 v12 = Today. v1..v11 은 7일 간격 과거. 모든 visitDate 상이.
      visits: [
        for (var n = 1; n <= 12; n++)
          visit(
            id: 'fx-visit-no147-v$n',
            customerId: id147,
            n: n,
            daysAgo: (12 - n) * 7,
            before: n == 6 ? kFixturePngBefore : null,
            after: n == 6 ? kFixturePngAfter : null,
          ),
      ],
    ),
    FixtureCustomer(
      id: id199,
      fileNo: 199,
      name: '픽스처 사진',
      phone: '010-0001-0199',
      consents: [
        consent(
          id: 'fx-consent-no199',
          customerId: id199,
          daysAgo: 5,
          photo: true,
        ),
      ],
      // Today 없음. v1 Before만, v2 B/A. 사진은 VisitChart 귀속.
      visits: [
        visit(
          id: 'fx-visit-no199-v1',
          customerId: id199,
          n: 1,
          daysAgo: 21,
          before: kFixturePngBefore,
        ),
        visit(
          id: 'fx-visit-no199-v2',
          customerId: id199,
          n: 2,
          daysAgo: 7,
          before: kFixturePngBefore,
          after: kFixturePngAfter,
        ),
      ],
    ),
    const FixtureCustomer(
      id: id200,
      fileNo: 200,
      name: '픽스처 비끝',
      phone: '010-0001-0200',
    ),
    FixtureCustomer(
      id: id201,
      fileNo: 201,
      name: '픽스처 씨시작',
      phone: '010-0001-0201',
      visits: [
        visit(id: 'fx-visit-no201-v1', customerId: id201, n: 1, daysAgo: 14),
      ],
    ),
  ];

  return FileCabinetFixture(shop: shop, drawers: drawers, customers: customers);
}
