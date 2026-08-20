import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../models/seminar_enrollment.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/seminar_review_modal.dart';
import 'seminar_class_open_page.dart';
import 'seminar_feedback_inbox_page.dart';

/// B2B 세미나 센터 — 요청 인사이트 · 클래스 개설 · 수강/피드백 관리.
class SeminarManagementPage extends StatefulWidget {
  const SeminarManagementPage({super.key, required this.store});

  final SoriStore store;

  static Future<void> open(BuildContext context, {required SoriStore store}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SeminarManagementPage(store: store),
      ),
    );
  }

  @override
  State<SeminarManagementPage> createState() => _SeminarManagementPageState();
}

class _SeminarManagementPageState extends State<SeminarManagementPage> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshSeminarEducationInsight();
      store.refreshMySeminarEnrollments();
      store.refreshSeminarFeedbackReports();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  CustomerChart? _chartById(String? id) {
    final key = id?.trim() ?? '';
    if (key.isEmpty) return null;
    for (final c in store.charts) {
      if (c.id == key) return c;
    }
    return null;
  }

  String? _topRequestedCaseId() {
    final insight = store.seminarEducationInsight;
    if (insight == null || insight.requestsByCase.isEmpty) return null;
    final entries = insight.requestsByCase.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  List<MapEntry<String, int>> get _topCases {
    final insight = store.seminarEducationInsight;
    if (insight == null || insight.requestsByCase.isEmpty) {
      return const [];
    }
    final entries = insight.requestsByCase.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  void _openClass() {
    final topCase = _topRequestedCaseId();
    final chart = topCase == null ? null : _chartById(topCase);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeminarClassOpenPage(
          store: store,
          targetCaseId: topCase,
          initialTitle: chart?.careName ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDirector = store.session?.activeMode == UserRole.director;
    final insight = store.seminarEducationInsight;
    final totalRequests = insight?.totalRequests ?? 0;
    final topCases = _topCases;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          '세미나 센터',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (!isDirector)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
              child: Text(
                '세미나 요청·클래스 개설은 원장 모드에서 이용할 수 있어요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            )
          else ...[
            _InsightHeader(
              loading: store.seminarEducationLoading,
              totalRequests: totalRequests,
              soriCashBalance: store.shop.soriCashBalance,
              completedSeminars: store.shop.completedSeminarCount,
              onOpenClass: _openClass,
            ),
            if (topCases.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '요청이 많은 케이스',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...topCases.take(5).map((row) {
                final chart = _chartById(row.key);
                final title = chart?.serviceMenuLabel ?? '관리 케이스';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE8E4F8)),
                  ),
                  child: ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('세미나 요청 ${row.value}건'),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SeminarClassOpenPage(
                              store: store,
                              targetCaseId: row.key,
                              initialTitle: chart?.careName ?? '',
                            ),
                          ),
                        );
                      },
                      child: const Text('개설'),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: const Text('📊', style: TextStyle(fontSize: 22)),
                title: const Text(
                  'AI 세미나 피드백 보관함',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  store.seminarFeedbackReportsLoading
                      ? '리포트 불러오는 중…'
                      : '완료 리포트 ${store.seminarFeedbackReports.length}건',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => SeminarFeedbackInboxPage.open(
                  context,
                  store: store,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _HeldEnrollmentsSection(store: store),
        ],
      ),
    );
  }
}

class _InsightHeader extends StatelessWidget {
  const _InsightHeader({
    required this.loading,
    required this.totalRequests,
    required this.soriCashBalance,
    required this.completedSeminars,
    required this.onOpenClass,
  });

  final bool loading;
  final int totalRequests;
  final int soriCashBalance;
  final int completedSeminars;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    final cash = soriCashBalance.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: SoriTokens.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '교육 수요 인사이트',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '받은 세미나 요청 $totalRequests건',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '완료 세미나 $completedSeminars회 · SORI Cash $cash원',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenClass,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              '클래스 개설하기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldEnrollmentsSection extends StatelessWidget {
  const _HeldEnrollmentsSection({required this.store});

  final SoriStore store;

  Future<void> _complete(
    BuildContext context,
    SeminarEnrollment enrollment,
  ) async {
    final ok = await SeminarReviewModal.show(
      context,
      store: store,
      enrollmentId: enrollment.id,
      classId: enrollment.classId,
      classTitle: enrollment.classTitle,
    );
    if (!context.mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('세미나 수강이 완료 처리되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final held = store.mySeminarEnrollments.where((e) => e.isHeld).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '내 세미나 수강',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (store.mySeminarEnrollmentsLoading && held.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (held.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E8EC)),
            ),
            child: Text(
              '진행 중인 세미나 수강이 없습니다.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...held.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE6E8EC)),
              ),
              child: ListTile(
                title: Text(
                  e.classTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('에스크로 보류 · ${e.amount}원'),
                trailing: TextButton(
                  onPressed: () => _complete(context, e),
                  child: const Text('완료'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
