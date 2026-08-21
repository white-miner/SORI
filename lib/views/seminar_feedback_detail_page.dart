import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seminar_feedback_report.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// AI 세미나 피드백 리포트 상세.
class SeminarFeedbackDetailPage extends StatefulWidget {
  const SeminarFeedbackDetailPage({
    super.key,
    required this.store,
    required this.reportId,
  });

  final SoriStore store;
  final String reportId;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required String reportId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeminarFeedbackDetailPage(
          store: store,
          reportId: reportId,
        ),
      ),
    );
  }

  @override
  State<SeminarFeedbackDetailPage> createState() =>
      _SeminarFeedbackDetailPageState();
}

class _SeminarFeedbackDetailPageState extends State<SeminarFeedbackDetailPage> {
  SeminarFeedbackReport? _report;
  bool _loading = true;

  static final _dateFmt = DateFormat('yyyy년 M월 d일', 'ko_KR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail =
        await widget.store.loadSeminarFeedbackReportDetail(widget.reportId);
    if (!mounted) return;
    setState(() {
      _report = detail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          'AI 피드백 리포트',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('리포트를 불러올 수 없습니다.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _HeaderCard(report: _report!, dateFmt: _dateFmt),
                    const SizedBox(height: 12),
                    _InsightInfographicCard(
                      emoji: '🔥',
                      title: '핵심 강점',
                      body: _report!.aiSummaryStrength,
                      tint: const Color(0xFFEF4444),
                      bg: const Color(0xFF2A1518),
                    ),
                    const SizedBox(height: 12),
                    _InsightInfographicCard(
                      emoji: '💡',
                      title: '다음 기수 성장 팁',
                      body: _report!.aiSummaryImprovement,
                      tint: const Color(0xFF0EA5E9),
                      bg: const Color(0xFF152033),
                    ),
                    const SizedBox(height: 12),
                    _PositiveCommentsCard(comments: _report!.positiveComments),
                  ],
                ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.report, required this.dateFmt});

  final SeminarFeedbackReport report;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final dateLabel = report.eventDate == null
        ? '일정 미기재'
        : dateFmt.format(report.eventDate!.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.classTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$dateLabel · 피드백 ${report.rawFeedbackCount}건 · 수강 완료 ${report.completedEnrollmentCount}명',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          if (report.topInsightTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.topInsightTags.map((tag) {
                return Chip(
                  label: Text(
                    tag.startsWith('#') ? tag : '#$tag',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: SoriTokens.primarySoft,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightInfographicCard extends StatelessWidget {
  const _InsightInfographicCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.tint,
    required this.bg,
  });

  final String emoji;
  final String title;
  final String body;
  final Color tint;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body.isNotEmpty
                      ? body
                      : '집계된 피드백을 바탕으로 AI 요약을 준비 중입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
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

class _PositiveCommentsCard extends StatelessWidget {
  const _PositiveCommentsCard({required this.comments});

  final List<String> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💬', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                '수강생 긍정 코멘트',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            Text(
              '아직 주관식 코멘트가 없습니다.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ...comments.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SoriTokens.border,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SoriTokens.border),
                  ),
                  child: Text(
                    '“$c”',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
