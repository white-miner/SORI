import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/clinical_trend_snapshot.dart';
import '../models/shop_climate_context.dart';
import 'trend_sparkline.dart';
import 'skin_stress_gauge.dart';
import 'sori_narrative_block.dart';

/// PRD v4.2 + v4.3 — Strip 탭 → SSI + Trend Radar 풀 시트.
Future<void> showClinicalAssistantSheet({
  required BuildContext context,
  required ShopClimateContext climate,
  ClinicalTrendSnapshot? trends,
  ClinicalTrendItem? initialTrend,
  int tempoLevel = 1,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ClinicalAssistantSheet(
      climate: climate,
      trends: trends,
      initialTrend: initialTrend,
      tempoLevel: tempoLevel,
    ),
  );
}

class _ClinicalAssistantSheet extends StatefulWidget {
  const _ClinicalAssistantSheet({
    required this.climate,
    this.trends,
    this.initialTrend,
    required this.tempoLevel,
  });

  final ShopClimateContext climate;
  final ClinicalTrendSnapshot? trends;
  final ClinicalTrendItem? initialTrend;
  final int tempoLevel;

  @override
  State<_ClinicalAssistantSheet> createState() => _ClinicalAssistantSheetState();
}

class _ClinicalAssistantSheetState extends State<_ClinicalAssistantSheet> {
  ClinicalTrendItem? _selected;

  @override
  void initState() {
    super.initState();
    final trends = widget.trends;
    _selected = widget.initialTrend ??
        trends?.top3.firstOrNull ??
        trends?.briefingLead;
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.climate.brief;
    final trends = widget.trends;
    final selected = _selected;

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    Center(
                      child: SkinStressGauge(
                        ssi: widget.climate.ssi,
                        size: 160,
                        strokeWidth: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MetricGrid(climate: widget.climate),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: SoriNarrativeBlock(
                        headline: brief.headline,
                        narrative: brief.narrative,
                        icon: Icons.spa_outlined,
                      ),
                    ),
                    if (trends != null && trends.top3.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        '임상 트렌드 레이더',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: VisitGlassTokens.care,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in trends.top3)
                            _SelectableTrendChip(
                              item: item,
                              selected: selected?.id == item.id,
                              onTap: () => setState(() => _selected = item),
                            ),
                        ],
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: TrendSparkline(
                                  values: selected.sparkline7d,
                                  width: 220,
                                  height: 44,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Naver ${selected.naverScore} · CTI ${selected.cti}',
                                style: VisitGlassTokens.captionCalm.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              SoriNarrativeBlock(
                                headline: selected.headline,
                                narrative: selected.narrative,
                                icon: Icons.trending_up_outlined,
                                compact: true,
                              ),
                              if (brief.shouldSurface) ...[
                                const SizedBox(height: 10),
                                SoriNarrativeBlock(
                                  headline: '환경 연계',
                                  narrative:
                                      'SSI ${widget.climate.ssi.band.label} — ${brief.headline}과 함께 "${selected.keyword}" 상담 화법을 연결하세요.',
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (brief.alerts.length > 1) ...[
                      const SizedBox(height: 12),
                      for (final alert in brief.alerts.skip(1).take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: SoriNarrativeBlock(
                              headline: alert.headline,
                              narrative: alert.narrative,
                              compact: true,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    _BindRow(
                      label: '웰컴 진정 온도',
                      value: '${brief.calmTargetC.toStringAsFixed(1)}°C',
                    ),
                    const SizedBox(height: 8),
                    _BindRow(
                      label: '장비 강도 상한',
                      value: 'Level ${brief.deviceIntensityCap}',
                    ),
                    if (widget.tempoLevel >= 4) ...[
                      const SizedBox(height: 12),
                      const SoriNarrativeBlock(
                        headline: '과밀 스케줄',
                        narrative: '워크인은 15분 이상 공백 슬롯에서만 권장합니다.',
                        icon: Icons.schedule_rounded,
                        compact: true,
                      ),
                    ],
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

class _SelectableTrendChip extends StatelessWidget {
  const _SelectableTrendChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ClinicalTrendItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VisitGlassTokens.care : const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.black.withValues(alpha: selected ? 0.12 : 0.06),
            ),
          ),
          child: Text(
            item.surgePct > 0
                ? '${item.keyword} +${item.surgePct}%'
                : item.keyword,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : VisitGlassTokens.care,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.climate});

  final ShopClimateContext climate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '온도',
            value: '${climate.tempC.toStringAsFixed(0)}°C',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '습도',
            value: '${climate.humidityPct}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(label: 'UV', value: '${climate.uvIndex}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'PM2.5',
            value: '${climate.pm25UgM3}',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: VisitGlassTokens.captionCalm.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BindRow extends StatelessWidget {
  const _BindRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: VisitGlassTokens.captionCalm.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: VisitGlassTokens.bodyCalm.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
