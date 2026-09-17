import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../services/sori_store.dart';
import 'customer_my_page_view.dart';
import 'director_my_page_view.dart';

/// 마이페이지 Facade — `activeMode`에 따라 원장/고객 뷰만 스위칭.
class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMembershipWallet();
      store.refreshMySeminarEnrollments();
      if (store.session?.activeMode == UserRole.director) {
        store.refreshSeminarEducationInsight();
        store.refreshSeminarFeedbackReports();
      }
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session;
    if (session == null) return const SizedBox.shrink();

    if (session.activeMode == UserRole.director) {
      return DirectorMyPageView(
        store: store,
        onSelectTab: widget.onSelectTab,
      );
    }
    return CustomerMyPageView(
      store: store,
      session: session,
    );
  }
}
