import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/visit/report/visit_care_report.dart';
import '../models/customer_chart.dart';
import '../models/home_care_prescriptions.dart';
import '../models/kakao_alimtalk.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 카카오 알림톡 버튼 랜딩 — `/#/care-report/:chartId` (로그인 불필요).
class CareReportPage extends StatefulWidget {
  const CareReportPage({
    super.key,
    required this.chartId,
    this.store,
  });

  final String chartId;
  final SoriStore? store;

  @override
  State<CareReportPage> createState() => _CareReportPageState();
}

class _CareReportPageState extends State<CareReportPage> {
  bool _loading = true;
  PublicCareReport? _report;
  String? _error;

  SoriStore get _store => widget.store ?? SoriStore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final report = await _store.loadPublicCareReport(widget.chartId);
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
      if (report == null) {
        _error = '유효하지 않은 케어 리포트 링크입니다';
      }
    });
  }

  Future<void> _callShop(Shop shop) async {
    final digits = (shop.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록된 샵 전화번호가 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: digits);
    await launchUrl(uri);
  }

  Future<void> _openBooking(Shop shop) async {
    final naver = shop.naverPlaceUrl.trim();
    if (naver.isNotEmpty) {
      final uri = Uri.tryParse(naver);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    await _callShop(shop);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: SoriTokens.background,
        body: Center(
          child: CircularProgressIndicator(color: SoriTokens.primary),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return Scaffold(
        backgroundColor: SoriTokens.background,
        body: Center(
          child: Text(
            _error ?? '리포트를 불러올 수 없습니다',
            style: const TextStyle(color: SoriTokens.textSecondary),
          ),
        ),
      );
    }

    final chart = report.chart;
    final shop = report.shop;
    final name = (report.customerDisplayName ?? '고객').trim();
    final care =
        chart.careName.trim().isEmpty ? '오늘의 케어' : chart.careName.trim();
    final summary = chart.treatmentSummary.trim().isNotEmpty
        ? chart.treatmentSummary.trim()
        : (chart.directorInsight.trim().isNotEmpty
            ? chart.directorInsight.trim()
            : '오늘 케어 내용을 확인해 주세요.');
    final missions = _missionLines(chart);
    final careReport = _parseCareReport(chart);

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              shop.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SoriTokens.primary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$name님의 케어 리포트',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '회차 ${chart.visitNumber} · $care',
              style: const TextStyle(
                fontSize: 14,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            if (careReport != null) ...[
              _CareTimeSummaryCard(report: careReport),
              const SizedBox(height: 12),
            ],
            _SectionCard(
              title: '오늘의 케어 내용',
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: SoriTokens.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Before / After',
              child: Row(
                children: [
                  Expanded(
                    child: _PhotoSlot(
                      label: 'Before',
                      url: chart.beforeImageUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      label: 'After',
                      url: chart.afterImageUrl,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '3일 홈케어 미션',
              child: Column(
                children: [
                  for (var i = 0; i < missions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _MissionRow(day: i + 1, text: missions[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callShop(shop),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('샵 전화연결'),
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
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openBooking(shop),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('예약'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  VisitCareReport? _parseCareReport(CustomerChart chart) {
    final raw = chart.careReportJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return VisitCareReport.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  List<String> _missionLines(CustomerChart chart) {
    final tags = HomecareDictionary.sanitizeTagIds(chart.homeCarePrescriptions);
    final lines = <String>[];
    for (final tag in tags) {
      final label = HomecareDictionary.chipLabelOf(tag);
      final directive = HomecareDictionary.directiveOf(tag);
      if (label != null && directive != null) {
        lines.add('$label — $directive');
      } else if (label != null) {
        lines.add(label);
      }
      if (lines.length >= 3) break;
    }
    while (lines.length < 3) {
      const fallback = [
        '미지근한 물로 가볍게 세안하고 보습을 듬뿍 올려 주세요.',
        '자외선 차단을 실내에서도 잊지 마세요.',
        '열감·자극이 있으면 샵으로 바로 연락해 주세요.',
      ];
      lines.add(fallback[lines.length]);
    }
    return lines.take(3).toList(growable: false);
  }
}

class _CareTimeSummaryCard extends StatelessWidget {
  const _CareTimeSummaryCard({required this.report});

  final VisitCareReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 케어 시간',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${report.careMinutes}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF34C759),
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '분 케어',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              if (report.overtimeMinutes > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${report.overtimeMinutes}분 정성',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '샵에서 함께한 시간 총 ${report.totalVisitMinutes}분',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
          if (report.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final step in report.steps) ...[
              _StepTimelineRow(step: step),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

class _StepTimelineRow extends StatelessWidget {
  const _StepTimelineRow({required this.step});

  final VisitCareStepLine step;

  @override
  Widget build(BuildContext context) {
    final actualMin = (step.actualSeconds + 59) ~/ 60;
    return Row(
      children: [
        Expanded(
          child: Text(
            step.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        Text(
          '${step.plannedMinutes}분 → ${actualMin}분',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SoriTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: SoriTokens.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: trimmed.isEmpty
                ? Container(
                    color: SoriTokens.surfaceElevated,
                    alignment: Alignment.center,
                    child: const Text(
                      '사진 준비 중',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  )
                : Image.network(
                    trimmed,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      color: SoriTokens.surfaceElevated,
                      alignment: Alignment.center,
                      child: const Text(
                        '불러오기 실패',
                        style: TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.day, required this.text});

  final int day;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SoriTokens.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'D$day',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: SoriTokens.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
