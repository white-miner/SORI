import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../add_customer_sheet.dart';
import '../customer_chart/customer_chart_page.dart';

/// 캐비넷 작업공간 색. 앱 brand purple과 별개. local UI only.
enum CabinetFinish {
  ivory('아이보리', Color(0xFFEDE6D9), Color(0xFFE0D3C2), Color(0xFF3F3A34)),
  sage('세이지', Color(0xFFB7C4B2), Color(0xFFA3B19E), Color(0xFF243028)),
  slate('슬레이트', Color(0xFF8B93A0), Color(0xFF7A8390), Color(0xFFF4F4F5)),
  charcoal('차콜', Color(0xFF3F3F46), Color(0xFF2F2F35), Color(0xFFF4F4F5)),
  burgundy('버건디', Color(0xFF7A3B44), Color(0xFF682F37), Color(0xFFF8F1F2)),
  navy('네이비', Color(0xFF2C3E56), Color(0xFF243448), Color(0xFFF2F5F8));

  const CabinetFinish(this.label, this.body, this.front, this.ink);

  final String label;
  final Color body;
  final Color front;
  final Color ink;
}

/// Chart 탭 기본 수납: 열고 닫는 서랍 A. fixture/DB No 없음.
class FileCabinetShell extends StatefulWidget {
  const FileCabinetShell({super.key, required this.store});

  final SoriStore store;

  @override
  State<FileCabinetShell> createState() => _FileCabinetShellState();
}

class _FileCabinetShellState extends State<FileCabinetShell> {
  final _search = TextEditingController();
  String _query = '';
  var _open = false;
  var _finish = CabinetFinish.ivory;

  static const _move = Duration(milliseconds: 240);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _search.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<Customer> get _files => widget.store.searchCustomers(_query);

  void _toggleDrawer() => setState(() => _open = !_open);

  Future<void> _openFile(Customer customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerChartPage(store: widget.store, customerId: customer.id),
      ),
    );
  }

  Future<void> _addFile() async {
    await showAddCustomerSheet(
      context,
      store: widget.store,
      title: '새 고객 파일',
      submitLabel: '등록',
      openChartAfter: false,
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SoriTokens.surface,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '캐비넷 설정',
                    key: Key('file-cabinet-settings-title'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '캐비넷 색상',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final finish in CabinetFinish.values)
                        _FinishSwatch(
                          finish: finish,
                          selected: _finish == finish,
                          onTap: () {
                            setState(() => _finish = finish);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    final count = widget.store.searchCustomers('').length;
    return ColoredBox(
      color: SoriTokens.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_open) ...[
              TextField(
                key: const Key('file-cabinet-search'),
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '파일 찾기',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: SoriTokens.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SoriTokens.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SoriTokens.inputBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: _CabinetBody(
                  finish: _finish,
                  open: _open,
                  fileCount: count,
                  files: files,
                  onToggle: _toggleDrawer,
                  onSettings: _openSettings,
                  onOpenFile: _openFile,
                  onAddFile: _addFile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CabinetBody extends StatelessWidget {
  const _CabinetBody({
    required this.finish,
    required this.open,
    required this.fileCount,
    required this.files,
    required this.onToggle,
    required this.onSettings,
    required this.onOpenFile,
    required this.onAddFile,
  });

  final CabinetFinish finish;
  final bool open;
  final int fileCount;
  final List<Customer> files;
  final VoidCallback onToggle;
  final VoidCallback onSettings;
  final ValueChanged<Customer> onOpenFile;
  final VoidCallback onAddFile;

  @override
  Widget build(BuildContext context) {
    final cabinet = AnimatedContainer(
      key: const Key('file-cabinet-body'),
      duration: _FileCabinetShellState._move,
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        color: finish.body,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33000000), width: 1),
      ),
      child: Column(
        mainAxisSize: open ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: _FileCabinetShellState._move,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.fromLTRB(10, open ? 16 : 0, 10, 0),
            child: _DrawerFront(
              finish: finish,
              open: open,
              fileCount: fileCount,
              onToggle: onToggle,
              onSettings: onSettings,
            ),
          ),
          if (open)
            Expanded(
              child: AnimatedOpacity(
                duration: _FileCabinetShellState._move,
                opacity: open ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        const Color(0x14000000),
                        finish.body,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: files.isEmpty
                              ? Center(
                                  child: Text(
                                    '파일이 없습니다',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: finish.ink.withValues(alpha: 0.7),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    4,
                                  ),
                                  itemCount: files.length,
                                  itemBuilder: (context, index) {
                                    final c = files[index];
                                    return _FileSpine(
                                      customer: c,
                                      ink: finish.ink,
                                      onTap: () => onOpenFile(c),
                                    );
                                  },
                                ),
                        ),
                        _AddSpine(ink: finish.ink, onTap: onAddFile),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: double.infinity, height: 18),
        ],
      ),
    );

    if (!open) return cabinet;
    return SizedBox.expand(child: cabinet);
  }
}

class _DrawerFront extends StatelessWidget {
  const _DrawerFront({
    required this.finish,
    required this.open,
    required this.fileCount,
    required this.onToggle,
    required this.onSettings,
  });

  final CabinetFinish finish;
  final bool open;
  final int fileCount;
  final VoidCallback onToggle;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? '서랍 A 닫기' : '서랍 A 열기',
      hint: '길게 누르면 캐비넷 설정',
      onTap: onToggle,
      onLongPress: onSettings,
      child: Material(
        color: finish.front,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const Key('file-cabinet-drawer-a'),
          onTap: onToggle,
          onLongPress: onSettings,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(height: 1, color: const Color(0x33000000)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFE6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFC4BDB0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '서랍 A',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2C2A26),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '파일 $fileCount개',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B6560),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: open ? '서랍 A 닫기' : '서랍 A 열기',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onToggle,
                  onLongPress: onSettings,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      key: const Key('file-cabinet-handle'),
                      width: 56,
                      height: 24,
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A4540),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSpine extends StatelessWidget {
  const _FileSpine({
    required this.customer,
    required this.ink,
    required this.onTap,
  });

  final Customer customer;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('file-cabinet-file-${customer.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 28,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.22),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    customer.phone,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ink.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSpine extends StatelessWidget {
  const _AddSpine({required this.ink, required this.onTap});

  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('file-cabinet-add'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: ink.withValues(alpha: 0.35)),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '새 고객 파일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishSwatch extends StatelessWidget {
  const _FinishSwatch({
    required this.finish,
    required this.selected,
    required this.onTap,
  });

  final CabinetFinish finish;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '${finish.label} 선택됨' : finish.label,
      child: InkWell(
        key: Key('file-cabinet-swatch-${finish.name}'),
        onTap: onTap,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 36,
                decoration: BoxDecoration(
                  color: finish.body,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? SoriTokens.textCharcoal
                        : const Color(0x33000000),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 18, color: finish.ink)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                finish.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
