import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'director_customers_tab.dart';
import 'director_review_manage_page.dart';

/// 원장 GNB 「고객」— 고객 목록 + 케어 후기(리뷰) 세그먼트.
class DirectorCustomerHubPage extends StatefulWidget {
  const DirectorCustomerHubPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomerHubPage> createState() =>
      _DirectorCustomerHubPageState();
}

class _DirectorCustomerHubPageState extends State<DirectorCustomerHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  SoriStore get store => widget.store;

  int get _reviewBadge =>
      store.reviewRequestedPendingCount + store.reviewUnrepliedCount;

  @override
  void initState() {
    super.initState();
    final initial = (store.pendingCustomerHubSegment ?? 0).clamp(0, 1);
    store.pendingCustomerHubSegment = null;
    _tabs = TabController(length: 2, vsync: this, initialIndex: initial);
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    final pending = store.pendingCustomerHubSegment;
    if (pending != null) {
      store.pendingCustomerHubSegment = null;
      final i = pending.clamp(0, 1);
      if (_tabs.index != i) {
        _tabs.animateTo(i);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: SoriTokens.background,
            child: TabBar(
              controller: _tabs,
              tabs: [
                const Tab(text: '고객'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('리뷰'),
                      if (_reviewBadge > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.systemRed,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _reviewBadge > 99 ? '99+' : '$_reviewBadge',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: SoriTokens.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                DirectorCustomersTab(store: store),
                DirectorReviewManagePage(store: store),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
