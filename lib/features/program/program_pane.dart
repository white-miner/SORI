import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../visit/home_visual_tokens.dart';
import 'program_edit_page.dart';
import 'widgets/program_board.dart';
import 'widgets/program_compare_page.dart';
import 'widgets/program_quote_page.dart';
import 'widgets/program_slot_replace_sheet.dart';

/// PRD v7.1 — 홈 2번 탭. 고객을 향하는 Presentation 모드가 기본이다.
class ProgramPane extends StatefulWidget {
  const ProgramPane({super.key, required this.store});

  final SoriStore store;

  @override
  State<ProgramPane> createState() => _ProgramPaneState();
}

class _ProgramPaneState extends State<ProgramPane>
    with AutomaticKeepAliveClientMixin {
  String? _expandedCategoryId;
  final List<String> _selectedIds = [];
  String? _frozenQuoteId;
  var _pickingPeer = false;

  @override
  bool get wantKeepAlive => true;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _toggleExpand(String categoryId) {
    setState(() {
      _expandedCategoryId =
          _expandedCategoryId == categoryId ? null : categoryId;
    });
  }

  Future<void> _toggleCheck(ProgramPackage package) async {
    if (_selectedIds.contains(package.id)) {
      setState(() => _selectedIds.remove(package.id));
      return;
    }
    if (_pickingPeer && _frozenQuoteId != null && _selectedIds.length == 1) {
      setState(() => _selectedIds.add(package.id));
      await _openFrozenCompare();
      return;
    }
    if (_selectedIds.length >= 2) {
      final drop = await showProgramSlotReplaceSheet(
        context: context,
        leftName: store.findProgramPackage(_selectedIds[0])?.name ?? '',
        rightName: store.findProgramPackage(_selectedIds[1])?.name ?? '',
        incomingName: package.name,
      );
      if (!mounted || drop == null) return;
      setState(() {
        _selectedIds[drop] = package.id;
      });
      return;
    }
    setState(() => _selectedIds.add(package.id));
  }

  bool get _crossCategory {
    if (_selectedIds.length < 2) return false;
    final a = store.findProgramPackage(_selectedIds[0]);
    final b = store.findProgramPackage(_selectedIds[1]);
    if (a == null || b == null) return false;
    return a.categoryId != b.categoryId;
  }

  Future<void> _openSelected() async {
    if (_pickingPeer) {
      if (_selectedIds.length == 2) {
        await _openFrozenCompare();
      }
      return;
    }
    if (_selectedIds.isEmpty) return;
    final left = store.findProgramPackage(_selectedIds[0]);
    if (left == null) return;
    final right = _selectedIds.length > 1
        ? store.findProgramPackage(_selectedIds[1])
        : null;
    if (_selectedIds.length > 1 && right == null) return;
    final quote = await store.presentProgramQuote(left: left, right: right);
    if (!mounted) return;
    await _pushConsult(quote);
  }

  Future<void> _openFrozenCompare() async {
    final quoteId = _frozenQuoteId;
    if (quoteId == null || _selectedIds.length != 2) return;
    final existing = store.findProgramQuote(quoteId);
    final left = store.findProgramPackage(_selectedIds[0]);
    final right = store.findProgramPackage(_selectedIds[1]);
    if (left == null || right == null) return;
    final quote = existing == null
        ? await store.presentProgramQuote(left: left, right: right)
        : await store.attachQuotePeer(quote: existing, right: right);
    if (!mounted) return;
    setState(() {
      _pickingPeer = false;
      _frozenQuoteId = null;
    });
    await _pushConsult(quote);
  }

  Future<void> _pushConsult(ProgramQuote quote) async {
    final result = await Navigator.of(context).push<ProgramConsultResult>(
      PageRouteBuilder<ProgramConsultResult>(
        transitionDuration: HomeVisualTokens.programExpandDuration,
        reverseTransitionDuration: HomeVisualTokens.programExpandDuration,
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: HomeVisualTokens.programExpandCurve,
            ),
            child: quote.isSingle
                ? ProgramQuotePage(store: store, quoteId: quote.id)
                : ProgramComparePage(store: store, quoteId: quote.id),
          );
        },
      ),
    );
    if (!mounted) return;
    if (result == ProgramConsultResult.addCompare) {
      setState(() {
        _frozenQuoteId = quote.id;
        _pickingPeer = true;
        if (_selectedIds.isEmpty) {
          _selectedIds.add(quote.chosen.id);
        }
        if (_selectedIds.length > 1) {
          _selectedIds.removeRange(1, _selectedIds.length);
        }
      });
      return;
    }
    if (result != ProgramConsultResult.accepted) {
      await store.abandonProgramQuote(quote.id);
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgramEditPage(store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final boards = store.programBoards;

    return ColoredBox(
      color: HomeVisualTokens.canvasBg,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HomeVisualTokens.sectionGutter,
                    12,
                    8,
                    8,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Program',
                          style: TextStyle(
                            fontSize: HomeVisualTokens.sectionLabelSize,
                            fontWeight: FontWeight.w700,
                            color: HomeVisualTokens.sectionLabelColor,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('program-edit-open'),
                        tooltip: '메뉴 보드 편집',
                        onPressed: _openEdit,
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: HomeVisualTokens.dateIconColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (boards.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyProgramBoard(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    HomeVisualTokens.sectionGutter,
                    0,
                    HomeVisualTokens.sectionGutter,
                    _selectedIds.isNotEmpty ? 88 : 24,
                  ),
                  sliver: SliverList.separated(
                    itemCount: boards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      return ProgramCategoryCard(
                        board: board,
                        expanded: board.category.id == _expandedCategoryId,
                        selectedIds: _selectedIds,
                        globalPromoCaption: store.globalPromoCaption,
                        onToggleExpand: () =>
                            _toggleExpand(board.category.id),
                        onToggleCheck: _toggleCheck,
                      );
                    },
                  ),
                ),
            ],
          ),
          if (_selectedIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _CompareDock(
                crossCategory: _crossCategory,
                leftName:
                    store.findProgramPackage(_selectedIds[0])?.name ?? '',
                rightName: _selectedIds.length > 1
                    ? (store.findProgramPackage(_selectedIds[1])?.name ?? '')
                    : '',
                compareEnabled: _selectedIds.length == 2,
                onClearLeft: () => setState(() => _selectedIds.removeAt(0)),
                onClearRight: () => setState(() {
                  if (_selectedIds.length > 1) _selectedIds.removeAt(1);
                }),
                pickingPeer: _pickingPeer,
                onProceed: _openSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyProgramBoard extends StatelessWidget {
  const _EmptyProgramBoard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_agenda_outlined,
            size: 34,
            color: HomeVisualTokens.dateIconColor,
          ),
          SizedBox(height: 12),
          Text(
            '아직 메뉴 보드가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeVisualTokens.dateTextColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '톱니에서 윤곽/웨딩 카테고리를 만드세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareDock extends StatelessWidget {
  const _CompareDock({
    required this.leftName,
    required this.rightName,
    required this.crossCategory,
    required this.compareEnabled,
    required this.onClearLeft,
    required this.onClearRight,
    required this.onProceed,
    this.pickingPeer = false,
  });

  final String leftName;
  final String rightName;
  final bool crossCategory;
  final bool compareEnabled;
  final bool pickingPeer;
  final VoidCallback onClearLeft;
  final VoidCallback onClearRight;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('program-compare-dock'),
      color: HomeVisualTokens.heroCardFill,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compareEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pickingPeer
                        ? '비교할 패키지를 하나 더 고르세요'
                        : '비교하려면 하나를 더 고르세요',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
              )
            else if (crossCategory)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '다른 카테고리입니다',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: HomeVisualTokens.programExpandDuration,
                    switchInCurve: HomeVisualTokens.programExpandCurve,
                    switchOutCurve: HomeVisualTokens.programExpandCurve,
                    child: _NameChip(
                      key: ValueKey('left-$leftName'),
                      name: leftName,
                      onClear: onClearLeft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: HomeVisualTokens.programExpandDuration,
                    switchInCurve: HomeVisualTokens.programExpandCurve,
                    switchOutCurve: HomeVisualTokens.programExpandCurve,
                    child: _NameChip(
                      key: ValueKey('right-$rightName'),
                      name: rightName.isEmpty ? '하나를 더 고르세요' : rightName,
                      onClear: rightName.isEmpty ? null : onClearRight,
                      placeholder: rightName.isEmpty,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: HomeVisualTokens.programDockH - 16,
                  child: FilledButton(
                    key: const Key('program-dock-proceed'),
                    onPressed: onProceed,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeVisualTokens.programCloserFill,
                      foregroundColor: HomeVisualTokens.programCloserOn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      compareEnabled ? '비교하기' : '이 구성으로 진행',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({
    super.key,
    required this.name,
    this.onClear,
    this.placeholder = false,
  });

  final String name;
  final VoidCallback? onClear;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: HomeVisualTokens.canvasBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: placeholder
                    ? HomeVisualTokens.dateIconColor
                    : HomeVisualTokens.dateTextColor,
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
