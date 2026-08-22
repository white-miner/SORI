import 'package:flutter/material.dart';

import '../models/seminar_class.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/seminar_class_detail_page.dart';
import '../views/seminar_class_open_page.dart';
import '../views/seminar_feedback_inbox_page.dart';

/// My Page · Seminar 탭 — 카드 피드.
class MySeminarTabBody extends StatefulWidget {
  const MySeminarTabBody({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  @override
  State<MySeminarTabBody> createState() => _MySeminarTabBodyState();
}

class _MySeminarTabBodyState extends State<MySeminarTabBody> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshSeminarClasses();
      widget.store.refreshMySeminarEnrollments();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeminarClassOpenPage(store: widget.store),
      ),
    );
    await widget.store.refreshSeminarClasses();
  }

  String _statusLabel(SeminarClassStatus s) => switch (s) {
        SeminarClassStatus.open => '모집 중',
        SeminarClassStatus.held => '진행',
        SeminarClassStatus.completed => '완료',
        SeminarClassStatus.cancelled => '취소',
        SeminarClassStatus.draft => '초안',
      };

  Color _statusColor(SeminarClassStatus s) => switch (s) {
        SeminarClassStatus.open => SoriTokens.primary,
        SeminarClassStatus.held => const Color(0xFF0EA5E9),
        SeminarClassStatus.completed => SoriTokens.textSecondary,
        SeminarClassStatus.cancelled => Colors.redAccent,
        SeminarClassStatus.draft => SoriTokens.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final classes = widget.store.seminarClasses;
    final held = widget.store.mySeminarEnrollments
        .where((e) => e.isHeld)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seminar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (widget.isOwner) ...[
                  TextButton(
                    onPressed: () => SeminarFeedbackInboxPage.open(
                      context,
                      store: widget.store,
                    ),
                    child: const Text('피드백'),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('개설'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (classes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  '개설된 세미나가 없어요\n「개설」로 첫 클래스를 만들어 보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final c = classes[i];
                final when = c.eventDate;
                final whenLabel = when == null
                    ? '일정 미정'
                    : '${when.year}.${when.month.toString().padLeft(2, '0')}.${when.day.toString().padLeft(2, '0')}';
                return Material(
                  color: SoriTokens.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SeminarClassDetailPage(
                            store: widget.store,
                            classId: c.id,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: SoriTokens.outlinePurple),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(c.status)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  _statusLabel(c.status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _statusColor(c.status),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                c.classFormatLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: SoriTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            c.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$whenLabel · ${c.location.trim().isEmpty ? '장소 미정' : c.location.trim()}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '정원 ${c.currentEnrollment}/${c.maxCapacity}'
                            '${c.price > 0 ? ' · ${c.price}원' : ''}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              widget.isOwner ? '관리하기 →' : '자세히 보기 →',
                              style: const TextStyle(
                                color: SoriTokens.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (held.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: Text(
                '내 수강 ${held.length}건 진행 중',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
