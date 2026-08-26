import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/fan_supporter.dart';
import '../models/point_shop.dart';
import '../theme/sori_tokens.dart';

/// 미디어 하단 1줄 글래스 스트립 — B/A 위에 올리지 않음 (높이 ≤44).
class FanBoostCreditStrip extends StatelessWidget {
  const FanBoostCreditStrip({
    super.key,
    required this.supporters,
    this.onTap,
  });

  final List<FanSupporterEntry> supporters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ranked = FanSupporterEntry.ranked(supporters);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final lead = ranked.first.name.trim().isEmpty ? '팬' : ranked.first.name.trim();
    final others = ranked.length - 1;
    final copy = others <= 0
        ? '팬 $lead님의 지원사격'
        : '팬 $lead님 외 ${others}명 지원사격';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x991A1218),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x55F472B6)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: SoriTokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    SupporterFacepile(supporters: ranked, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        copy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: SoriTokens.textSecondary,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0x99F9A8D4),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top 3 아바타 겹침 + `+N` 오버플로우 칩.
class SupporterFacepile extends StatelessWidget {
  const SupporterFacepile({
    super.key,
    required this.supporters,
    this.size = 22,
    this.maxVisible = 3,
  });

  final List<FanSupporterEntry> supporters;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final ranked = FanSupporterEntry.ranked(supporters);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final visible = ranked.take(maxVisible).toList();
    final overflow = ranked.length - visible.length;
    final overlap = size * 0.36; // ~−8px when size=22
    final count = visible.length + (overflow > 0 ? 1 : 0);
    final width = size + (count - 1) * (size - overlap);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: _FaceAvatar(entry: visible[i], size: size),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B1F32),
                  border: Border.all(color: const Color(0xFF1A1218), width: 1.5),
                ),
                child: Text(
                  overflow > 99 ? '99+' : '+$overflow',
                  style: TextStyle(
                    fontSize: size < 24 ? 8.5 : 10,
                    fontWeight: FontWeight.w900,
                    color: SoriTokens.textSecondary,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaceAvatar extends StatelessWidget {
  const _FaceAvatar({required this.entry, required this.size});

  final FanSupporterEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = entry.avatarUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1A1218), width: 1.5),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0x44F472B6),
        backgroundImage:
            url.isNotEmpty && !url.startsWith('data:') ? NetworkImage(url) : null,
        child: url.isEmpty || url.startsWith('data:')
            ? Text(
                entry.initial,
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.textSecondary,
                ),
              )
            : null,
      ),
    );
  }
}

/// 레거시 단일 닉 배너 — Facepile 없을 때 fallback.
class FanSponsorCreditBanner extends StatelessWidget {
  const FanSponsorCreditBanner({
    super.key,
    required this.fanName,
    this.compact = false,
  });

  final String fanName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = fanName.trim().isEmpty ? '팬' : fanName.trim();
    return FanBoostCreditStrip(
      supporters: [FanSupporterEntry(name: name, echoSpent: 0)],
    );
  }
}

/// 상세 — 동일 스트립 + 시트 트리거 (아바타 가로열 대체).
class FanSupportersAvatarRow extends StatelessWidget {
  const FanSupportersAvatarRow({
    super.key,
    required this.fanNames,
    this.supporters = const [],
    this.onOpenSheet,
  });

  final List<String> fanNames;
  final List<FanSupporterEntry> supporters;
  final VoidCallback? onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final list = supporters.isNotEmpty
        ? supporters
        : fanNames
            .map((n) => FanSupporterEntry(name: n, echoSpent: 0))
            .where((e) => e.name.trim().isNotEmpty)
            .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return FanBoostCreditStrip(supporters: list, onTap: onOpenSheet);
  }
}

Future<void> showFanSupportersSheet(
  BuildContext context, {
  required List<FanSupporterEntry> supporters,
  String title = '이 게시물의 Top 서포터즈',
}) {
  final ranked = FanSupporterEntry.ranked(supporters);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.58;
      return SafeArea(
        child: SizedBox(
          height: h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SoriTokens.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: SoriTokens.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Fan-Boost · 누적 Echo · 닉네임 공개',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ranked.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 서포터즈가 없어요.',
                          style: TextStyle(color: SoriTokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: ranked.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = ranked[i];
                          final rank = i + 1;
                          final rose = rank <= 3;
                          return Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: rose
                                        ? SoriTokens.textSecondary
                                        : SoriTokens.textSecondary,
                                  ),
                                ),
                              ),
                              _FaceAvatar(entry: row, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  row.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              Text(
                                '${row.echoSpent}E',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  color: rose
                                      ? SoriTokens.textSecondary
                                      : SoriTokens.textSecondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 샵 프로필 — TOP 서포터즈 랭킹 뼈대.
class ShopTopSupportersSection extends StatelessWidget {
  const ShopTopSupportersSection({
    super.key,
    required this.entries,
  });

  final List<({String name, int echoSpent})> entries;

  static List<({String name, int echoSpent})> fromBoosts(
    Iterable<BoostPlacement> boosts, {
    required String shopId,
  }) {
    final map = <String, int>{};
    for (final b in boosts) {
      if (b.shopId != shopId || !b.isFanBoost) continue;
      final name = b.fanDisplayName.trim();
      if (name.isEmpty) continue;
      map[name] = (map[name] ?? 0) + b.pointsSpent;
    }
    final list = map.entries
        .map((e) => (name: e.key, echoSpent: e.value))
        .toList()
      ..sort((a, b) => b.echoSpent.compareTo(a.echoSpent));
    return list;
  }

  static List<({String name, int echoSpent})> fromSupporters(
    Iterable<FanSupporterEntry> supporters,
  ) {
    return FanSupporterEntry.ranked(supporters)
        .map((e) => (name: e.name, echoSpent: e.echoSpent))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '우리 샵 TOP 서포터즈',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fan-Boost로 샵을 밀어준 팬 랭킹',
          style: TextStyle(
            fontSize: 11.5,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: SoriTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.border),
            ),
            child: const Text(
              '아직 서포터즈가 없어요. 첫 Fan-Boost로 랭킹을 열어보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...entries.take(5).toList().asMap().entries.map((e) {
            final rank = e.key + 1;
            final row = e.value;
            final initial = row.name.isNotEmpty
                ? String.fromCharCode(row.name.runes.first).toUpperCase()
                : '?';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: rank <= 3
                            ? SoriTokens.textSecondary
                            : SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0x44F472B6),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${row.echoSpent}E',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
