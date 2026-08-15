import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_chart.dart';
import '../services/openai_service.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';

/// 고객용 이케아 조립형 AI 리뷰 작성 동선.
class IkeaReviewComposerPage extends StatefulWidget {
  const IkeaReviewComposerPage({
    super.key,
    required this.store,
    this.chart,
    this.openAi,
  });

  final SoriStore store;
  final CustomerChart? chart;
  final OpenAiService? openAi;

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

  late final OpenAiService _openAi;
  final Set<String> _selected = {};
  String _aiReview = '';
  bool _generating = false;
  String? _aiError;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _openAi = widget.openAi ?? OpenAiService();
    _aiReview = _fallbackText();
  }

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

  String _fallbackText() => OpenAiService.localFallback(
        selectedChips: _selected.toList(),
        careName: _careName,
        shopName: widget.store.shop.name,
      );

  Future<void> _generateAiReview() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('만족 포인트를 2~3개 먼저 골라 주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _generating = true;
      _aiError = null;
    });

    try {
      final text = await _openAi.composeReview(
        selectedChips: _selected.toList(),
        careName: _careName,
        directorComment: _directorComment,
        shopName: widget.store.shop.name,
      );
      if (!mounted) return;
      setState(() => _aiReview = text);
    } on OpenAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.message;
        _aiReview = _fallbackText();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError = '잠시 후 다시 시도해 주세요';
        _aiReview = _fallbackText();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 문장 생성에 실패했어요. 잠시 후 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copyAndOpenNaver() async {
    final text = _aiReview.trim().isEmpty ? _fallbackText() : _aiReview.trim();
    setState(() => _copying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('클립보드에 후기를 복사했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      final chartId = _chart?.id;
      var synced = chartId == null;
      if (chartId != null) {
        try {
          final review = await widget.store.markNaverRegistered(
            chartId: chartId,
            composedText: text,
          );
          synced = review?.naverRegistered == true;
          widget.store.clearError();
        } catch (_) {
          synced = false;
          widget.store.clearError();
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  '복사는 완료됐어요. 네이버 등록 상태 저장은 잠시 후 다시 시도해 주세요.',
                ),
                backgroundColor: SoriTokens.warningText,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (synced && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('네이버 등록 완료로 저장했어요. 플레이스로 이동합니다.'),
            backgroundColor: SoriTokens.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final uri = Uri.tryParse(widget.store.shop.naverReviewDeepLink);
      if (uri == null || uri.toString().trim().isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                '네이버 리뷰 작성 URL이 없어요. 샵 정보에서 직행 링크를 등록해 주세요.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('복사 중 문제가 생겼어요: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _copying = false);
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
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generating ? null : _generateAiReview,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _generating ? 'AI가 문장을 조립 중…' : 'AI로 문장 조립하기',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      side: const BorderSide(color: SoriTokens.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SoriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(step: 3, label: 'AI 리뷰 결과'),
                const SizedBox(height: 12),
                if (_generating)
                  const _ReviewShimmer()
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SoriTokens.border),
                    ),
                    child: Text(
                      _aiReview,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                if (_aiError != null && !_generating) ...[
                  const SizedBox(height: 8),
                  Text(
                    _aiError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_generating || _copying)
                        ? null
                        : _copyAndOpenNaver,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF03C75A),
                      disabledBackgroundColor:
                          const Color(0xFF03C75A).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _copying
                          ? '처리 중…'
                          : '📋 복사하고 네이버에 리뷰 남기기',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (_chart?.feedbackToken != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SoriShare.shareReviewLink(
                          url: SoriStore.buildCustomerReviewUrl(
                            _chart!.feedbackToken!,
                          ),
                          customerName:
                              widget.store.session?.name ?? '고객',
                          careName: _careName,
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text(
                        '링크 공유하기',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SoriTokens.primary,
                        side: const BorderSide(color: SoriTokens.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewShimmer extends StatelessWidget {
  const _ReviewShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF9FAFB),
      child: Column(
        children: List.generate(4, (i) {
          return Container(
            height: i == 3 ? 16 : 14,
            margin: EdgeInsets.only(bottom: i == 3 ? 0 : 10),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
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
