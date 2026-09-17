import 'dart:math' as math;

/// Home / Community 피드 세그먼트 — Ad 인벤토리 격리 키.
enum FeedSegment {
  caseFeed('case'),
  interior('interior'),
  deviceReview('device_review');

  const FeedSegment(this.dbValue);
  final String dbValue;

  static FeedSegment fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'interior':
        return FeedSegment.interior;
      case 'device_review':
      case 'device-review':
        return FeedSegment.deviceReview;
      default:
        return FeedSegment.caseFeed;
    }
  }
}

/// 부스터 슬롯 후보 스코어 입력.
class BoostScoreInput {
  const BoostScoreInput({
    required this.targetId,
    required this.placementId,
    this.fandomEcho = 0,
    this.paidRatio = 0.5,
    this.startsAt,
    this.isFanBoost = false,
    this.pointsSpent = 0,
  });

  final String targetId;
  final String placementId;
  final int fandomEcho;
  final double paidRatio;
  final DateTime? startsAt;
  final bool isFanBoost;
  final int pointsSpent;

  /// 가중치: Fandom > Paid > Recency + Fan bonus.
  double score({DateTime? now, double recencyTauHours = 12}) {
    final n = now ?? DateTime.now();
    final fandom =
        math.log(1 + math.max(0, fandomEcho)) / math.log(1 + 5000);
    final paid = paidRatio.clamp(0.0, 1.0);
    final ageH = startsAt == null
        ? 24.0
        : n.difference(startsAt!).inSeconds / 3600.0;
    final recency = math.exp(-ageH / recencyTauHours).clamp(0.0, 1.0);
    final fanBonus = isFanBoost ? 1.0 : 0.45;
    return 0.40 * fandom.clamp(0.0, 1.0) +
        0.25 * paid +
        0.20 * recency +
        0.15 * fanBonus;
  }
}

/// viewer_seed 기반 결정적 셔플 (같은 seed → 같은 순열).
List<T> seededShuffle<T>(List<T> input, String seed) {
  if (input.length <= 1) return List<T>.from(input);
  final out = List<T>.from(input);
  var state = _fnv1a(seed);
  for (var i = out.length - 1; i > 0; i--) {
    state = _xorshift(state);
    final j = state % (i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

/// 스코어 DESC → 상위 [poolSize] 시드 셔플 → 슬롯 수만큼 추출.
List<BoostScoreInput> pickBoostSlots({
  required List<BoostScoreInput> candidates,
  required int slotCount,
  required String viewerSeed,
  int poolSize = 40,
  DateTime? now,
}) {
  if (slotCount <= 0 || candidates.isEmpty) return const [];
  final ranked = List<BoostScoreInput>.from(candidates)
    ..sort((a, b) {
      final c = b.score(now: now).compareTo(a.score(now: now));
      if (c != 0) return c;
      return a.targetId.compareTo(b.targetId);
    });
  final pool = ranked.take(math.min(poolSize, ranked.length)).toList();
  final shuffled = seededShuffle(pool, viewerSeed);
  return shuffled.take(math.min(slotCount, shuffled.length)).toList();
}

/// 4:1 Interleave — Boost at indices 0,5,10,15… (≤20% Ad).
/// [organic] 최신순, [boosted] 이미 슬롯 순서로 정렬된 부스터 아이템.
List<T> interleaveFeed<T>({
  required List<T> organic,
  required List<T> boosted,
  required String Function(T) idOf,
  int boostEvery = 5,
}) {
  if (boosted.isEmpty) return List<T>.from(organic);
  if (organic.isEmpty) return List<T>.from(boosted);

  final boostIds = boosted.map(idOf).toSet();
  final organics = organic.where((e) => !boostIds.contains(idOf(e))).toList();
  final out = <T>[];
  var oi = 0;
  var bi = 0;
  var i = 0;
  final maxLen = organics.length + boosted.length;
  while (out.length < maxLen && (oi < organics.length || bi < boosted.length)) {
    final wantBoost = boostEvery > 0 && i % boostEvery == 0;
    if (wantBoost && bi < boosted.length) {
      out.add(boosted[bi++]);
      i++;
      continue;
    }
    if (oi < organics.length) {
      out.add(organics[oi++]);
      i++;
      continue;
    }
    // Organic exhausted: only fill remaining boosts on boost slots (no pin-all dump).
    if (bi < boosted.length) {
      if (wantBoost) {
        out.add(boosted[bi++]);
        i++;
      } else {
        i++;
      }
      continue;
    }
    break;
  }
  return out;
}

/// 페이지당 필요 슬롯 수 (pageSize=20 → 4).
int boostSlotsForPage(int pageSize, {int boostEvery = 5}) {
  if (pageSize <= 0 || boostEvery <= 0) return 0;
  return (pageSize / boostEvery).floor();
}

/// 시간창 시드: userId|segment|hourBucket
String feedViewerSeed({
  required String viewerId,
  required FeedSegment segment,
  DateTime? now,
  int hourBucket = 1,
}) {
  final n = now ?? DateTime.now().toUtc();
  final bucket = n.millisecondsSinceEpoch ~/
      (Duration(hours: hourBucket).inMilliseconds);
  final vid = viewerId.trim().isEmpty ? 'anon' : viewerId.trim();
  return '$vid|${segment.dbValue}|$bucket';
}

int _fnv1a(String s) {
  var hash = 0x811c9dc5;
  for (final c in s.codeUnits) {
    hash ^= c;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

int _xorshift(int state) {
  var x = state;
  x ^= (x << 13) & 0x7fffffff;
  x ^= (x >> 17);
  x ^= (x << 5) & 0x7fffffff;
  return x == 0 ? 1 : x;
}
