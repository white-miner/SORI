import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'ikea_review_composer_page.dart';
import 'my_app.dart';

/// 고객용 독립 모바일 웹 (`/#/review?token=...`).
/// 본인 확인 후 이케아형 AI 리뷰 동선으로 연결합니다.
class CustomerReviewPage extends StatefulWidget {
  const CustomerReviewPage({
    super.key,
    required this.store,
    required this.token,
  });

  final SoriStore store;
  final String token;

  @override
  State<CustomerReviewPage> createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  bool _verified = false;
  bool _verifyPromptShown = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVerified());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  CustomerChart? get _chart => widget.store.findChartByToken(widget.token);

  Customer? get _customer {
    final chart = _chart;
    if (chart == null) return null;
    return widget.store.findCustomer(chart.customerId);
  }

  Future<void> _ensureVerified() async {
    if (_verifyPromptShown || _verified) return;
    final customer = _customer;
    if (customer == null) return;
    _verifyPromptShown = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PhoneLast4Dialog(
        customerName: customer.name,
        onSubmit: (last4) => widget.store.verifyPhoneLast4(
          expectedPhone: customer.phone,
          inputLast4: last4,
        ),
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      setState(() => _verified = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호가 일치하지 않습니다. 다시 시도해 주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _verifyPromptShown = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) await _ensureVerified();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final customer = _customer;

    if (widget.token.trim().isEmpty || chart == null || customer == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: Text('유효하지 않은 고객 링크입니다')),
      );
    }

    if (!_verified) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(color: MyApp.soriPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IkeaReviewComposerPage(
        store: widget.store,
        chart: chart,
      ),
    );
  }
}

class _PhoneLast4Dialog extends StatefulWidget {
  const _PhoneLast4Dialog({
    required this.customerName,
    required this.onSubmit,
  });

  final String customerName;
  final bool Function(String last4) onSubmit;

  @override
  State<_PhoneLast4Dialog> createState() => _PhoneLast4DialogState();
}

class _PhoneLast4DialogState extends State<_PhoneLast4Dialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('본인 확인'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.customerName}님, 등록된 전화번호 뒷자리 4자리를 입력해 주세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '전화번호 뒷자리 4자리',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context, widget.onSubmit(_controller.text));
          },
          style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
