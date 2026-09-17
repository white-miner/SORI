import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import 'director_customers_tab.dart';
import 'director_review_manage_page.dart';

/// 원장 GNB 「고객」— CRM · 리뷰 (PRD v5.1: 상담 → 홈 승격).
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.visit.ensureLoaded();
      store.refreshDiscoverDirectors(soft: true);
    });
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
            child: SoriYoutubeTabBar(
              controller: _tabs,
              labels: const ['고객', '리뷰'],
              badges: [0, _reviewBadge],
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
