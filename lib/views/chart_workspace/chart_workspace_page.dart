import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../add_customer_sheet.dart';
import 'chart_drawer_rail.dart';
import 'chart_file_document_strip.dart';
import 'chart_file_rail.dart';
import 'chart_index_palette.dart';
import 'chart_index_palette_sheet.dart';
import 'chart_new_visit_sheet.dart';
import 'chart_visit_rail.dart';
import 'chart_visit_sheet.dart';
import 'chart_workspace_state.dart';

/// Chart 탭: 서랍 → 신규/파일 → 문서 strip → 신규작성·Today/v → 기록지.
class ChartWorkspacePage extends StatefulWidget {
  const ChartWorkspacePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<ChartWorkspacePage> createState() => _ChartWorkspacePageState();
}

class _ChartWorkspacePageState extends State<ChartWorkspacePage> {
  final _drawers = const [kDefaultChartDrawer];
  late String _selectedDrawerId;
  String? _selectedFileId;
  String? _selectedCustomerId;
  String? _selectedVisitId;

  @override
  void initState() {
    super.initState();
    _selectedDrawerId = kDefaultChartDrawer.id;
    widget.store.addListener(_onStore);
    // 인덱스 색상 팔레트가 바뀌면(설정에서 편집·초기화·기기 저장값 로드
    // 완료) rail을 다시 그려 즉시 반영한다.
    ChartIndexPaletteStore.instance.addListener(_onPaletteChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    ChartIndexPaletteStore.instance.removeListener(_onPaletteChanged);
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    setState(() {
      if (_selectedCustomerId != null &&
          widget.store.findCustomer(_selectedCustomerId!) == null) {
        _selectedCustomerId = null;
        _selectedFileId = null;
        _selectedVisitId = null;
      }
      _ensureVisitSelection();
    });
  }

  void _onPaletteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openIndexColorSettings() =>
      showChartIndexPaletteSheet(context);

  List<FileRailItem> get _fileItems => buildFileRailItems(widget.store);

  Customer? get _selectedCustomer {
    final id = _selectedCustomerId;
    if (id == null) return null;
    return widget.store.findCustomer(id);
  }

  List<VisitRailItem> get _visitItems {
    final id = _selectedCustomerId;
    if (id == null) return const [];
    return buildVisitRailItems(widget.store, id);
  }

  VisitRailItem? get _selectedVisit {
    final items = _visitItems;
    if (items.isEmpty) return null;
    final id = _selectedVisitId;
    if (id == null) return items.first;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return items.first;
  }

  void _ensureVisitSelection() {
    final items = _visitItems;
    if (items.isEmpty) {
      _selectedVisitId = null;
      return;
    }
    if (_selectedVisitId == null ||
        !items.any((e) => e.id == _selectedVisitId)) {
      _selectedVisitId = items.first.id;
    }
  }

  void _selectDrawer(ChartDrawerViewModel drawer) {
    setState(() {
      _selectedDrawerId = drawer.id;
      _selectedFileId = null;
      _selectedCustomerId = null;
      _selectedVisitId = null;
    });
  }

  Future<void> _selectFile(FileRailItem item) async {
    if (item is NewCustomerFileRailItem) {
      await showAddCustomerSheet(
        context,
        store: widget.store,
        title: '새 고객 파일',
        submitLabel: '등록',
        openChartAfter: false,
      );
      if (mounted) setState(() {});
      return;
    }
    if (item is CustomerFileRailItem) {
      setState(() {
        _selectedFileId = item.id;
        _selectedCustomerId = item.customer.id;
        _selectedVisitId = null;
        _ensureVisitSelection();
      });
    }
  }

  void _selectVisit(VisitRailItem item) {
    setState(() => _selectedVisitId = item.id);
  }

  void _onChartSaved(CustomerChart chart) {
    setState(() {
      _selectedCustomerId = chart.customerId;
      _selectedFileId = 'file-${chart.customerId}';
      final today = todayChartForCustomer(widget.store, chart.customerId);
      if (today != null && today.id == chart.id) {
        _selectedVisitId = VisitRailItem.today(today).id;
      } else {
        _selectedVisitId = VisitRailItem.existing(chart).id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = _selectedCustomer;
    final visit = _selectedVisit;
    final visitItems = _visitItems;

    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textCharcoal,
                    ),
                  ),
                ),
                // 조용한 설정 진입점 — 버튼 나열이 아니라 아이콘 하나.
                IconButton(
                  key: const Key('chart-index-color-settings-entry'),
                  onPressed: _openIndexColorSettings,
                  tooltip: '인덱스 색상 설정',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.palette_outlined,
                    size: 20,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ChartDrawerRail(
            drawers: _drawers,
            selectedDrawerId: _selectedDrawerId,
            onSelected: _selectDrawer,
          ),
          const SizedBox(height: 8),
          ChartFileRail(
            items: _fileItems,
            selectedId: _selectedFileId,
            onSelected: _selectFile,
          ),
          if (customer != null) ...[
            const SizedBox(height: 8),
            ChartFileDocumentStrip(
              store: widget.store,
              customer: customer,
              fileNumber: fileDisplayNumberFor(widget.store, customer),
            ),
            const SizedBox(height: 4),
            ChartVisitRail(
              items: visitItems,
              selectedId: visit?.id,
              onSelected: _selectVisit,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: customer == null
                ? Padding(
                    // 화면 중앙을 채우는 안내 배너 금지 — 조용한 한 줄만.
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Text(
                      '서랍에서 파일을 선택하세요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary.withValues(alpha: 0.62),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _buildSheet(customer, visit),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(Customer customer, VisitRailItem? visit) {
    if (visit == null) {
      return const SizedBox(key: ValueKey('chart-empty'), height: 120);
    }
    if (visit.kind == VisitRailKind.newDraft) {
      return ChartNewVisitSheet(
        key: const ValueKey('visit-new'),
        store: widget.store,
        customer: customer,
        onSaved: _onChartSaved,
      );
    }
    final chart = visit.chart;
    if (chart == null) {
      return const SizedBox(key: ValueKey('chart-missing'));
    }
    return ChartVisitSheet(
      key: ValueKey(visit.id),
      store: widget.store,
      chart: chart,
      isToday: visit.kind == VisitRailKind.today,
      onSaved: _onChartSaved,
    );
  }
}
