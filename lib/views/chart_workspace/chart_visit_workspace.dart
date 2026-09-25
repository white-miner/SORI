import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/chart_visit/chart_visit_flow_page.dart';
import '../../features/chart_visit/chart_visit_home_page.dart';
import '../../features/chart_visit/chart_visit_live.dart';
import '../../features/chart_visit/chart_visit_mock.dart';
import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/sori_nav.dart';
import '../smart_guide_camera_page.dart';

/// 위저드 CARE 단계와 같은 반응 선택지.
const List<String> _kReactionChoices = ['홍조', '따가움', '가려움', '열감', '부종', '통증'];

/// 오늘 방문 작성 데스크의 아코디언 섹션.
enum ChartVisitWorkspaceSection {
  safety('safety', '안전확인'),
  concern('concern', '고민·목표'),
  care('care', '시술 단계'),
  reaction('reaction', '반응'),
  photo('photo', '전후사진'),
  aftercare('aftercare', '애프터케어·홈케어·다음 관리');

  const ChartVisitWorkspaceSection(this.id, this.title);

  final String id;
  final String title;
}

/// 홈 CHART 탭 — 고객을 고르면 바로 열리는 "오늘 방문" 작성 데스크.
///
/// 데이터는 기존 CHART 위저드와 같은 [ChartVisitSession] / [ChartVisitGateway]
/// (`saveDraft` · `complete` · `resumeLatest` · `startFresh`)를 그대로 쓴다.
/// 새 저장 경로나 스키마는 없다. 고객만 열어 보고 나가면 행을 만들지 않고,
/// 처음 저장(임시저장·방문 완료·사진·편집 후 나가기)할 때 draft 행을 만든다.
class ChartVisitWorkspace extends StatefulWidget {
  const ChartVisitWorkspace({
    super.key,
    required this.store,
    required this.customer,
    required this.onCompleted,
  });

  final SoriStore store;
  final Customer customer;

  /// 방문 완료 저장이 끝난 뒤 호출된다. 빈 데스크로 돌아가는 건 부모 몫.
  final VoidCallback onCompleted;

  @override
  State<ChartVisitWorkspace> createState() => _ChartVisitWorkspaceState();
}

class _ChartVisitWorkspaceState extends State<ChartVisitWorkspace> {
  final ChartVisitPreviewStore _preview = ChartVisitPreviewStore.instance;

  ChartVisitSession? _session;
  ChartVisitGateway? _gateway;

  /// true 면 [_session] 의 id 가 실제 차트 draft 행이다.
  bool _persisted = false;
  bool _forceNewOnPersist = false;
  bool _resumed = false;
  bool _dirty = false;
  bool _completed = false;
  bool _busy = false;
  bool _photoBusy = false;
  bool _loading = true;
  String _error = '';

  bool _editingSafety = false;
  bool _openScoreDetails = false;
  final Set<String> _safetyOpen = {};
  final Set<ChartVisitWorkspaceSection> _open = {
    ChartVisitWorkspaceSection.safety,
  };

