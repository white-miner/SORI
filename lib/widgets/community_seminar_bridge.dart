import 'package:flutter/material.dart';

import '../models/seminar_class.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../views/seminar_class_detail_page.dart';

/// 작성자 세미나 브릿지 — 개설 세미나가 있을 때만 노출.
class CommunitySeminarBridge extends StatefulWidget {
  const CommunitySeminarBridge({
    super.key,
    required this.store,
    required this.shopId,
    this.compactLabel,
  });

  final SoriStore store;
  final String shopId;

  /// null이면 기본 '이 원장님의 개설 세미나 보기'
  final String? compactLabel;

  @override
  State<CommunitySeminarBridge> createState() => _CommunitySeminarBridgeState();
}

class _CommunitySeminarBridgeState extends State<CommunitySeminarBridge> {
  List<SeminarClass>? _classes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommunitySeminarBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _load();
  }

  Future<void> _load() async {
    final id = widget.shopId.trim();
    if (id.isEmpty) return;
    // Same shop — reuse store cache when possible.
    if (id == widget.store.shop.id && widget.store.seminarClasses.isNotEmpty) {
      setState(() => _classes = List.from(widget.store.seminarClasses));
      return;
    }
    setState(() => _loading = true);
    try {
      final list =
          await widget.store.loadSeminarClassesForShop(id);
      if (!mounted) return;
      setState(() {
        _classes = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _classes = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openSheet() async {
    final classes = _classes ?? const <SeminarClass>[];
    if (classes.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + soriSheetBottomPadding(ctx),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '이 원장님의 세미나',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...classes.take(8).map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.school_outlined,
                    color: SoriTokens.primary,
                  ),
                  title: Text(
                    c.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '정원 ${c.currentEnrollment}/${c.maxCapacity}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    SeminarClassDetailPage.open(
                      context,
                      store: widget.store,
                      classId: c.id,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final classes = _classes;
    if (classes == null || classes.isEmpty) return const SizedBox.shrink();

    final button = OutlinedButton.icon(
      onPressed: _openSheet,
      icon: const Icon(Icons.school_outlined, size: 18),
      label: Text(widget.compactLabel ?? '이 원장님의 개설 세미나 보기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: SoriTokens.textTertiary,
        side: BorderSide(
          color: SoriTokens.primary.withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
    );

    if (widget.compactLabel != null) return button;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: button,
    );
  }
}
