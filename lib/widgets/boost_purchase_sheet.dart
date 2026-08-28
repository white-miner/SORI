import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import 'boost_bump_sheet.dart';

/// @deprecated Use [showBoostBumpSheet] — Split & Micro (075).
Future<bool> showBoostPurchaseSheet(
  BuildContext context, {
  required SoriStore store,
  required String chartId,
  String caseTitle = '',
}) {
  return showBoostBumpSheet(
    context,
    store: store,
    chartId: chartId,
    caseTitle: caseTitle,
  );
}
