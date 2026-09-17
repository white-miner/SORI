import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seminar_class.dart';
import '../theme/sori_tokens.dart';

/// Home feed card for open seminar recruitment posts.
class HomeSeminarFeedCard extends StatelessWidget {
  const HomeSeminarFeedCard({
    super.key,
    required this.seminar,
    required this.onOpenDetail,
    this.onOpenSourceCase,
  });

  final SeminarClass seminar;
  final VoidCallback onOpenDetail;
  final VoidCallback? onOpenSourceCase;

  static final _priceFmt = NumberFormat('#,###', 'ko_KR');
  static final _dateFmt = DateFormat('M월 d일 (E)', 'ko_KR');

  @override
  Widget build(BuildContext context) {
    final dateLabel = seminar.eventDate != null
        ? _dateFmt.format(seminar.eventDate!.toLocal())
        : '일정 협의';
    final hasSourceCase = seminar.targetCaseId?.trim().isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: SoriTokens.card(radius: 20).copyWith(
        border: Border.all(color: const Color(0x334338CA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x0A4338CA),
        child: InkWell(
          onTap: onOpenDetail,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4338CA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '세미나 모집',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      seminar.classFormatLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  seminar.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                if (seminar.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    seminar.description.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: SoriTokens.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${seminar.currentEnrollment}/${seminar.maxCapacity}명',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_priceFmt.format(seminar.price)}원',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
                if (hasSourceCase && onOpenSourceCase != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpenSourceCase,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF4338CA),
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                      label: const Text(
                        '이 세미나를 탄생시킨 B/A 케이스 보러가기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
