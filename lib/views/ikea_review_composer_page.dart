import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';

/// 고객용 이케아 조립형 AI 리뷰 작성 동선.
class IkeaReviewComposerPage extends StatefulWidget {
  const IkeaReviewComposerPage({
    super.key,
    required this.store,
    this.chart,
  });

  final SoriStore store;
  final CustomerChart? chart;

  @override
  State<IkeaReviewComposerPage> createState() => _IkeaReviewComposerPageState();
}

class _IkeaReviewComposerPageState extends State<IkeaReviewComposerPage> {
  static const List<String> _blockChips = [
    '속당김 해결',
    '친절한 설명',
    '프라이빗한 공간',
    '아프지 않은 케어',
    '보습이 오래감',
    '맞춤 홈케어 안내',
    '시술 후 톤업',
    '대기 없이 쾌적',
  ];

  final Set<String> _selected = {};

  CustomerChart? get _chart {
    if (widget.chart != null) return widget.chart;
    final id = widget.store.session?.customerId;
    if (id == null) return null;
    return widget.store.latestChart(id);
  }

  String get _careName {
    final chart = _chart;
    if (chart == null) return '수분 집중 케어';
    if (chart.careName.isNotEmpty) return chart.careName;
    return chart.treatmentSummary.isNotEmpty
        ? chart.treatmentSummary
        : '맞춤 에스테틱 케어';
  }

  String get _directorComment {
    final insight = _chart?.directorInsight.trim();
    if (insight != null && insight.isNotEmpty) return insight;
    return '오늘 피부 컨디션에 맞춰 자극을 줄이고 보습 장벽을 중심으로 케어했어요. 홈에서는 미지근한 클렌징을 권해 드려요.';
  }

  String get _composedReview {
    final picks = _selected.isEmpty
        ? '편안하게 케어받을 수 있었어요'
        : _selected.join(', ');
    return '오늘은 $_careName를 받았는데, 특히 $picks 점이 마음에 들었어요. '
        '원장님 설명이 꼼꼼해서 다음에도 믿고 방문하고 싶습니다. '
        '#${widget.store.shop.name.replaceAll(' ', '')} #소통하는리뷰';
  }

  Future<void> _copyAndOpenNaver() async {
    await Clipboard.setData(ClipboardData(text: _composedReview));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('후기 문구를 복사했어요. 네이버로 이동합니다.'),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    final uri = Uri.tryParse(widget.store.shop.naverReviewDeepLink);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Text(
            '이케아처럼 조립하는 후기',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '블록을 고르면 AI가 자연스러운 리뷰 문장을 만들어 드려요',
            style: TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 16),

          // STEP 1
          SoriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(step: 1, label: 'AI 케어 요약'),
                const SizedBox(height: 12),
                Text(
                  _careName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SoriTokens.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '원장님 코멘트\n$_directorComment',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // STEP 2
          SoriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(step: 2, label: '후기 블록 선택'),
                const SizedBox(height: 10),
                const Text(
                  '오늘 가장 만족스러웠던 점을 2~3개 골라주세요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _blockChips.map((chip) {
                    final selected = _selected.contains(chip);
                    return FilterChip(
                      label: Text(chip),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selected.add(chip);
                          } else {
                            _selected.remove(chip);
                          }
                        });
                      },
                      selectedColor: SoriTokens.primarySoft,
                      checkmarkColor: SoriTokens.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? SoriTokens.primary
                            : SoriTokens.textPrimary,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // STEP 3
          SoriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(step: 3, label: 'AI 리뷰 결과'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SoriTokens.border),
                  ),
                  child: Text(
                    _composedReview,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _copyAndOpenNaver,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF03C75A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '📋 복사하고 네이버 영수증 리뷰 가기',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step, required this.label});

  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SoriTokens.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'STEP $step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
