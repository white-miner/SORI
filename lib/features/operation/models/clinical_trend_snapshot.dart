/// PRD v4.3 — 단일 임상 트렌드 키워드 + CTI.
class ClinicalTrendItem {
  const ClinicalTrendItem({
    required this.id,
    required this.keyword,
    required this.category,
    required this.cti,
    required this.surgePct,
    required this.sparkline7d,
    required this.headline,
    required this.narrative,
    this.naverScore = 0,
    this.qualifies = true,
    this.poPriority = 50,
  });

  final String id;
  final String keyword;
  final String category;
  final int cti;
  final int surgePct;
  final List<int> sparkline7d;
  final String headline;
  final String narrative;
  final int naverScore;
  final bool qualifies;
  final int poPriority;

  factory ClinicalTrendItem.fromMap(Map<String, dynamic> map) {
    final sparkRaw = map['sparkline_7d'];
    final spark = sparkRaw is List
        ? sparkRaw.map((e) => (e as num).round()).toList()
        : <int>[];

    return ClinicalTrendItem(
      id: map['id']?.toString() ?? '',
      keyword: map['keyword']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      cti: (map['cti'] as num?)?.round() ?? 0,
      surgePct: (map['surge_pct'] as num?)?.round() ?? 0,
      sparkline7d: spark,
      headline: map['headline']?.toString() ?? '',
      narrative: map['narrative']?.toString() ?? '',
      naverScore: (map['naver_score'] as num?)?.round() ?? 0,
      qualifies: map['qualifies'] as bool? ?? true,
      poPriority: (map['po_priority'] as num?)?.round() ?? 50,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'keyword': keyword,
        'category': category,
        'cti': cti,
        'surge_pct': surgePct,
        'sparkline_7d': sparkline7d,
        'headline': headline,
        'narrative': narrative,
        'naver_score': naverScore,
        'qualifies': qualifies,
        'po_priority': poPriority,
      };
}

/// PRD v4.3 — Edge 2h snapshot (Top3 + Top1 briefing bind).
class ClinicalTrendSnapshot {
  const ClinicalTrendSnapshot({
    required this.items,
    required this.top3,
    this.top1,
    this.fetchedAt,
    this.source = 'naver',
    this.hasSurge = false,
    this.cached = false,
  });

  final List<ClinicalTrendItem> items;
  final List<ClinicalTrendItem> top3;
  final ClinicalTrendItem? top1;
  final DateTime? fetchedAt;
  final String source;
  final bool hasSurge;
  final bool cached;

  ClinicalTrendItem? get briefingLead => top1 ?? (top3.isNotEmpty ? top3.first : null);

  factory ClinicalTrendSnapshot.fromMap(Map<String, dynamic> map) {
    List<ClinicalTrendItem> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ClinicalTrendItem.fromMap)
          .toList();
    }

    final items = parseList(map['items']);
    var top3 = parseList(map['top3']);
    if (top3.isEmpty && items.isNotEmpty) {
      final sorted = [...items]..sort((a, b) {
          if (b.cti != a.cti) return b.cti.compareTo(a.cti);
          if (b.surgePct != a.surgePct) return b.surgePct.compareTo(a.surgePct);
          return b.poPriority.compareTo(a.poPriority);
        });
      top3 = sorted
          .where((i) => i.surgePct >= 5 || i.cti >= 40)
          .take(3)
          .toList();
    }

    final top1Raw = map['top1'];
    final top1 = top1Raw is Map<String, dynamic>
        ? ClinicalTrendItem.fromMap(top1Raw)
        : (top3.isNotEmpty ? top3.first : null);

    final fetchedRaw = map['fetched_at']?.toString() ?? '';
    return ClinicalTrendSnapshot(
      items: items,
      top3: top3,
      top1: top1,
      fetchedAt: DateTime.tryParse(fetchedRaw)?.toLocal(),
      source: map['source']?.toString() ?? 'naver',
      hasSurge: map['has_surge'] as bool? ?? top3.isNotEmpty,
      cached: map['cached'] as bool? ?? false,
    );
  }

  static ClinicalTrendSnapshot fallback() {
    final items = [
      ClinicalTrendItem.fromMap({
        'id': 'K01',
        'keyword': '홍조',
        'category': 'barrier_sensitive',
        'cti': 71,
        'surge_pct': 42,
        'sparkline_7d': [38, 41, 44, 48, 52, 58, 65],
        'headline': '홍조 검색 급증',
        'narrative':
            "요즘 '홍조' 검색이 42% 올랐어요. 장벽·진정 쪽 먼저 여쭤보시면 고객이 트렌드까지 아는 샵이라고 느낍니다.",
        'naver_score': 68,
        'qualifies': true,
        'po_priority': 100,
      }),
      ClinicalTrendItem.fromMap({
        'id': 'K02',
        'keyword': '피부장벽',
        'category': 'barrier_sensitive',
        'cti': 58,
        'surge_pct': 28,
        'sparkline_7d': [40, 42, 43, 45, 47, 50, 54],
        'headline': '피부장벽 관심↑',
        'narrative':
            "'피부장벽' 고민 검색이 28% 증가했습니다. TEWL·민감 반응을 짚어 주시면 신뢰가 빨리 쌓입니다.",
        'naver_score': 54,
        'qualifies': true,
        'po_priority': 95,
      }),
      ClinicalTrendItem.fromMap({
        'id': 'K03',
        'keyword': '트러블',
        'category': 'trouble_sebum',
        'cti': 52,
        'surge_pct': 19,
        'sparkline_7d': [35, 36, 38, 39, 41, 43, 45],
        'headline': '트러블 수요 활발',
        'narrative':
            "'트러블' 검색이 19% 올랐어요. 활성 여부와 홈케어 루틴부터 가볍게 확인해 보세요.",
        'naver_score': 45,
        'qualifies': true,
        'po_priority': 90,
      }),
    ];
    return ClinicalTrendSnapshot(
      items: items,
      top3: items,
      top1: items.first,
      fetchedAt: DateTime.now(),
      source: 'fallback',
      hasSurge: true,
    );
  }
}
