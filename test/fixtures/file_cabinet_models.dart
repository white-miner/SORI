/// 파일 위계 UI fixture 전용 모델.
/// production `lib/` 에 두지 않는다. CustomerChart / SoriStore 와 무관하다.
library;

enum FixtureCreateFailure { drawerNotFound }

class FixtureShop {
  const FixtureShop({required this.id, required this.name});

  final String id;
  final String name;
}

class FixtureDrawer {
  const FixtureDrawer({
    required this.id,
    required this.label,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final String id;
  final String label;
  final int rangeStart;
  final int rangeEnd;

  bool containsFileNo(int fileNo) =>
      fileNo >= rangeStart && fileNo <= rangeEnd;
}

class FixtureConsent {
  const FixtureConsent({
    required this.id,
    required this.customerId,
    required this.signedAt,
    this.photoConsent = false,
    this.signatureDataUrl,
    this.pdfBytesMarker,
  });

  final String id;
  final String customerId;
  final DateTime signedAt;
  final bool photoConsent;

  /// 신규 가짜 서명만. 라이브 data URL / Storage URL 금지.
  final String? signatureDataUrl;

  /// PDF 본문 대신 fixture 식별 문자열. 라이브 PDF URL 금지.
  final String? pdfBytesMarker;
}

class FixtureVisitChart {
  const FixtureVisitChart({
    required this.id,
    required this.customerId,
    required this.visitNumber,
    required this.visitDate,
    this.careName = '',
    this.memo = '',
    this.beforeImageDataUrl,
    this.afterImageDataUrl,
  });

  final String id;
  final String customerId;
  final int visitNumber;

  /// 서울 달력일 (시간 00:00).
  final DateTime visitDate;
  final String careName;
  final String memo;
  final String? beforeImageDataUrl;
  final String? afterImageDataUrl;

  bool get hasBefore => (beforeImageDataUrl ?? '').isNotEmpty;
  bool get hasAfter => (afterImageDataUrl ?? '').isNotEmpty;
}

class FixtureCustomer {
  const FixtureCustomer({
    required this.id,
    required this.fileNo,
    required this.name,
    required this.phone,
    this.consents = const [],
    this.visits = const [],
  });

  final String id;
  final int fileNo;
  final String name;
  final String phone;
  final List<FixtureConsent> consents;
  final List<FixtureVisitChart> visits;

  FixtureCustomer copyWith({
    List<FixtureConsent>? consents,
    List<FixtureVisitChart>? visits,
  }) {
    return FixtureCustomer(
      id: id,
      fileNo: fileNo,
      name: name,
      phone: phone,
      consents: consents ?? this.consents,
      visits: visits ?? this.visits,
    );
  }
}
