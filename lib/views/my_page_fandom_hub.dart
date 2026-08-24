import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import 'community_following_pane.dart';

/// 팔로잉(구독) 허브 — 원장 찾기는 홈 탐색으로.
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

class _MyPageFandomHubPageState extends State<MyPageFandomHubPage> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMySubscriptions();
      store.refreshFollowingFeed(soft: true);
    });
  }

  void _openHomeExplore() {
    store.requestHomeExplore();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('팬덤 · 구독'),
        backgroundColor: SoriTokens.surface,
        actions: [
          TextButton(
            onPressed: _openHomeExplore,
            child: const Text(
              '원장 찾기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: CommunityFollowingPane(
        store: store,
        onOpenDiscover: _openHomeExplore,
      ),
    );
  }
}
