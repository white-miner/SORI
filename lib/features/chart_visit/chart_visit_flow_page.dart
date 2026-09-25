import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/sori_router.dart';
import '../../theme/sori_tokens.dart';
import 'chart_visit_mock.dart';

const _steps = ['INFO', 'SKIN', 'CONSULT', 'CARE', 'RESULT'];

/// 집중 작성. 하단 탭 밖에 둔다. 샘플 세션만 수정한다.
class ChartVisitFlowPage extends StatefulWidget {
  const ChartVisitFlowPage({super.key});

  @override
  State<ChartVisitFlowPage> createState() => _ChartVisitFlowPageState();
}

class _ChartVisitFlowPageState extends State<ChartVisitFlowPage> {
  final _store = ChartVisitPreviewStore.instance;
  int _step = 0;
  bool _complete = false;
  bool _editingSafety = false;
  bool _editingSummary = false;
  bool _openGuide = false;
  bool _openHomeCare = false;
  bool _openNext = false;
  bool _editingNext = false;
  String _saveLabel = '저장됨';
  /// INFO 에서 '있음'을 눌러 입력칸을 연 항목(값이 아직 비어 있어도 열어 둔다).
  final Set<String> _safetyOpen = {};
  Timer? _saveTimer;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    if (_store.active == null) _store.startNewVisit();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _saveTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _flash() {
    _saveTimer?.cancel();
    setState(() => _saveLabel = '저장 중...');
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _persistDraft();
    });
  }

  Future<void> _finishVisit() async {
    final session = _store.active;
    final gate = _store.gateway;
    if (_store.live && gate != null && session != null) {
      try {
        await gate.complete(session);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('저장 실패'),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () {
                _finishVisit();
              },
            ),
          ),
        );
        return;
      }
      final customerId = _store.liveCustomerId;
      _store.active = null;
      if (!mounted) return;
      if (customerId != null && customerId.isNotEmpty) {
        context.go(AppPaths.customerDetail(customerId));
        return;
      }
    } else {
      _store.commitActiveVisit();
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.chartVisitPreview);
    }
  }

  Future<void> _persistDraft() async {
    final session = _store.active;
    final gate = _store.gateway;
    if (!_store.live || gate == null || session == null) {
      if (!mounted) return;
      setState(() => _saveLabel = '저장됨');
      _store.touch();
      return;
    }
    try {
      await gate.saveDraft(session);
      if (!mounted) return;
      setState(() => _saveLabel = '저장됨');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveLabel = '저장 실패');
    }
  }

  void _syncClock() {
    final recording = _store.active?.consult == ConsultPhase.recording;
    if (recording && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        final session = _store.active;
        if (session == null || session.consult != ConsultPhase.recording) {
          _syncClock();
          return;
        }
        session.consultSeconds += 1;
        _store.touch();
      });
    } else if (!recording) {
      _clock?.cancel();
      _clock = null;
    }
  }

  void _go(int next) {
    setState(() {
      _step = next.clamp(0, _steps.length - 1);
      _complete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _store.active;
    if (session == null) {
      return const Scaffold(
        backgroundColor: SoriTokens.background,
        body: SizedBox.shrink(),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      key: const Key('chart-visit-flow'),
      backgroundColor: SoriTokens.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (_complete) {
              setState(() => _complete = false);
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppPaths.chartVisitPreview);
            }
          },
        ),
        title: _complete
            ? const SizedBox.shrink()
            : Text(
                _store.customer.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
        actions: [
          if (!_complete)
            Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: _saveLabel == '저장 실패' ? _flash : null,
                child: Text(
                  _saveLabel,
                  key: const Key('chart-visit-save'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: SoriTokens.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_complete && !wide)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: _Progress(index: _step),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1040 : 520),
                child: wide && !_complete
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 280,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
                              children: [
                                Text(
                                  _store.customer.name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _store.customer.checkLines.join(' · '),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Color(0xFFB4534A),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _Progress(index: _step, vertical: true),
                              ],
                            ),
                          ),
                          Expanded(child: _stepScroll(session)),
                        ],
                      )
                    : _stepScroll(session),
              ),
            ),
          ),
          if (!_complete) _bottomBar(session) else _completeBar(),
        ],
      ),
    );
  }

  Widget _stepScroll(ChartVisitSession session) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (_complete) _completeBody(session) else _stepBody(session),
      ],
    );
  }

  Widget _stepBody(ChartVisitSession session) {
    return switch (_step) {
      0 => _info(session),
      1 => _skin(session),
      2 => _consult(session),
      3 => _care(session),
      _ => _result(session),
    };
  }

  Widget _bottomBar(ChartVisitSession session) {
    final awaitApply = _step == 2 &&
        session.consult == ConsultPhase.summarized &&
        !session.consultApplied;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
        child: Row(
          children: [
            TextButton(
              key: const Key('chart-visit-back'),
              onPressed: _step == 0 ? null : () => _go(_step - 1),
              child: const Text(
                '이전',
                style: TextStyle(fontSize: 16, color: SoriTokens.textSecondary),
              ),
            ),
            if (awaitApply)
              TextButton(
                key: const Key('chart-visit-next'),
                onPressed: () => _go(_step + 1),
                child: const Text(
                  '다음',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: SoriTokens.textTertiary,
                  ),
                ),
              ),
            const Spacer(),
            if (awaitApply)
              _DarkButton(
                key: const Key('chart-visit-apply'),
                label: '차트에 적용',
                compact: true,
                onPressed: () {
                  session.consultApplied = true;
                  _editingSummary = false;
                  _flash();
                },
              )
            else
              TextButton(
                key: const Key('chart-visit-next'),
                onPressed: () {
                  if (_step >= _steps.length - 1) {
                    setState(() => _complete = true);
                  } else {
                    _go(_step + 1);
                  }
                },
                child: Text(
                  _step >= _steps.length - 1 ? '완료' : '다음',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _completeBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: _DarkButton(
          key: const Key('chart-visit-to-home'),
          label: '고객 CHART',
          onPressed: () {
            _finishVisit();
          },
        ),
      ),
    );
  }

  Widget _info(ChartVisitSession session) {
    final safety = session.safety;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 확인',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _fact('알레르기', safety.allergy),
        _fact('복용약', safety.medication),
        _fact('현재 질환', safety.condition),
        _fact('임신 / 수유', safety.pregnancy),
        _fact('최근 시술', safety.recentProcedure),
        _fact('기능성 제품', _productLabel(safety.activeProduct)),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('chart-visit-safety-edit'),
          onPressed: () => setState(() => _editingSafety = !_editingSafety),
          child: Text(
            _editingSafety ? '편집 닫기' : '변경사항 있음',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (_editingSafety) ...[
          const Text(
            '오늘 방문에만 이 내용이 남습니다. 지난 방문 문장은 바뀌지 않습니다.',
            style: TextStyle(fontSize: 13, height: 1.4, color: SoriTokens.textTertiary),
          ),
          const SizedBox(height: 12),
          _yesNo(
            label: '알레르기',
            value: safety.allergy,
            onChanged: (v) => _store.updateActiveSafety(safety.copyWith(allergy: v)),
          ),
          _yesNo(
            label: '복용약',
            value: safety.medication,
            onChanged: (v) => _store.updateActiveSafety(safety.copyWith(medication: v)),
          ),
          _yesNo(
            label: '현재 질환',
            value: safety.condition,
            onChanged: (v) => _store.updateActiveSafety(safety.copyWith(condition: v)),
          ),
          _choice(
            label: '임신 / 수유',
            value: safety.pregnancy,
            options: const ['해당 없음', '임신 중', '수유 중'],
            onChanged: (v) => _store.updateActiveSafety(safety.copyWith(pregnancy: v)),
          ),
          _yesNo(
            label: '최근 시술',
            value: safety.recentProcedure,
            onChanged: (v) =>
                _store.updateActiveSafety(safety.copyWith(recentProcedure: v)),
          ),
          _line(
            label: '기능성 제품',
            value: safety.activeProduct,
            onChanged: (v) =>
                _store.updateActiveSafety(safety.copyWith(activeProduct: v)),
          ),
        ],
      ],
    );
  }

  String _productLabel(String raw) {
    final text = raw.trim();
    if (text.startsWith('레티놀')) return '레티놀';
    return text;
  }

  Widget _skin(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 피부에서\n가장 신경 쓰이는 건 무엇인가요?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
        ),
        const SizedBox(height: 8),
        const Text(
          '최대 3개까지 선택할 수 있어요.',
          style: TextStyle(fontSize: 14, color: SoriTokens.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in kConcernChoices)
              _ChoiceChip(
                label: label,
                order: session.concerns.indexOf(label),
                onTap: () {
                  final list = session.concerns;
                  if (list.contains(label)) {
                    list.remove(label);
                  } else if (list.length < 3) {
                    list.add(label);
                  }
                  _flash();
                },
              ),
          ],
        ),
        if (session.concerns.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            '언제부터 신경 쓰였나요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in kSinceChoices)
                _ChoiceChip(
                  label: label,
                  selected: session.since == label,
                  onTap: () {
                    session.since = label;
                    _flash();
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            '얼마나 신경 쓰이나요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _ScoreDots(
            value: session.discomfort,
            onChanged: (v) {
              session.discomfort = v;
              _flash();
            },
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text('거의 없음', style: TextStyle(fontSize: 12, color: SoriTokens.textTertiary)),
                Spacer(),
                Text('매우 신경 쓰임', style: TextStyle(fontSize: 12, color: SoriTokens.textTertiary)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '어떻게 달라졌으면 좋겠어요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _LineField(
            initial: session.desiredChange,
            hint: '한 문장으로',
            onChanged: (v) {
              session.desiredChange = v;
              _flash();
            },
          ),
          const SizedBox(height: 28),
          const Divider(height: 1, color: Color(0x14000000)),
          const SizedBox(height: 28),
          const Text(
            '관리사 피부 체크',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '현재 피부 상태를 기록합니다.',
            style: TextStyle(fontSize: 14, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final axis in kSkinAxes) ...[
            _AxisRow(
              label: axis.$2,
              value: session.scores[axis.$1] ?? 0,
              onChanged: (v) {
                session.scores[axis.$1] = v;
                _flash();
              },
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 12),
          const Text(
            '현재 피부를 남겨둘게요',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '오늘 관리 전 피부 상태를 기록합니다.',
            style: TextStyle(fontSize: 14, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 14),
          _PrimaryCapture(
            label: '정면 촬영',
            filled: session.beforeCaptured.contains('정면'),
            onTap: () => _toggleAngle(session.beforeCaptured, '정면'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SecondaryCapture(
                  label: '좌측',
                  filled: session.beforeCaptured.contains('좌측'),
                  onTap: () => _toggleAngle(session.beforeCaptured, '좌측'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryCapture(
                  label: '우측',
                  filled: session.beforeCaptured.contains('우측'),
                  onTap: () => _toggleAngle(session.beforeCaptured, '우측'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _toggleAngle(Set<String> captured, String angle) {
    if (captured.contains(angle)) {
      captured.remove(angle);
    } else {
      captured.add(angle);
    }
    _flash();
  }

  Widget _consult(ChartVisitSession session) {
    final phase = session.consult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Kicker('상담'),
        const SizedBox(height: 8),
        if (phase == ConsultPhase.idle) ...[
          const Text(
            '상담 전',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _DarkButton(
            key: const Key('chart-visit-consult-start'),
            label: '상담 시작',
            onPressed: () {
              session.consult = ConsultPhase.recording;
              _syncClock();
              _flash();
            },
          ),
        ] else if (phase == ConsultPhase.recording || phase == ConsultPhase.paused) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: phase == ConsultPhase.recording
                      ? const Color(0xFFE11D48)
                      : SoriTokens.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                phase == ConsultPhase.recording ? '상담 기록 중' : '일시정지',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatClock(session.consultSeconds),
            key: const Key('chart-visit-consult-clock'),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '목소리는 이 샘플에서 저장되지 않습니다.',
            style: TextStyle(fontSize: 13, color: SoriTokens.textTertiary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  session.consult = phase == ConsultPhase.recording
                      ? ConsultPhase.paused
                      : ConsultPhase.recording;
                  _syncClock();
                  _flash();
                },
                child: Text(
                  phase == ConsultPhase.recording ? '일시정지' : '다시 시작',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const Key('chart-visit-consult-end'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SoriTokens.textPrimary,
                  side: const BorderSide(color: SoriTokens.textPrimary, width: 1.4),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  session.consult = ConsultPhase.summarized;
                  session.consultApplied = false;
                  _syncClock();
                  _flash();
                },
                child: const Text(
                  '상담 종료',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ] else ...[
          const Text(
            '상담이 정리되었습니다',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            session.consultApplied
                ? '차트에 적용됨'
                : '아직 차트에 적용되지 않았습니다.',
            key: const Key('chart-visit-consult-status'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: session.consultApplied
                  ? SoriTokens.semanticGreen
                  : SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _summaryBlock('주요 고민', session.summaryConcerns, (v) {
            session.summaryConcerns = v;
            session.consultApplied = false;
            _flash();
          }),
          _summaryBlock('생활 / 홈케어', session.summaryLife, (v) {
            session.summaryLife = v;
            session.consultApplied = false;
            _flash();
          }),
          _summaryBlock('관리사 판단', session.summaryJudgement, (v) {
            session.summaryJudgement = v;
            session.consultApplied = false;
            _flash();
          }),
          _summaryBlock('고객이 원하는 변화', session.summaryWish, (v) {
            session.summaryWish = v;
            session.consultApplied = false;
            _flash();
          }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _editingSummary = !_editingSummary),
            child: Text(
              _editingSummary ? '수정 닫기' : '수정',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryBlock(String title, String body, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          if (_editingSummary)
            _LineField(initial: body, hint: title, maxLines: 3, onChanged: onChanged)
          else
            Text(
              body,
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
        ],
      ),
    );
  }

  Widget _care(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Kicker('오늘의 관리 목표'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final goal in kCareGoals)
              _ChoiceChip(
                label: goal,
                selected: session.goals.contains(goal),
                onTap: () {
                  if (session.goals.contains(goal)) {
                    session.goals.remove(goal);
                  } else {
                    session.goals.add(goal);
                  }
                  _flash();
                },
              ),
          ],
        ),
        const SizedBox(height: 32),
        const _Kicker('TODAY CARE'),
        const SizedBox(height: 8),
        for (var i = 0; i < session.steps.length; i++)
          _CareStepTile(
            index: i + 1,
            step: session.steps[i],
            onChanged: _flash,
          ),
        TextButton(
          onPressed: () {
            session.steps.add(CareStepDraft(title: '새 단계', expanded: true));
            _flash();
          },
          child: const Text('단계 추가', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        const _Kicker('관리 중 반응'),
        const SizedBox(height: 8),
        _ChoiceChip(
          label: '없음',
          selected: session.reactionNone,
          onTap: () {
            session.reactionNone = true;
            session.reactions.clear();
            _flash();
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in ['홍조', '따가움', '가려움', '열감', '부종', '통증'])
              _ChoiceChip(
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
                  _flash();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _result(ChartVisitSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘의 변화',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        const Text(
          '오늘 관리 후 피부를 남겨둘게요.',
          style: TextStyle(fontSize: 15, color: SoriTokens.textSecondary),
        ),
        const SizedBox(height: 12),
        _PrimaryCapture(
          label: '정면 촬영',
          filled: session.afterCaptured.contains('정면'),
          height: 112,
          onTap: () => _toggleAngle(session.afterCaptured, '정면'),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Before',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                'After',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _CompareWell(),
        const SizedBox(height: 8),
        for (final change in session.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${change.axis}   ${change.from} → ${change.to}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        TextButton(
          key: const Key('chart-visit-add-change'),
          onPressed: () => _addChange(session),
          child: const Text(
            '변화 추가',
            style: TextStyle(fontSize: 15, color: SoriTokens.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        _FoldRow(
          title: '관리 후 안내',
          open: _openGuide,
          onTap: () => setState(() => _openGuide = !_openGuide),
        ),
        if (_openGuide)
          for (final item in kAftercare)
            InkWell(
              onTap: () {
                if (session.aftercare.contains(item)) {
                  session.aftercare.remove(item);
                } else {
                  session.aftercare.add(item);
                }
                _flash();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      session.aftercare.contains(item)
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 22,
                      color: session.aftercare.contains(item)
                          ? SoriTokens.textPrimary
                          : SoriTokens.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 16, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ),
        _FoldRow(
          title: '홈케어',
          open: _openHomeCare,
          onTap: () => setState(() => _openHomeCare = !_openHomeCare),
        ),
        if (_openHomeCare) ...[
          const Text('AM', style: TextStyle(fontSize: 13, color: SoriTokens.textTertiary)),
          const SizedBox(height: 6),
          _LineField(
            initial: session.homeAm,
            hint: '아침',
            onChanged: (v) {
              session.homeAm = v;
              _flash();
            },
          ),
          const SizedBox(height: 12),
          const Text('PM', style: TextStyle(fontSize: 13, color: SoriTokens.textTertiary)),
          const SizedBox(height: 6),
          _LineField(
            initial: session.homePm,
            hint: '저녁',
            onChanged: (v) {
              session.homePm = v;
              _flash();
            },
          ),
        ],
        _FoldRow(
          title: '다음 관리',
          open: _openNext,
          onTap: () => setState(() => _openNext = !_openNext),
        ),
        if (_openNext) ...[
          Text(
            session.nextNote,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${session.nextTiming} 후',
            style: const TextStyle(fontSize: 16, color: SoriTokens.textSecondary),
          ),
          TextButton(
            onPressed: () => setState(() => _editingNext = !_editingNext),
            child: Text(_editingNext ? '수정 닫기' : '수정'),
          ),
          if (_editingNext) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final timing in kNextTimings)
                  _ChoiceChip(
                    label: timing,
                    selected: session.nextTiming == timing,
                    onTap: () {
                      session.nextTiming = timing;
                      _flash();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _LineField(
              initial: session.nextNote,
              hint: '다음에 할 관리',
              onChanged: (v) {
                session.nextNote = v;
                _flash();
              },
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _addChange(ChartVisitSession session) async {
    var axis = '홍조';
    var from = 3;
    var to = 2;
    final added = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SoriTokens.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '변화 추가',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in kSkinAxes)
                          _ChoiceChip(
                            label: item.$2,
                            selected: axis == item.$2,
                            onTap: () => setSheet(() => axis = item.$2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('이전'),
                    _ScoreDots(value: from, onChanged: (v) => setSheet(() => from = v)),
                    const SizedBox(height: 8),
                    const Text('이후'),
                    _ScoreDots(value: to, onChanged: (v) => setSheet(() => to = v)),
                    const SizedBox(height: 16),
                    _DarkButton(
                      label: '기록',
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (added == true) {
      session.changes.add(ScoreChange(axis: axis, from: from, to: to));
      _flash();
    }
  }

  Widget _completeBody(ChartVisitSession session) {
    return Column(
      key: const Key('chart-visit-complete'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _store.customer.name,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          formatVisitFull(session.startedAt),
          style: const TextStyle(fontSize: 16, color: SoriTokens.textSecondary),
        ),
        const SizedBox(height: 20),
        const _Kicker('오늘의 고민'),
        const SizedBox(height: 4),
        Text(
          session.concernLine.isEmpty ? '기록 없음' : session.concernLine,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const _Kicker('오늘의 관리'),
        const SizedBox(height: 4),
        Text(
          session.goalLine,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Before',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'After',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Expanded(child: _PhotoWell(label: '', height: 72)),
            SizedBox(width: 12),
            Expanded(child: _PhotoWell(label: '', height: 72)),
          ],
        ),
        const SizedBox(height: 14),
        for (final change in session.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${change.axis}   ${change.from} → ${change.to}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        const _Kicker('NEXT'),
        const SizedBox(height: 4),
        Text(
          '${session.nextTiming} 후',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          session.nextNote,
          style: const TextStyle(fontSize: 16, color: SoriTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: SoriTokens.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yesNo({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final none = !_safetyOpen.contains(label) &&
        (value.trim().isEmpty || value.trim() == '없음');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChoiceChip(
                label: '없음',
                selected: none,
                onTap: () {
                  _safetyOpen.remove(label);
                  onChanged('없음');
                  _flash();
                },
              ),
              const SizedBox(width: 8),
              _ChoiceChip(
                label: '있음',
                selected: !none,
                onTap: () {
                  if (none) {
                    _safetyOpen.add(label);
                    onChanged('');
                  }
                  _flash();
                },
              ),
            ],
          ),
          if (!none) ...[
            const SizedBox(height: 8),
            _LineField(
              initial: value,
              hint: label,
              onChanged: (v) {
                onChanged(v);
                _flash();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _ChoiceChip(
                  label: option,
                  selected: value == option,
                  onTap: () {
                    onChanged(option);
                    _flash();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _LineField(
          initial: value,
          hint: label,
          onChanged: (v) {
            onChanged(v);
            _flash();
          },
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index, this.vertical = false});

  final int index;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var i = 0; i < _steps.length; i++)
        Padding(
          padding: EdgeInsets.only(
            bottom: vertical ? 14 : 0,
            right: !vertical && i < _steps.length - 1 ? 20 : 0,
          ),
          child: Text(
            _steps[i],
            style: TextStyle(
              fontSize: i == index ? 15 : 13,
              fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.6,
              color: i == index ? SoriTokens.textPrimary : SoriTokens.textTertiary,
            ),
          ),
        ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (index + 1) / _steps.length,
            minHeight: 2,
            backgroundColor: const Color(0x14000000),
            color: SoriTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SoriTokens.textTertiary,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.order = -1,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final int order;

  @override
  Widget build(BuildContext context) {
    final on = selected || order >= 0;
    return Material(
      color: on ? SoriTokens.textPrimary : const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order >= 0) ...[
                  Text(
                    '${order + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : SoriTokens.textPrimary,
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

class _ScoreDots extends StatelessWidget {
  const _ScoreDots({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var n = 1; n <= 5; n++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: n == 1 ? 0 : 8),
              child: _ScoreDot(
                n: n,
                selected: value == n,
                onTap: () => onChanged(n),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoreDot extends StatelessWidget {
  const _ScoreDot({
    required this.n,
    required this.selected,
    required this.onTap,
  });

  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: selected ? SoriTokens.textPrimary : Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? SoriTokens.textPrimary : const Color(0xFFD4D4D8),
            width: 1.4,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF71717A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _ScoreDots(value: value, onChanged: onChanged)),
      ],
    );
  }
}

class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.label, this.height});

  final String label;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final well = Material(
      color: const Color(0xFFE7E2DC),
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: label.isEmpty
            ? const SizedBox.shrink()
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6560),
                ),
              ),
      ),
    );
    if (height != null) {
      return SizedBox(height: height, width: double.infinity, child: well);
    }
    return AspectRatio(aspectRatio: 0.8, child: well);
  }
}

class _CompareWell extends StatefulWidget {
  const _CompareWell();

  @override
  State<_CompareWell> createState() => _CompareWellState();
}

class _CompareWellState extends State<_CompareWell> {
  double _t = 0.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cut = constraints.maxWidth * _t;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFD9D3CC)),
                    ClipRect(
                      clipper: _LeftClipper(cut),
                      child: const ColoredBox(color: Color(0xFFE7E2DC)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Slider(
          value: _t,
          activeColor: SoriTokens.textPrimary,
          onChanged: (v) => setState(() => _t = v),
        ),
      ],
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.width);
  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper old) => old.width != width;
}

class _CareStepTile extends StatefulWidget {
  const _CareStepTile({
    required this.index,
    required this.step,
    required this.onChanged,
  });

  final int index;
  final CareStepDraft step;
  final VoidCallback onChanged;

  @override
  State<_CareStepTile> createState() => _CareStepTileState();
}

class _CareStepTileState extends State<_CareStepTile> {
  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final n = widget.index.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => step.expanded = !step.expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      n,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    step.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: SoriTokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (step.expanded) ...[
            const Text(
              '관리 내용 / 메모',
              style: TextStyle(fontSize: 13, color: SoriTokens.textTertiary),
            ),
            const SizedBox(height: 6),
            _mini('관리 내용', step.memo, (v) => step.memo = v),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => step.detailsOpen = !step.detailsOpen),
                child: Text(
                  step.detailsOpen ? '상세 기록 닫기' : '+ 상세 기록',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (step.detailsOpen) ...[
              _mini('제품', step.product, (v) => step.product = v),
              _mini('기기', step.device, (v) => step.device = v),
              _mini('강도', step.intensity, (v) => step.intensity = v),
              _mini('시간', step.minutes, (v) => step.minutes = v),
              _mini('부위', step.area, (v) => step.area = v),
            ],
          ],
        ],
      ),
    );
  }

  Widget _mini(String hint, String value, ValueChanged<String> write) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _LineField(
        initial: value,
        hint: hint,
        onChanged: (v) {
          write(v);
          widget.onChanged();
        },
      ),
    );
  }
}

class _LineField extends StatefulWidget {
  const _LineField({
    required this.initial,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_LineField> createState() => _LineFieldState();
}

class _LineFieldState extends State<_LineField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: SoriTokens.textTertiary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _DarkButton extends StatefulWidget {
  const _DarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  State<_DarkButton> createState() => _DarkButtonState();
}

class _DarkButtonState extends State<_DarkButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SoriTokens.textPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: widget.compact
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: label,
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(child: label),
                ),
        ),
      ),
    );
  }
}

class _PrimaryCapture extends StatelessWidget {
  const _PrimaryCapture({
    required this.label,
    required this.filled,
    required this.onTap,
    this.height = 148,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFE7E2DC) : const Color(0xFFF7F5F3),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 28,
                color: Color(0xFF6B6560),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryCapture extends StatelessWidget {
  const _SecondaryCapture({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFE7E2DC) : const Color(0xFFF7F5F3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 64,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldRow extends StatelessWidget {
  const _FoldRow({
    required this.title,
    required this.open,
    required this.onTap,
  });

  final String title;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              open ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
              color: SoriTokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 공유 별칭 — 홈 CHART 오늘 방문 작성 데스크(`chart_visit_workspace.dart`)가
// 이 파일의 필드 위젯을 그대로 재사용하도록 공개 이름만 덧붙인다.
// 기존 private 클래스와 위저드 동작은 바꾸지 않는다.
// ---------------------------------------------------------------------------

// ignore: library_private_types_in_public_api
typedef ChartVisitChoiceChip = _ChoiceChip;
// ignore: library_private_types_in_public_api
typedef ChartVisitScoreDots = _ScoreDots;
// ignore: library_private_types_in_public_api
typedef ChartVisitAxisRow = _AxisRow;
// ignore: library_private_types_in_public_api
typedef ChartVisitCareStepTile = _CareStepTile;
// ignore: library_private_types_in_public_api
typedef ChartVisitLineField = _LineField;
// ignore: library_private_types_in_public_api
typedef ChartVisitFoldRow = _FoldRow;
