import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../add_customer_sheet.dart';
import '../customer_chart/customer_chart_page.dart';

/// Chart 탭 기본 수납: 서랍 A. B/C 분할·fixture·DB No 발급 없음.
class FileCabinetShell extends StatefulWidget {
  const FileCabinetShell({super.key, required this.store});

  final SoriStore store;

  @override
  State<FileCabinetShell> createState() => _FileCabinetShellState();
}

class _FileCabinetShellState extends State<FileCabinetShell> {
  final _search = TextEditingController();
  String _query = '';

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

  Future<void> _openFile(Customer customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerChartPage(
          store: widget.store,
          customerId: customer.id,
        ),
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

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chart',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '서랍 A',
                  key: Key('file-cabinet-drawer-a'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '파일 ${files.length}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('file-cabinet-search'),
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '파일 찾기',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: SoriTokens.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SoriTokens.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SoriTokens.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SoriTokens.brand),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('file-cabinet-add'),
                    onPressed: _addFile,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('새 고객 파일'),
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.brand,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SoriTokens.inputBorder),
          Expanded(
            child: files.isEmpty
                ? const Center(
                    child: Text(
                      '서랍 A에 아직 파일이 없습니다',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = files[index];
                      return _FileRow(
                        customer: c,
                        onTap: () => _openFile(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SoriTokens.inputBorder),
      ),
      child: InkWell(
        key: Key('file-cabinet-file-${customer.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              const SizedBox(
                width: 52,
                child: Text(
                  '번호\n준비 중',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textTertiary,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