  /// 세션이 통째로 바뀌면 입력칸을 새 값으로 다시 만든다.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    // 편집 후 데스크로 돌아가면 조용히 draft 로 남긴다(위저드 자동저장과 같은 의도).
    // 트리 정리 중에는 스토어 알림을 보낼 수 없으므로 다음 마이크로태스크로 미룬다.
    if (_dirty && !_completed) {
      unawaited(Future<void>.microtask(_flushOnLeave));
    }
    super.dispose();
  }

  Customer get _customer =>
      widget.store.findCustomer(widget.customer.id) ?? widget.customer;

  // ---------------------------------------------------------------------------
  // 세션 준비 · 저장
  // ---------------------------------------------------------------------------

  Future<void> _bootstrap() async {
    if (!mounted) return;
    bindChartVisitRoute(widget.store, widget.customer.id);
    final gate = _preview.gateway;
    if (gate == null || _preview.liveCustomerId != widget.customer.id) {
      setState(() {
        _loading = false;
        _error = _preview.liveNotice.isNotEmpty
            ? _preview.liveNotice
            : '고객 차트를 열 수 없습니다';
      });
      return;
    }
    _gateway = gate;
    try {
      final active = _preview.active;
      if (active != null) {
        _adopt(active, persisted: true, resumed: true);
        return;
      }
      final drafts = _sortedDrafts();
      ChartVisitDraftRef? today;
      for (final draft in drafts) {
        if (_isToday(draft)) {
          today = draft;
          break;
        }
      }
      if (today != null) {
        await _resume(gate, today);
        return;
      }
      if (drafts.isNotEmpty) {
        final choice = await _askDraftChoice();
        if (!mounted) return;
        if (choice == 'resume') {
          await _resume(gate, drafts.first);
          return;
        }
        _forceNewOnPersist = true;
      }
      _adopt(_pendingSession(), persisted: false, resumed: false);
    } catch (e) {
      debugPrint('ChartVisitWorkspace bootstrap failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '방문 기록을 불러오지 못했습니다';
      });
    }
  }

  Future<void> _resume(ChartVisitGateway gate, ChartVisitDraftRef draft) async {
    final session = await gate.resumeLatest(draft);
    if (!mounted) return;
    _preview.active = session;
    _preview.touch();
    _adopt(session, persisted: true, resumed: true);
  }

  void _adopt(
    ChartVisitSession session, {
    required bool persisted,
    required bool resumed,
  }) {
    if (!mounted) return;
    setState(() {
      _session = session;
      _persisted = persisted;
      _resumed = resumed;
      _loading = false;
      _error = '';
      _safetyOpen.clear();
      _generation++;
    });
  }

  List<ChartVisitDraftRef> _sortedDrafts() {
    int visitNo(ChartVisitDraftRef d) =>
        widget.store.findChartById(d.chartId)?.visitNumber ?? 0;
    return List<ChartVisitDraftRef>.of(_preview.drafts)
      ..sort((a, b) => visitNo(b).compareTo(visitNo(a)));
  }

  bool _isToday(ChartVisitDraftRef draft) {
    final day = draft.record.visitDate ??
        widget.store.findChartById(draft.chartId)?.createdAt;
    if (day == null) return false;
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Future<String?> _askDraftChoice() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('chart-visit-workspace-draft-choice'),
          title: const Text('작성 중인 방문이 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'resume'),
              child: const Text('이어서 작성'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'fresh'),
              child: const Text('새 방문 시작'),
            ),
          ],
        );
      },
    );
  }

  /// 아직 행이 없는 오늘 방문. `ChartVisitLiveGateway.startFresh` 의 새 세션과 같은 초기값.
  ChartVisitSession _pendingSession() {
    final customer = _customer;
    final session = ChartVisitSession.fresh(
      id: '',
      startedAt: DateTime.now(),
      safety: safetyFromCustomer(customer),
    );
    session.skinTraitHint = customer.skinTrait.trim();
    return session;
  }

  /// 처음 저장할 때만 기존 게이트웨이로 draft 행을 만든다.
  Future<ChartVisitSession> _ensurePersisted() async {
    final session = _session!;
    final gate = _gateway!;
    if (_persisted) return session;
    final created = await gate.startFresh(forceNew: _forceNewOnPersist);
    final merged = ChartVisitSession.fromRecord(
      id: created.id,
      startedAt: created.startedAt,
      record: session.toRecord(flowStatus: 'draft'),
    );
    merged.skinTraitHint = session.skinTraitHint;
    merged.safetyDirty = session.safetyDirty;
    merged.consult = session.consult;
    merged.consultSeconds = session.consultSeconds;
    for (var i = 0; i < merged.steps.length && i < session.steps.length; i++) {
      merged.steps[i].expanded = session.steps[i].expanded;
      merged.steps[i].detailsOpen = session.steps[i].detailsOpen;
    }
    _session = merged;
    _persisted = true;
    _forceNewOnPersist = false;
    if (mounted && _preview.liveCustomerId == widget.customer.id) {
      _preview.active = merged;
      _preview.touch();
    }
    return merged;
  }

  Future<void> _flushOnLeave() async {
    final gate = _gateway;
    if (gate == null || _session == null) return;
    try {
      final session = await _ensurePersisted();
      await gate.saveDraft(session);
    } catch (e) {
      debugPrint('ChartVisitWorkspace leave-save failed: $e');
    }
  }

  void _touch() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  void _snack(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  Future<void> _saveDraft({bool quiet = false}) async {
    final gate = _gateway;
    if (_busy || gate == null || _session == null) return;
    setState(() => _busy = true);
    try {
      final session = await _ensurePersisted();
      await gate.saveDraft(session);
      _dirty = false;
      if (!quiet && mounted) _snack('임시저장했어요');
    } catch (e) {
      debugPrint('ChartVisitWorkspace saveDraft failed: $e');
      if (mounted) _snack('저장 실패');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final gate = _gateway;
    if (_busy || gate == null || _session == null) return;
    setState(() => _busy = true);
    try {
      final session = await _ensurePersisted();
      await gate.complete(session);
      if (_preview.active == session) _preview.active = null;
      _dirty = false;
      _completed = true;
    } catch (e) {
      debugPrint('ChartVisitWorkspace complete failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(
        '저장 실패',
        action: SnackBarAction(label: '다시 시도', onPressed: _complete),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onCompleted();
  }

  Future<void> _openHistory() async {
    if (_dirty) await _saveDraft(quiet: true);
    if (!mounted) return;
    await pushRootPage<void>(context, const ChartVisitHomePage());
    if (!mounted) return;
    // 이력 화면에서 위저드로 새 방문을 열었으면 그 세션을 이어서 보여준다.
    final active = _preview.active;
    if (active != null && !identical(active, _session)) {
      _adopt(active, persisted: true, resumed: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _shoot(GuideCameraKind kind) async {
    if (_photoBusy || _busy || _session == null) return;
    setState(() => _photoBusy = true);
    try {
      final session = await _ensurePersisted();
      if (!mounted) return;
      final chart = widget.store.findChartById(session.id);
      final result = await SmartGuideCameraPage.open(
        context,
        shopId: widget.store.shop.id,
        customerId: widget.customer.id,
        kind: kind,
        ghostBeforeUrl:
            kind == GuideCameraKind.after ? chart?.beforeImageUrl : null,
      );
      // 방문 세션 화면과 같게 대표 한 장만 차트에 반영한다.
      final shot = result?.primary;
      if (!mounted || shot == null) return;
      if (shot.kind == GuideCameraKind.before) {
        await widget.store.updateCustomerChartFields(
          chartId: session.id,
          beforeImageUrl: shot.url,
        );
      } else {
        await widget.store.patchChartAfterImage(
          chartId: session.id,
          afterImageUrl: shot.url,
        );
      }
      if (mounted) {
        _snack(
          shot.kind == GuideCameraKind.before
              ? 'Before 저장 완료'
              : 'After 저장 완료',
        );
      }
    } catch (e) {
      debugPrint('ChartVisitWorkspace photo failed: $e');
      if (mounted) _snack('사진 저장 실패');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 요약
  // ---------------------------------------------------------------------------

  static bool _isNone(String value) {
    final t = value.trim();
    return t.isEmpty || t == '없음' || t == '해당 없음';
  }

  String _safetySummary(ChartVisitSession s) {
    final flagged = <String>[
      if (!_isNone(s.safety.allergy)) '알레르기',
      if (!_isNone(s.safety.medication)) '복용약',
      if (!_isNone(s.safety.condition)) '질환',
      if (!_isNone(s.safety.pregnancy)) '임신/수유',
      if (!_isNone(s.safety.recentProcedure)) '최근 시술',
      if (!_isNone(s.safety.activeProduct)) '기능성 제품',
    ];
    if (flagged.isEmpty) return '특이사항 없음';
    return '확인 ${flagged.join(' · ')}';
  }

  String _concernSummary(ChartVisitSession s) {
    final parts = <String>[
      if (s.concerns.isNotEmpty) '고민 ${s.concerns.length}',
      if (s.goals.isNotEmpty) '목표 ${s.goals.length}',
    ];
    return parts.isEmpty ? '미입력' : parts.join(' · ');
  }

  String _careSummary(ChartVisitSession s) {
    if (s.steps.isEmpty) return '미입력';
    final written = s.steps.where((step) {
      return step.memo.trim().isNotEmpty ||
          step.product.trim().isNotEmpty ||
          step.device.trim().isNotEmpty ||
          step.intensity.trim().isNotEmpty ||
          step.minutes.trim().isNotEmpty ||
          step.area.trim().isNotEmpty;
    }).length;
    final base = '${s.steps.length}단계';
    return written > 0 ? '$base · 기록 $written' : base;
  }

  String _reactionSummary(ChartVisitSession s) {
    if (s.reactionNone || s.reactions.isEmpty) return '없음';
    return s.reactions.join(' · ');
  }

  (String?, String?) _photoUrls(ChartVisitSession s) {
    if (!_persisted) return (null, null);
    final chart = widget.store.findChartById(s.id);
    String? clean(String? url) {
      final t = url?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return (clean(chart?.beforeImageUrl), clean(chart?.afterImageUrl));
  }

  String _photoSummary(ChartVisitSession s) {
    final (before, after) = _photoUrls(s);
    final count = (before != null ? 1 : 0) + (after != null ? 1 : 0);
    return count == 0 ? '미입력' : '사진 $count장';
  }

  String _aftercareSummary(ChartVisitSession s) {
    final parts = <String>[
      if (s.aftercare.isNotEmpty) '안내 ${s.aftercare.length}',
      if (s.homeAm.trim().isNotEmpty || s.homePm.trim().isNotEmpty) '홈케어',
      if (s.nextTiming.trim().isNotEmpty) '다음 ${s.nextTiming.trim()}',
    ];
    return parts.isEmpty ? '미입력' : parts.join(' · ');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return ColoredBox(
      key: const Key('chart-visit-workspace'),
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(child: _body(session)),
          if (session != null) _bottomBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              _customer.name,
              key: const Key('chart-visit-workspace-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textCharcoal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _Pill(label: '오늘 방문', strong: true),
          if (_resumed) ...[
            const SizedBox(width: 6),
            const _Pill(
              key: Key('chart-visit-workspace-resumed'),
              label: '이어서 작성',
            ),
          ],
          const Spacer(),
          TextButton.icon(
            key: const Key('chart-visit-workspace-history'),
            onPressed: _openHistory,
            style: TextButton.styleFrom(
              foregroundColor: SoriTokens.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text(
              '이력',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ChartVisitSession? session) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: SoriTokens.textCharcoal,
          ),
        ),
      );
    }
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error.isEmpty ? '고객 차트를 열 수 없습니다' : _error,
          style: const TextStyle(fontSize: 14, color: SoriTokens.textSecondary),
        ),
      );
    }
    final sections = <Widget>[
      _section(
        ChartVisitWorkspaceSection.safety,
        summary: _safetySummary(session),
        filled: true,
        child: _safetyBody(session),
      ),
      _section(
        ChartVisitWorkspaceSection.concern,
        summary: _concernSummary(session),
        child: _concernBody(session),
      ),
      _section(
        ChartVisitWorkspaceSection.care,
        summary: _careSummary(session),
        child: _careBody(session),
      ),
      _section(
        ChartVisitWorkspaceSection.reaction,
        summary: _reactionSummary(session),
        filled: true,
        child: _reactionBody(session),
      ),
      _section(
        ChartVisitWorkspaceSection.photo,
        summary: _photoSummary(session),
        child: _photoBody(session),
      ),
      _section(
        ChartVisitWorkspaceSection.aftercare,
        summary: _aftercareSummary(session),
        child: _aftercareBody(session),
      ),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          key: const Key('chart-visit-workspace-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: KeyedSubtree(
            key: ValueKey<int>(_generation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  sections[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    ChartVisitWorkspaceSection section, {
    required String summary,
    required Widget child,
    bool filled = false,
  }) {
    final open = _open.contains(section);
    return _WorkspaceSection(
      id: section.id,
      index: section.index + 1,
      title: section.title,
      summary: summary,
      summaryFilled: filled || summary != '미입력',
      open: open,
      onToggle: () => setState(() {
        if (open) {
          _open.remove(section);
        } else {
          _open.add(section);
        }
      }),
      child: child,
    );
  }

  Widget _bottomBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SoriTokens.surface,
        border: Border(top: BorderSide(color: SoriTokens.inputBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('chart-visit-workspace-save-draft'),
                      onPressed: _busy ? null : () => _saveDraft(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SoriTokens.textCharcoal,
                        side: const BorderSide(color: SoriTokens.inputBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '임시저장',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('chart-visit-workspace-complete'),
                        onPressed: _busy ? null : _complete,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primary,
                          foregroundColor: SoriTokens.onPrimary,
                          disabledBackgroundColor: const Color(0xFF52525B),
                          disabledForegroundColor: SoriTokens.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '방문 완료',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }

  // --- 1. 안전확인 (위저드 INFO 와 같은 항목) ---------------------------------

  Widget _safetyBody(ChartVisitSession session) {
    final safety = session.safety;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fact('알레르기', safety.allergy),
        _fact('복용약', safety.medication),
        _fact('현재 질환', safety.condition),
        _fact('임신 / 수유', safety.pregnancy),
        _fact('최근 시술', safety.recentProcedure),
        _fact('기능성 제품', safety.activeProduct),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('chart-visit-workspace-safety-edit'),
            onPressed: () => setState(() => _editingSafety = !_editingSafety),
            style: TextButton.styleFrom(
              foregroundColor: SoriTokens.textCharcoal,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              _editingSafety ? '편집 닫기' : '변경사항 있음',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (_editingSafety) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '오늘 방문에 남고, 고객의 현재 안전 정보도 함께 바뀝니다. 지난 방문 기록은 바뀌지 않습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SoriTokens.textTertiary,
              ),
            ),
          ),
          _yesNo(
            'allergy',
            '알레르기',
            safety.allergy,
            (v) => _updateSafety(session, safety.copyWith(allergy: v)),
          ),
          _yesNo(
            'medication',
            '복용약',
            safety.medication,
            (v) => _updateSafety(session, safety.copyWith(medication: v)),
          ),
          _yesNo(
            'condition',
            '현재 질환',
            safety.condition,
            (v) => _updateSafety(session, safety.copyWith(condition: v)),
          ),
          _subLabel('임신 / 수유'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const ['해당 없음', '임신 중', '수유 중'])
                ChartVisitChoiceChip(
                  label: option,
                  selected: safety.pregnancy == option,
                  onTap: () => _updateSafety(
                    session,
                    safety.copyWith(pregnancy: option),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _yesNo(
            'recent_procedure',
            '최근 시술',
            safety.recentProcedure,
            (v) => _updateSafety(session, safety.copyWith(recentProcedure: v)),
          ),
          _subLabel('기능성 제품'),
          ChartVisitLineField(
            initial: safety.activeProduct,
            hint: '기능성 제품',
            onChanged: (v) =>
                _updateSafety(session, safety.copyWith(activeProduct: v)),
          ),
        ],
      ],
    );
  }

  void _updateSafety(ChartVisitSession session, SafetySnapshot next) {
    session.safety = next;
    session.safetyDirty = true;
    _touch();
  }

  Widget _fact(String label, String value) {
    final attention = !_isNone(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value.trim().isEmpty ? '없음' : value.trim(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: attention ? FontWeight.w800 : FontWeight.w600,
                color: SoriTokens.textCharcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yesNo(
    String key,
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final none = !_safetyOpen.contains(key) && _isNone(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subLabel(label),
          Row(
            children: [
              ChartVisitChoiceChip(
                label: '없음',
                selected: none,
                onTap: () {
                  _safetyOpen.remove(key);
                  onChanged('없음');
                },
              ),
              const SizedBox(width: 8),
              ChartVisitChoiceChip(
                label: '있음',
                selected: !none,
                onTap: () {
                  if (!none) return;
                  _safetyOpen.add(key);
                  onChanged('');
                },
              ),
            ],
          ),
          if (!none) ...[
            const SizedBox(height: 8),
            ChartVisitLineField(
              initial: _isNone(value) ? '' : value,
              hint: label,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. 고민·목표 ---------------------------------------------------------

  Widget _concernBody(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subLabel('고민 · 최대 3개'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in kConcernChoices)
              KeyedSubtree(
                key: Key('chart-visit-workspace-concern-$label'),
                child: ChartVisitChoiceChip(
                  label: label,
                  order: session.concerns.indexOf(label),
                  onTap: () {
                    final list = session.concerns;
                    if (list.contains(label)) {
                      list.remove(label);
                    } else if (list.length < 3) {
                      list.add(label);
                    }
                    _touch();
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _subLabel('관리 목표'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final goal in kCareGoals)
              KeyedSubtree(
                key: Key('chart-visit-workspace-goal-$goal'),
                child: ChartVisitChoiceChip(
                  label: goal,
                  selected: session.goals.contains(goal),
                  onTap: () {
                    if (session.goals.contains(goal)) {
                      session.goals.remove(goal);
                    } else {
                      session.goals.add(goal);
                    }
                    _touch();
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _subLabel('원하는 변화'),
        ChartVisitLineField(
          initial: session.desiredChange,
          hint: '한 문장으로',
          onChanged: (v) {
            session.desiredChange = v;
            _touch();
          },
        ),
        const SizedBox(height: 4),
        ChartVisitFoldRow(
          title: '상세 · 피부 점수',
          open: _openScoreDetails,
          onTap: () => setState(() => _openScoreDetails = !_openScoreDetails),
        ),
        if (_openScoreDetails) ...[
          _subLabel('언제부터'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in kSinceChoices)
                ChartVisitChoiceChip(
                  label: label,
                  selected: session.since == label,
                  onTap: () {
                    session.since = session.since == label ? '' : label;
                    _touch();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          _subLabel('신경 쓰이는 정도'),
          ChartVisitScoreDots(
            value: session.discomfort,
            onChanged: (v) {
              session.discomfort = session.discomfort == v ? 0 : v;
              _touch();
            },
          ),
          const SizedBox(height: 14),
          _subLabel('피부 점수 (선택)'),
          for (final axis in kSkinAxes) ...[
            ChartVisitAxisRow(
              label: axis.$2,
              value: session.scores[axis.$1] ?? 0,
              onChanged: (v) {
                session.scores[axis.$1] =
                    (session.scores[axis.$1] ?? 0) == v ? 0 : v;
                _touch();
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  // --- 3. 시술 단계 ---------------------------------------------------------

  Widget _careBody(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < session.steps.length; i++)
          KeyedSubtree(
            key: ValueKey<String>('chart-visit-workspace-step-$i'),
            child: ChartVisitCareStepTile(
              index: i + 1,
              step: session.steps[i],
              onChanged: _touch,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('chart-visit-workspace-add-step'),
            onPressed: () {
              session.steps.add(CareStepDraft(title: '새 단계', expanded: true));
              _touch();
            },
            style: TextButton.styleFrom(
              foregroundColor: SoriTokens.textCharcoal,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              '단계 추가',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. 반응 ---------------------------------------------------------------

  Widget _reactionBody(ChartVisitSession session) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChartVisitChoiceChip(
          label: '없음',
          selected: session.reactionNone || session.reactions.isEmpty,
          onTap: () {
            session.reactionNone = true;
            session.reactions.clear();
            _touch();
          },
        ),
        for (final label in _kReactionChoices)
          ChartVisitChoiceChip(
            label: label,
            selected: session.reactions.contains(label),
            onTap: () {
              session.reactionNone = false;
              if (session.reactions.contains(label)) {
                session.reactions.remove(label);
              } else {
                session.reactions.add(label);
              }
              if (session.reactions.isEmpty) session.reactionNone = true;
              _touch();
            },
          ),
      ],
    );
  }

  // --- 5. 전후사진 ------------------------------------------------------------

  Widget _photoBody(ChartVisitSession session) {
    final (before, after) = _photoUrls(session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PhotoSlot(
                key: const Key('chart-visit-workspace-photo-before'),
                label: 'Before',
                url: before,
                busy: _photoBusy,
                onTap: () => _shoot(GuideCameraKind.before),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PhotoSlot(
                key: const Key('chart-visit-workspace-photo-after'),
                label: 'After',
                url: after,
                busy: _photoBusy,
                onTap: () => _shoot(GuideCameraKind.after),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '촬영하면 오늘 방문 차트에 바로 저장됩니다.',
          style: TextStyle(fontSize: 12, color: SoriTokens.textTertiary),
        ),
      ],
    );
  }

  // --- 6. 애프터케어 · 홈케어 · 다음 관리 ---------------------------------------

  Widget _aftercareBody(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subLabel('관리 후 안내'),
        for (final item in kAftercare)
          InkWell(
            onTap: () {
              if (session.aftercare.contains(item)) {
                session.aftercare.remove(item);
              } else {
                session.aftercare.add(item);
              }
              _touch();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    session.aftercare.contains(item)
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: session.aftercare.contains(item)
                        ? SoriTokens.textCharcoal
                        : SoriTokens.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SoriTokens.textCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        _subLabel('홈케어'),
        ChartVisitLineField(
          initial: session.homeAm,
          hint: '아침 (AM)',
          onChanged: (v) {
            session.homeAm = v;
            _touch();
          },
        ),
        const SizedBox(height: 8),
        ChartVisitLineField(
          initial: session.homePm,
          hint: '저녁 (PM)',
          onChanged: (v) {
            session.homePm = v;
            _touch();
          },
        ),
        const SizedBox(height: 12),
        _subLabel('다음 관리'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final timing in kNextTimings)
              ChartVisitChoiceChip(
                label: timing,
                selected: session.nextTiming == timing,
                onTap: () {
                  session.nextTiming =
                      session.nextTiming == timing ? '' : timing;
                  _touch();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        ChartVisitLineField(
          initial: session.nextNote,
          hint: '다음에 할 관리',
          onChanged: (v) {
            session.nextNote = v;
            _touch();
          },
        ),
      ],
    );
  }

  Widget _subLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: SoriTokens.textSecondary,
        ),
      ),
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.id,
    required this.index,
    required this.title,
    required this.summary,
    required this.summaryFilled,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final String id;
  final int index;
  final String title;
  final String summary;
  final bool summaryFilled;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('chart-visit-section-$id'),
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('chart-visit-section-$id-header'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textCharcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          key: Key('chart-visit-section-$id-summary'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: summaryFilled
                                ? SoriTokens.textSecondary
                                : SoriTokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: SoriTokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              key: Key('chart-visit-section-$id-body'),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SoriTokens.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: child,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? SoriTokens.surface : const Color(0xFFE9ECF1),
        borderRadius: BorderRadius.circular(999),
        border: strong ? Border.all(color: SoriTokens.inputBorder) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strong ? SoriTokens.textCharcoal : SoriTokens.textSecondary,
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    super.key,
    required this.label,
    required this.url,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final String? url;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return AspectRatio(
      aspectRatio: 1.15,
      child: Material(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      size: 22,
                      color: SoriTokens.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$label 촬영',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textCharcoal,
                      ),
                    ),
                  ],
                ),
              if (image != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: _Pill(label: label, strong: true),
                ),
              if (busy)
                const ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SoriTokens.textCharcoal,
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
