import 'package:flutter/material.dart';

import '../models/shop_assets.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Asset Tier 3 — Supporter 누적 Echo·상호작용 명세서.
Future<void> showSupporterInteractionStatementSheet(
  BuildContext context, {
  required SoriStore store,
  required String customerId,
  required String displayName,
  required int echoTotal,
  String? avatarUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SupporterInteractionStatementSheet(
      store: store,
      customerId: customerId,
      displayName: displayName,
      echoTotal: echoTotal,
      avatarUrl: avatarUrl,
    ),
  );
}

class _SupporterInteractionStatementSheet extends StatefulWidget {
  const _SupporterInteractionStatementSheet({
    required this.store,
    required this.customerId,
    required this.displayName,
    required this.echoTotal,
    this.avatarUrl,
  });

  final SoriStore store;
  final String customerId;
  final String displayName;
  final int echoTotal;
  final String? avatarUrl;

  @override
  State<_SupporterInteractionStatementSheet> createState() =>
      _SupporterInteractionStatementSheetState();
}

class _SupporterInteractionStatementSheetState
    extends State<_SupporterInteractionStatementSheet> {
  bool _loading = true;
  List<SupporterInteractionLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lines = await widget.store.loadSupporterInteractionStatement(
      widget.customerId,
    );
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    final avatar = widget.avatarUrl?.trim() ?? '';

    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage: avatar.isNotEmpty && !avatar.startsWith('data:')
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar.isEmpty || avatar.startsWith('data:')
                        ? Text(
                            widget.displayName.isNotEmpty
                                ? widget.displayName.characters.first
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.echoTotal}E total',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _lines.isEmpty
                      ? const Center(
                          child: Text(
                            'No interactions yet.',
                            style: TextStyle(
                              color: SoriTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final line = _lines[i];
                            final dt = line.occurredAt;
                            final date = dt == null
                                ? ''
                                : '${dt.month}/${dt.day} · '
                                    '${dt.hour.toString().padLeft(2, '0')}:'
                                    '${dt.minute.toString().padLeft(2, '0')}';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SoriTokens.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: SoriTokens.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          line.kindLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (line.echoAmount > 0)
                                        Text(
                                          '${line.echoAmount}E',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: SoriTokens.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (line.targetLabel.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      line.targetLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: SoriTokens.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (date.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: SoriTokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
