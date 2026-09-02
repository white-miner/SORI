import 'package:flutter/material.dart';

import '../../models/program_sales.dart';
import '../../services/sori_store.dart';
import '../visit/home_visual_tokens.dart';
import 'widgets/program_confirm_sheet.dart';

Future<bool> acceptProgramQuoteWithCustomer({
  required BuildContext context,
  required SoriStore store,
  required ProgramQuote quote,
}) async {
  final decision = await showProgramConfirmSheet(
    context: context,
    store: store,
    quote: quote,
  );
  if (decision == null || !context.mounted) return false;
  final saved = await store.acceptProgramQuote(
    quote: quote,
    customerId: decision.customer.id,
    paymentStatus: decision.paymentStatus,
    paidKrw: decision.paidKrw,
    method: decision.method,
  );
  if (!context.mounted) return false;
  final visits = ProgramPricing.membershipVisits(
    quote.chosen.visitCount,
    ProgramPricing.stacked(quote.promotionIds, store.programPromotions),
  );
  final couponN = store.unusedCouponCount(saved.id);
  final payLabel = decision.paymentStatus.labelKo;
  final couponTail = couponN > 0 ? ' · 쿠폰 ${couponN}장' : '';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${saved.name} · ${quote.chosen.name} $visits회 등록 · $payLabel$couponTail',
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: HomeVisualTokens.programCloserFill,
    ),
  );
  return true;
}
