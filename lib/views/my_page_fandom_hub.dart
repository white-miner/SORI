import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import 'community_discover_pane.dart';
import 'community_following_pane.dart';

/// 팔로잉·탐색 — Community가 아닌 마이페이지 전용 허브.
class MyPageFandomHubPage extends StatefulWidget {
  const MyPageFandomHubPage({super.key, required this.store});

  final SoriStore store;

  static Future<void> open(BuildContext context, {required SoriStore store}) {
    return pushRootPage<void>(
      context,
      MyPageFandomHubPage(store: store),
    );
  }

  @override
  State<MyPageFandomHubPage> createState() => _MyPageFandomHubPageState();
}

class _MyPageFandomHubPageState extends State<MyPageFandomHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMySubscriptions();
      store.refreshDiscoverDirectors(soft: true);
      store.refreshFollowingFeed(soft: true);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('팬덤 · 구독'),
        backgroundColor: SoriTokens.surface,
        bottom: TabBar(
          controller: _tabs,
          labelColor: SoriTokens.primary,
          unselectedLabelColor: SoriTokens.textSecondary,
          indicatorColor: SoriTokens.primary,
          tabs: const [
            Tab(text: '팔로잉'),
            Tab(text: '탐색'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          CommunityFollowingPane(
            store: store,
            onOpenDiscover: () => _tabs.animateTo(1),
          ),
          CommunityDiscoverPane(store: store),
        ],
      ),
    );
  }
}
