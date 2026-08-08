import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'my_app.dart';

/// 원장용 어드민: 차트 + 방문 확인 + 고객 링크/QR/문자만.
/// 고객 심리 동선 버튼은 절대 표시하지 않는다.
class AdminChartPage extends StatefulWidget {
  const AdminChartPage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<AdminChartPage> createState() => _AdminChartPageState();
}

class _AdminChartPageState extends State<AdminChartPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  CustomerChart? get _chart => widget.store.latestChart(widget.customerId);

  Future<void> _confirmVisit() async {
    final chart = _chart;
    if (chart == null) return;

    widget.store.confirmVisit(chartId: chart.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('방문 확인 완료 · 고객 전용 웹 링크가 생성되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('고객 링크가 복사되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _sendSms({
    required Customer customer,
    required String url,
  }) async {
    final body =
        '${customer.name}님, 오늘 시술 진단 리포트와 후기 안내입니다.\n$url';
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customer.phone} 문자 초안을 복사했습니다. 메시지 앱에 붙여넣기 하세요.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final chart = _chart;

    if (customer == null || chart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('차트 관리')),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final token = chart.feedbackToken;
    final reviewUrl =
        token == null ? null : SoriStore.buildCustomerReviewUrl(token);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text('${customer.name} · 차트'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _AdminCustomerHeader(customer: customer, chart: chart),
          const SizedBox(height: 16),
          _AdminChartCard(
            chart: chart,
            onConfirmVisit: chart.visitChecked ? null : _confirmVisit,
          ),
          if (chart.hasFeedbackLine && reviewUrl != null) ...[
            const SizedBox(height: 20),
            _CustomerLinkPanel(
              url: reviewUrl,
              onCopy: () => _copyLink(reviewUrl),
              onSms: () => _sendSms(customer: customer, url: reviewUrl),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminCustomerHeader extends StatelessWidget {
  const _AdminCustomerHeader({
    required this.customer,
    required this.chart,
  });

  final Customer customer;
  final CustomerChart chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            child: Text(
              customer.name.characters.first,
              style: const TextStyle(
                color: MyApp.soriPurple,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.phone,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  chart.isFirstVisit
                      ? '첫 방문 고객'
                      : '회원권 ${chart.visitNumber}회차',
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _AdminChartCard extends StatelessWidget {
  const _AdminChartCard({
    required this.chart,
    required this.onConfirmVisit,
  });

  final CustomerChart chart;
  final VoidCallback? onConfirmVisit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '시술 차트',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MyApp.soriPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${chart.visitNumber}회차',
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BeforeAfterBox(
                  label: 'Before',
                  hasImage: chart.beforeImageUrl != null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BeforeAfterBox(
                  label: 'After',
                  hasImage: chart.afterImageUrl != null,
                ),
              ),
            ],
          ),
          if (chart.treatmentSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              chart.treatmentSummary,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          if (chart.directorInsight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '원장 인사이트: ${chart.directorInsight}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirmVisit,
              style: FilledButton.styleFrom(
                backgroundColor: chart.visitChecked
                    ? Colors.grey.shade400
                    : MyApp.soriPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                chart.visitChecked
                    ? '방문 확인 완료'
                    : '방문 확인 (visit_checked)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterBox extends StatelessWidget {
  const _BeforeAfterBox({
    required this.label,
    required this.hasImage,
  });

  final String label;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.image : Icons.image_outlined,
            color: MyApp.soriPurple.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerLinkPanel extends StatelessWidget {
  const _CustomerLinkPanel({
    required this.url,
    required this.onCopy,
    required this.onSms,
  });

  final String url;
  final VoidCallback onCopy;
  final VoidCallback onSms;

  @override
  Widget build(BuildContext context) {
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(url)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '고객 전용 웹 링크',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '카운터 QR 또는 문자로 전달하세요. 원장용 메뉴는 고객 화면에 노출되지 않습니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                qrUrl,
                width: 160,
                height: 160,
                errorBuilder: (_, _, _) => Container(
                  width: 160,
                  height: 160,
                  color: const Color(0xFFF3F1FB),
                  alignment: Alignment.center,
                  child: const Text(
                    'QR',
                    style: TextStyle(
                      color: MyApp.soriPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            url,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('링크 복사'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MyApp.soriPurple,
                    side: const BorderSide(color: MyApp.soriPurple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSms,
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('문자 발송'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MyApp.soriPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
