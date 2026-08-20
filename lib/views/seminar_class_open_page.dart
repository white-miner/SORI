import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import 'seminar_create_page.dart';

/// 호환 진입점 — [SeminarCreatePage]로 위임.
class SeminarClassOpenPage extends StatelessWidget {
  const SeminarClassOpenPage({
    super.key,
    required this.store,
    this.targetCaseId,
    this.initialTitle = '',
  });

  final SoriStore store;
  final String? targetCaseId;
  final String initialTitle;

  @override
  Widget build(BuildContext context) {
    return SeminarCreatePage(
      store: store,
      targetCaseId: targetCaseId,
      initialTitle: initialTitle,
    );
  }
}
