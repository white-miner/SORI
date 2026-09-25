import 'package:flutter/material.dart';

import '../../features/chart_visit/chart_visit_live.dart';
import '../../features/chart_visit/chart_visit_mock.dart';
import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'chart_empty_desk.dart';
import 'chart_index_palette.dart';
import 'chart_index_palette_sheet.dart';
import 'chart_visit_workspace.dart';

/// Chart 탭: 기본은 빈 데스크. 고객을 고르면 오늘 방문 작성 데스크
/// ([ChartVisitWorkspace])가 바로 열린다. 이력(ChartVisitHomePage)은
/// 작성 데스크 헤더의 '이력' 링크로 연다.
class ChartWorkspacePage extends StatefulWidget {
  const ChartWorkspacePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<ChartWorkspacePage> createState() => _ChartWorkspacePageState();
}

class _ChartWorkspacePageState extends State<ChartWorkspacePage> {
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    // 인덱스 색상 팔레트가 바뀌면(설정에서 편집·초기화·기기 저장값 로드
    // 완료) rail을 다시 그려 즉시 반영한다.
    ChartIndexPaletteStore.instance.addListener(_onPaletteChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    ChartIndexPaletteStore.instance.removeListener(_onPaletteChanged);
    ChartVisitPreviewStore.instance.detachIfLive();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    setState(() {
      if (_selectedCustomerId != null &&
          widget.store.findCustomer(_selectedCustomerId!) == null) {
        _selectedCustomerId = null;
      }
    });
  }

  void _onPaletteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openIndexColorSettings() =>
      showChartIndexPaletteSheet(context);

  Customer? get _selectedCustomer {
    final id = _selectedCustomerId;
    if (id == null) return null;
    return widget.store.findCustomer(id);
  }

  void _openCustomer(Customer customer) {
    setState(() {
      _selectedCustomerId = customer.id;
    });
    bindChartVisitRoute(widget.store, customer.id);
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomerId = null;
    });
    ChartVisitPreviewStore.instance.detachIfLive();
  }

  /// 방문 완료 저장 뒤 — 데스크를 비우고 알린다.
  void _onVisitCompleted(Customer customer) {
    _clearCustomerSelection();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${customer.name} 방문 기록을 저장했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _selectedCustomer;

    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
            child: Row(
              children: [
                if (customer != null)
                  IconButton(
                    key: const Key('chart-desk-back'),
                    onPressed: _clearCustomerSelection,
                    tooltip: '데스크로',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 22,
                      color: SoriTokens.textCharcoal,
                    ),
                  ),
                const Expanded(
                  child: Text(
                    'CHART',
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
          Expanded(
            child: customer != null
                ? ChartVisitWorkspace(
                    key: ValueKey<String>('chart-visit-workspace-${customer.id}'),
                    store: widget.store,
                    customer: customer,
                    onCompleted: () => _onVisitCompleted(customer),
                  )
                : ChartEmptyDesk(
                    store: widget.store,
                    onSelectCustomer: _openCustomer,
                  ),
          ),
        ],
      ),
    );
  }
}
