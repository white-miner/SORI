import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'admin_chart_writer_page.dart';
import 'customer_link_popup.dart';
import 'my_app.dart';

/// 원장용: 전화번호 기준 차트 타임라인 + 작성/방문확인/링크만.
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

  List<CustomerChart> get _timeline =>
      widget.store.chartsForCustomer(widget.customerId);

  Future<void> _openWriter({CustomerChart? chart}) async {
    final customer = _customer;
    if (customer == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminChartWriterPage(
          store: widget.store,
          customer: customer,
          existingChart: chart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('차트 관리')),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final timeline = _timeline;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text('${customer.name} · 차트'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWriter(),
        backgroundColor: MyApp.soriPurple,
        icon: const Icon(Icons.note_add_outlined, color: Colors.white),
        label: const Text('새 차트 작성', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          _Header(customer: customer),
          const SizedBox(height: 16),
          const Text(
            '시술 차트 타임라인',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '전화번호 Unique Key: ${customer.phone}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text('아직 작성된 차트가 없습니다. 새 차트를 작성해 주세요.'),
            )
          else
            ...timeline.map((chart) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimelineCard(
                  chart: chart,
                  onEdit: chart.visitChecked
                      ? null
                      : () => _openWriter(chart: chart),
                  onShowLink: chart.hasFeedbackLine
                      ? () => showCustomerLinkPopup(
                            context,
                            chart: chart,
                            store: widget.store,
                          )
                      : null,
                  onConfirmOnly: chart.visitChecked
                      ? null
                      : () async {
                          final opened =
                              widget.store.confirmVisit(chartId: chart.id);
                          if (!context.mounted) return;
                          await showCustomerLinkPopup(
                            context,
                            chart: opened,
                            store: widget.store,
                          );
                        },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});

  final Customer customer;

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.chart,
    this.onEdit,
    this.onShowLink,
    this.onConfirmOnly,
  });

  final CustomerChart chart;
  final VoidCallback? onEdit;
  final VoidCallback? onShowLink;
  final VoidCallback? onConfirmOnly;

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MyApp.soriPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '차트 ${chart.displayChartNo} · ${chart.visitNumber}회차',
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (chart.visitChecked)
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade500),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            chart.careName.isNotEmpty ? chart.careName : chart.treatmentSummary,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (chart.directorInsight.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              chart.directorInsight,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onEdit != null)
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('차트 수정'),
                ),
              if (onConfirmOnly != null)
                FilledButton(
                  onPressed: onConfirmOnly,
                  style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
                  child: const Text('방문 확인'),
                ),
              if (onShowLink != null)
                OutlinedButton.icon(
                  onPressed: onShowLink,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('링크/QR'),
                ),
              if (onShowLink != null)
                TextButton(
                  onPressed: () async {
                    final url =
                        SoriStore.buildCustomerReviewUrl(chart.feedbackToken!);
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('링크 복사됨'),
                          backgroundColor: MyApp.soriPurple,
                        ),
                      );
                    }
                  },
                  child: const Text('링크 복사'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
