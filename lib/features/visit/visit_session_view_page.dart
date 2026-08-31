import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../operation/widgets/care_timer_widget.dart';

/// PO v4.5 — session detail: flip clock + 3-button care timer flow.
class VisitSessionViewPage extends StatelessWidget {
  const VisitSessionViewPage({
    super.key,
    required this.store,
    required this.session,
    required this.onConsultationStart,
    required this.onOpenChart,
    required this.onCareStart,
    required this.onCareEnd,
    required this.onAfterPhoto,
    required this.onVisitEnd,
  });

  final SoriStore store;
  final VisitSession session;
  final VoidCallback onConsultationStart;
  final VoidCallback onOpenChart;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;
  final VoidCallback onAfterPhoto;
  final Future<void> Function() onVisitEnd;

  @override
  Widget build(BuildContext context) {
    final customer = store.findCustomer(session.customerId);
    final name = customer?.name ?? session.customerName;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        elevation: 0,
        title: Text(
          name,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          CareTimerWidget(
            store: store,
            session: session,
            onConsultationStart: onConsultationStart,
            onOpenChart: onOpenChart,
            onCareStart: onCareStart,
            onCareEnd: onCareEnd,
            onAfterPhoto: onAfterPhoto,
            onVisitEnd: () async {
              await onVisitEnd();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
