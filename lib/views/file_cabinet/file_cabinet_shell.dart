import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../add_customer_sheet.dart';
import '../customer_chart/customer_chart_page.dart';

/// 캐비넷 작업공간 색. 앱 brand purple과 별개. local UI only.
enum CabinetFinish {
  ivory('아이보리', Color(0xFFD9CFC0), Color(0xFFF0E7DA), Color(0xFF2F2B26)),
  sage('세이지', Color(0xFF8FA68A), Color(0xFFB7C7B2), Color(0xFF1F2A22)),
  slate('슬레이트', Color(0xFF6E7888), Color(0xFF93A0AF), Color(0xFFF4F5F7)),
  charcoal('차콜', Color(0xFF2C2C32), Color(0xFF46464E), Color(0xFFF3F3F4)),
  burgundy('버건디', Color(0xFF5F2A32), Color(0xFF874650), Color(0xFFF8F1F2)),
  navy('네이비', Color(0xFF1E2F43), Color(0xFF334B66), Color(0xFFF1F4F8));

  const CabinetFinish(this.label, this.body, this.front, this.ink);

  final String label;
  final Color body;
  final Color front;
  final Color ink;

  Color get cavity => Color.alphaBlend(const Color(0x59000000), body);
}

/// Chart 탭 기본 수납: 서랍 A. 기본 OPEN. fixture/DB No 없음.
class FileCabinetShell extends StatefulWidget {
  const FileCabinetShell({super.key, required this.store});

  final SoriStore store;

  @override
  State<FileCabinetShell> createState() => _FileCabinetShellState();
}

class _FileCabinetShellState extends State<FileCabinetShell> {
  final _search = TextEditingController();
  String _query = '';
  var _open = true;
  var _finish = CabinetFinish.ivory;

  static const _move = Duration(milliseconds: 260);

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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '고객 파일 캐비넷',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textCharcoal,
              ),
            ),
            const SizedBox(height: 8),
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
                child: _CabinetObject(
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

class _CabinetObject extends StatelessWidget {
  const _CabinetObject({
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55000000), width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: open ? MainAxisSize.max : MainAxisSize.min,
        children: [
          AnimatedSlide(
            duration: _FileCabinetShellState._move,
            curve: Curves.easeOutCubic,
            offset: Offset(0, open ? 0.06 : 0),
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
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AnimatedOpacity(
                  duration: _FileCabinetShellState._move,
                  opacity: open ? 1 : 0,
                  child: _DrawerCavity(
                    finish: finish,
                    files: files,
                    onOpenFile: onOpenFile,
                    onAddFile: onAddFile,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: double.infinity, height: 8),
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
        color: Colors.transparent,
        child: InkWell(
          key: const Key('file-cabinet-drawer-a'),
          onTap: onToggle,
          onLongPress: onSettings,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: finish.front,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x44000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 1,
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  color: const Color(0x33000000),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F0E6),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFB7AFA2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                Semantics(
                  button: true,
                  label: open ? '서랍 A 닫기' : '서랍 A 열기',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onToggle,
                    onLongPress: onSettings,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 14),
                      child: Center(
                        child: Container(
                          key: const Key('file-cabinet-handle'),
                          width: 92,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3632),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF1A1714),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x44000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                              BoxShadow(
                                color: Color(0x33FFFFFF),
                                blurRadius: 1,
                                offset: Offset(0, -1),
                              ),
                            ],
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
      ),
    );
  }
}

class _DrawerCavity extends StatelessWidget {
  const _DrawerCavity({
    required this.finish,
    required this.files,
    required this.onOpenFile,
    required this.onAddFile,
  });

  final CabinetFinish finish;
  final List<Customer> files;
  final ValueChanged<Customer> onOpenFile;
  final VoidCallback onAddFile;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: _FileCabinetShellState._move,
      opacity: 1,
      child: DecoratedBox(
        key: const Key('file-cabinet-cavity'),
        decoration: BoxDecoration(
          color: finish.cavity,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66000000)),
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
                          color: finish.ink.withValues(alpha: 0.72),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                      itemCount: files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
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
    return Material(
      color: const Color(0xFFF8F5EE),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: Key('file-cabinet-file-${customer.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFD2C8B8)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4DACB),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(3),
                    ),
                    border: Border(right: BorderSide(color: Color(0xFFC9BCA8))),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                        const SizedBox(height: 2),
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
                ),
              ],
            ),
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('file-cabinet-add'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: ink),
              const SizedBox(width: 6),
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
