import 'package:flutter/material.dart';

import '../models/point_shop.dart';
import '../theme/sori_tokens.dart';

/// Fan-Boost 스폰서 크레딧 — 피드/상세 공통.
class FanSponsorCreditBanner extends StatelessWidget {
  const FanSponsorCreditBanner({
    super.key,
    required this.fanName,
    this.compact = false,
  });

  final String fanName;
  final bool compact;

  String get _name {
    final n = fanName.trim();
    return n.isEmpty ? '팬' : n;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1524),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: const Color(0x66F472B6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compact ? 16 : 18,
            color: const Color(0xFFF472B6),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              compact
                  ? 'Sponsored by $_name'
                  : '팬 $_name님의 지원사격',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFF9A8D4),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상세 상단 — 이 게시물을 띄워준 팬 아바타 열.
class FanSupportersAvatarRow extends StatelessWidget {
  const FanSupportersAvatarRow({
    super.key,
    required this.fanNames,
  });

  final List<String> fanNames;

  @override
  Widget build(BuildContext context) {
    final names = fanNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 게시물을 띄워준 팬',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final name = names[i];
                final initial =
                    name.isNotEmpty ? String.fromCharCode(name.runes.first) : '?';
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0x44F472B6),
                      child: Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFFF9A8D4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 48,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 샵 프로필 — TOP 서포터즈 랭킹 뼈대.
class ShopTopSupportersSection extends StatelessWidget {
  const ShopTopSupportersSection({
    super.key,
    required this.entries,
  });

  /// name → echo spent (표시용)
  final List<({String name, int echoSpent})> entries;

  /// 활성 Fan-Boost 배치에서 샵별 서포터 집계 (연동 준비용).
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
          'Fan-Boost로 샵을 밀어준 팬 랭킹 (연동 준비)',
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
              '아직 서포터즈가 없어요. 첫 Fan-Boost의 랭킹을 열어보세요.',
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
                            ? const Color(0xFFF9A8D4)
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
                        color: Color(0xFFF9A8D4),
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
                      color: Color(0xFFF9A8D4),
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
