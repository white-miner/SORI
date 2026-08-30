import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/customer_chart.dart';
import '../../models/home_care_prescriptions.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';

/// Consultation Surface — 고객 대면 co-view (B안, PRD v3.0).
/// 내부 메모·연락처 등 민감 정보 미노출. B/A + 상태 칩 + 관리 계획만.
class ConsultationSurfacePage extends StatefulWidget {
  const ConsultationSurfacePage({
    super.key,
    required this.customerName,
    required this.chart,
    this.careLabel,
  });

  final String customerName;
  final CustomerChart chart;
  final String? careLabel;

  @override
  State<ConsultationSurfacePage> createState() =>
      _ConsultationSurfacePageState();
}

class _ConsultationSurfacePageState extends State<ConsultationSurfacePage> {
  bool _showAfter = false;

  List<String> get _statusChips {
    final chips = <String>[];
    chips.addAll(widget.chart.concernChips);
    if (widget.chart.skinSensitivity.trim().isNotEmpty) {
      chips.add(widget.chart.skinSensitivity.trim());
    }
    if (widget.chart.careName.trim().isNotEmpty) {
      chips.add(widget.chart.careName.trim());
    }
    return chips.take(8).toList();
  }

  List<String> get _planTags {
    return HomecareDictionary.sanitizeTagIds(widget.chart.homeCarePrescriptions);
  }

  @override
  Widget build(BuildContext context) {
    final before = widget.chart.beforeImageUrl?.trim();
    final after = widget.chart.afterImageUrl?.trim();
    final hasBefore = before != null && before.isNotEmpty;
    final hasAfter = after != null && after.isNotEmpty;
    final canSlide = hasBefore && hasAfter;

    return Scaffold(
      backgroundColor: const Color(0xFF141018),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.customerName}님 · 함께 보는 케어',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    VisitGlassCard(
                      socialGlow: true,
                      tint: VisitGlassTokens.care,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(VisitGlassTokens.radiusLg),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: _HeroPhoto(
                            beforeUrl: before,
                            afterUrl: after,
                            showAfter: _showAfter,
                          ),
                        ),
                      ),
                    ),
                    if (canSlide) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ToggleChip(
                            label: 'Before',
                            selected: !_showAfter,
                            onTap: () => setState(() => _showAfter = false),
                          ),
                          const SizedBox(width: 8),
                          _ToggleChip(
                            label: 'After',
                            selected: _showAfter,
                            onTap: () => setState(() => _showAfter = true),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '오늘의 상태',
                      style: VisitGlassTokens.captionCalm.copyWith(
                        color: VisitGlassTokens.care,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusChips.isEmpty
                          ? [
                              _StatusChip(
                                label: widget.careLabel?.trim().isNotEmpty == true
                                    ? widget.careLabel!.trim()
                                    : '상담 중',
                              ),
                            ]
                          : _statusChips
                              .map((c) => _StatusChip(label: c))
                              .toList(),
                    ),
                    if (_planTags.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        '관리 계획',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          color: VisitGlassTokens.sage,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _planTags
                            .map(
                              (id) => _StatusChip(
                                label: HomecareDictionary.chipLabelOf(id) ?? id,
                                sage: true,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (widget.chart.treatmentSummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      VisitGlassCard(
                        tint: VisitGlassTokens.sage,
                        child: Text(
                          widget.chart.treatmentSummary.trim(),
                          style: VisitGlassTokens.bodyCalm.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({
    required this.beforeUrl,
    required this.afterUrl,
    required this.showAfter,
  });

  final String? beforeUrl;
  final String? afterUrl;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final url = showAfter && afterUrl != null && afterUrl!.isNotEmpty
        ? afterUrl
        : beforeUrl;

    if (url == null || url.isEmpty) {
      return Container(
        color: VisitGlassTokens.careSoft,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 48,
              color: VisitGlassTokens.care.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              '촬영된 사진이 여기에 표시됩니다',
              style: VisitGlassTokens.captionCalm.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: VisitGlassTokens.care),
      ),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: VisitGlassTokens.calmMotion,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? VisitGlassTokens.care.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? VisitGlassTokens.care.withValues(
                      alpha: VisitGlassTokens.edgeGlowMin,
                    )
                  : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.sage = false});

  final String label;
  final bool sage;

  @override
  Widget build(BuildContext context) {
    final color = sage ? VisitGlassTokens.sage : VisitGlassTokens.care;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.14),
        border: Border.all(
          color: color.withValues(alpha: VisitGlassTokens.edgeGlowMin),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: sage ? VisitGlassTokens.sage : VisitGlassTokens.care,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
