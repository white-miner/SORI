import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import 'admin_chart_page.dart';
import 'app_shell_page.dart';
import 'my_app.dart';

/// 원장 홈 — 카카오톡 친구 탭 스타일 샵 카드 + 고객 리스트.
class DirectorHomePage extends StatefulWidget {
  const DirectorHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorHomePage> createState() => _DirectorHomePageState();
}

class _DirectorHomePageState extends State<DirectorHomePage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Customer> get _filtered => widget.store.searchCustomers(_query);

  Future<void> _addQuickCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('고객 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (ok == true &&
        name.text.trim().isNotEmpty &&
        SoriStore.normalizePhone(phone.text).length >= 10) {
      widget.store.addCustomer(
        Customer(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          shopId: widget.store.shop.id,
          name: name.text.trim(),
          phone: phone.text.trim(),
          lastTreatmentDate: DateTime.now(),
          treatmentType: '상담',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('고객이 추가되었습니다'),
            backgroundColor: MyApp.soriPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final session = store.session!;
    final customers = _filtered;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: ModeProfileHeader(
            store: store,
            title: store.shop.name,
            subtitle: '${session.name} 원장 · ${store.shop.phone ?? ''}',
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (session.showFirstChartTutorial)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _TutorialCard(
                      onStart: () async {
                        store.dismissFirstChartTutorial();
                        if (customers.isEmpty) {
                          await _addQuickCustomer();
                        }
                        final list = store.searchCustomers(_query);
                        if (list.isNotEmpty && context.mounted) {
                          await openChartWriterForCustomer(
                            context,
                            store: store,
                            customer: list.first,
                          );
                        }
                      },
                      onDismiss: store.dismissFirstChartTutorial,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: '이름 또는 전화번호 검색',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        '고객 ${customers.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addQuickCustomer,
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('추가'),
                        style: TextButton.styleFrom(foregroundColor: MyApp.soriPurple),
                      ),
                    ],
                  ),
                ),
              ),
              if (customers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? '아직 등록된 고객이 없어요' : '검색 결과가 없습니다',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final chart = store.latestChart(customer.id);
                    return Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminChartPage(
                                store: store,
                                customerId: customer.id,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => openChartWriterForCustomer(
                          context,
                          store: store,
                          customer: customer,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    MyApp.soriPurple.withValues(alpha: 0.12),
                                child: Text(
                                  customer.name.characters.first,
                                  style: const TextStyle(
                                    color: MyApp.soriPurple,
                                    fontWeight: FontWeight.bold,
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      customer.phone,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    chart == null
                                        ? '차트 없음'
                                        : '차트 ${chart.displayChartNo}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: MyApp.soriPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chart == null
                                        ? '-'
                                        : '${chart.visitNumber}회차',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.onStart, required this.onDismiss});

  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MyApp.soriPurple.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🎉 10초 만에 첫 고객 차트 작성하고\nQR/링크 생성해보기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MyApp.soriPurple,
              ),
              child: const Text('지금 체험하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
