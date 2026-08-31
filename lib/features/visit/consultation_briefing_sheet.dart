import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import 'ba_recall_cache.dart';
import 'today_agenda.dart';

/// PO Sprint 3.3 — 3초 브리핑 시트 (읽기 전용, CDG).
Future<void> showConsultationBriefingSheet({
  required BuildContext context,
  required ConsultationBriefing briefing,
  required VoidCallback onStartConsultation,
  VoidCallback? onOpenCustomerDetail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ConsultationBriefingSheet(
      briefing: briefing,
      onStartConsultation: () {
        Navigator.of(ctx).pop();
        onStartConsultation();
      },
      onOpenCustomerDetail: onOpenCustomerDetail == null
          ? null
          : () {
              Navigator.of(ctx).pop();
              onOpenCustomerDetail();
            },
    ),
  );
}

class _ConsultationBriefingSheet extends StatelessWidget {
  const _ConsultationBriefingSheet({
    required this.briefing,
    required this.onStartConsultation,
    this.onOpenCustomerDetail,
  });

  final ConsultationBriefing briefing;
  final VoidCallback onStartConsultation;
  final VoidCallback? onOpenCustomerDetail;

  static const _groupedBg = Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    final item = briefing.item;
    final thumbs = item.customerId.trim().isEmpty
        ? const <ChartBaThumb>[]
        : BaRecallCache.instance.thumbsFor(item.customerId);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: _groupedBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: [
                    _Header(briefing: briefing),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: '최근 방문',
                      child: _LastVisitRow(
                        lastVisit: briefing.lastVisitDate,
                        priorTreatment: briefing.priorTreatmentLabel,
                      ),
                    ),
                    if (briefing.concernChips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: '관심 · 고민',
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final chip in briefing.concernChips.take(6))
                              _Chip(label: chip),
                          ],
                        ),
                      ),
                    ],
                    if (briefing.todayPlanLabel.isNotEmpty ||
                        briefing.homeCareLabels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: '오늘 계획',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (briefing.todayPlanLabel.isNotEmpty)
                              Text(
                                briefing.todayPlanLabel,
                                style: VisitGlassTokens.bodyCalm,
                              ),
                            if (briefing.homeCareLabels.length > 1) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final label
                                      in briefing.homeCareLabels.skip(1).take(4))
                                    _Chip(label: label, subtle: true),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (thumbs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: 'B/A 회상',
                        child: SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: thumbs.length.clamp(0, 4),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final thumb = thumbs[i];
                              final url = thumb.beforeUrl?.trim().isNotEmpty ==
                                      true
                                  ? thumb.beforeUrl
                                  : thumb.afterUrl;
                              return _BaThumbTile(
                                url: url,
                                visitNo: thumb.visitNumber,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _PrimaryCta(
                      label: item.hasActiveSession ? '이어하기' : '상담 시작',
                      onTap: onStartConsultation,
                    ),
                    if (onOpenCustomerDetail != null &&
                        item.customerId.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onOpenCustomerDetail,
                        child: const Text('고객 상세 보기'),
                      ),
                    ],
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.briefing});

  final ConsultationBriefing briefing;

  @override
  Widget build(BuildContext context) {
    final item = briefing.item;
    final track = briefing.track;
    final visitNo = briefing.visitNumber;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: SoriTokens.surface,
          child: Text(
            item.customerName.characters.first,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.customerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  track.label,
                  if (visitNo != null) '${visitNo}회차',
                  item.timeLabel,
                ].join(' · '),
                style: VisitGlassTokens.captionCalm,
              ),
              if (item.schedule?.note.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  item.schedule!.note.trim(),
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: SoriTokens.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.hasActiveSession)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VisitGlassTokens.care.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.session!.phase.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VisitGlassTokens.care,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: VisitGlassTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LastVisitRow extends StatelessWidget {
  const _LastVisitRow({
    required this.lastVisit,
    required this.priorTreatment,
  });

  final DateTime? lastVisit;
  final String priorTreatment;

  @override
  Widget build(BuildContext context) {
    final dateLabel = lastVisit == null
        ? '기록 없음'
        : '${lastVisit!.year}.${lastVisit!.month.toString().padLeft(2, '0')}.${lastVisit!.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateLabel, style: VisitGlassTokens.bodyCalm),
        if (priorTreatment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            priorTreatment,
            style: VisitGlassTokens.captionCalm,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.subtle = false});

  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: subtle
            ? SoriTokens.surface
            : VisitGlassTokens.care.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SoriTokens.border.withValues(alpha: subtle ? 0.5 : 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: subtle ? SoriTokens.textSecondary : VisitGlassTokens.care,
        ),
      ),
    );
  }
}

class _BaThumbTile extends StatelessWidget {
  const _BaThumbTile({this.url, required this.visitNo});

  final String? url;
  final int visitNo;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: trimmed.isEmpty
                ? ColoredBox(
                    color: SoriTokens.surface,
                    child: Icon(
                      Icons.image_outlined,
                      color: SoriTokens.textSecondary.withValues(alpha: 0.5),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: trimmed,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${visitNo}회',
          style: VisitGlassTokens.captionCalm.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VisitGlassTokens.care,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
