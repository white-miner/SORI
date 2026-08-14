import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import 'unified_home_feed_page.dart';

/// 레거시 원장 홈 — 통합 커뮤니티 피드로 위임.
@Deprecated('Use UnifiedHomeFeedPage via router')
class DirectorHomePage extends StatelessWidget {
  const DirectorHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return UnifiedHomeFeedPage(store: store);
  }
}
