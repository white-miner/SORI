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
    final pending = store.pendingCustomerHubSegment;
    if (pending == null) return;
    store.pendingCustomerHubSegment = null;
    final i = pending.clamp(0, 1);
    if (_tabs.index != i) {
      _tabs.animateTo(i);
    }
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
              labelColor: Colors.white,
              unselectedLabelColor: SoriTokens.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '고객'),
                Tab(text: '리뷰'),
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
