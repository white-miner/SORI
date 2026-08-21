import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seminar_feedback_report.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'seminar_feedback_detail_page.dart';

/// 원장 — AI 세미나 피드백 보관함 (인박스).
class SeminarFeedbackInboxPage extends StatefulWidget {
  const SeminarFeedbackInboxPage({super.key, required this.store});

  final SoriStore store;

  static Future<void> open(BuildContext context, {required SoriStore store}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeminarFeedbackInboxPage(store: store),
      ),
    );
  }

  @override
  State<SeminarFeedbackInboxPage> createState() =>
      _SeminarFeedbackInboxPageState();
}

class _SeminarFeedbackInboxPageState extends State<SeminarFeedbackInboxPage> {
  static final _dateFmt = DateFormat('yyyy.MM.dd', 'ko_KR');

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshSeminarFeedbackReports();
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

  @override
  Widget build(BuildContext context) {
    final reports = widget.store.seminarFeedbackReports;
    final loading = widget.store.seminarFeedbackReportsLoading;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '세미나 인사이트 보관함',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: loading && reports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '아직 집계된 세미나 피드백 리포트가 없습니다.\n'
                      '수강생이 인사이트 리뷰를 남기면 AI 요약이 생성됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.store.refreshSeminarFeedbackReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FeedbackReportCard(
                          report: report,
                          dateFmt: _dateFmt,
                          onTap: () => SeminarFeedbackDetailPage.open(
                            context,
                            store: widget.store,
                            reportId: report.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _FeedbackReportCard extends StatelessWidget {
  const _FeedbackReportCard({
    required this.report,
    required this.dateFmt,
    required this.onTap,
  });

  final SeminarFeedbackReport report;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = report.eventDate == null
        ? '일정 미기재'
        : dateFmt.format(report.eventDate!.toLocal());

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoriTokens.border),
            boxShadow: SoriTokens.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.classTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '수강 완료 ${report.completedEnrollmentCount}명',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (report.topInsightTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: report.topInsightTags.take(5).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SoriTokens.primarySoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          tag.startsWith('#') ? tag : '#$tag',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.primary,
                          ),
                        ),
                      );
                    }).toList(),
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
