import 'package:flutter/material.dart';

import '../../models/program_sales.dart';
import '../../services/sori_store.dart';
import '../visit/home_visual_tokens.dart';
import '../visit/visit_customer_picker_sheet.dart';

Future<void> acceptProgramQuoteWithCustomer({
  required BuildContext context,
  required SoriStore store,
  required ProgramQuote quote,
}) async {
  final customer = await showVisitCustomerPickerSheet(context, store: store);
  if (customer == null || !context.mounted) return;
  final saved = await store.acceptProgramQuote(
    quote: quote,
    customerId: customer.id,
  );
  if (!context.mounted) return;
  final visits = ProgramPricing.membershipVisits(
    quote.chosen.visitCount,
    ProgramPricing.stacked(quote.promotionIds, store.programPromotions),
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${saved.name} · ${quote.chosen.name} $visits회 등록'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: HomeVisualTokens.programCloserFill,
    ),
  );
}
