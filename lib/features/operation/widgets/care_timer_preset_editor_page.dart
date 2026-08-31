import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_program_template.dart';
import '../visit_timer_store.dart';
import 'flip_clock_display.dart';
import 'volume_glass_theme.dart';
import 'widget_glass_card.dart';

/// PRD v4.5 — preset editor: flip preview (left) + timeline sequence (right).
class CareTimerPresetEditorPage extends StatefulWidget {
  const CareTimerPresetEditorPage({
    super.key,
    required this.store,
    this.initialSlot = 0,
  });

  final SoriStore store;
  final int initialSlot;

  @override
  State<CareTimerPresetEditorPage> createState() =>
      _CareTimerPresetEditorPageState();
}

class _CareTimerPresetEditorPageState extends State<CareTimerPresetEditorPage> {
  late int _slot;
  late TextEditingController _nameCtrl;
  late List<_StepDraft> _steps;
  bool _saving = false;

  VisitTimerStore get timerStore => VisitTimerStore.instance;

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot.clamp(0, 4);
    _loadSlot(_slot);
  }

  void _loadSlot(int slot) {
    final preset = timerStore.presetAt(slot);
    _nameCtrl = TextEditingController(text: preset.name);
    _steps = preset.steps.isEmpty
        ? [_StepDraft(label: '구간 1', minutes: 10)]
        : preset.steps
            .map((s) => _StepDraft(label: s.label, minutes: s.minutes))
            .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final s in _steps) {
      s.labelCtrl.dispose();
    }
    super.dispose();
  }

  int get _previewSeconds =>
      _steps.fold<int>(0, (sum, s) => sum + s.minutes * 60);

  void _selectSlot(int slot) {
    setState(() {
      _slot = slot;
      for (final s in _steps) {
        s.labelCtrl.dispose();
      }
      _loadSlot(slot);
    });
  }

  void _addStep() {
    if (_steps.length >= 5) return;
    setState(() {
      _steps.add(_StepDraft(label: '구간 ${_steps.length + 1}', minutes: 10));
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      _steps[index].labelCtrl.dispose();
      _steps.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final sid = widget.store.shop.id.trim();
      final existing = timerStore.presetAt(_slot);
      final steps = _steps
          .map(
            (d) => CareProgramStep(
              label: d.labelCtrl.text.trim().isEmpty
                  ? '구간'
                  : d.labelCtrl.text.trim(),
              minutes: d.minutes.clamp(1, 180),
            ),
          )
          .toList();
      await timerStore.savePreset(
        existing.copyWith(
          shopId: sid,
          slotIndex: _slot,
          name: _nameCtrl.text.trim().isEmpty
              ? '프리셋 ${_slot + 1}'
              : _nameCtrl.text.trim(),
          steps: steps,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        elevation: 0,
        title: Text(
          '케어 타이머 프리셋',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중…' : '저장'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PresetQuickPick(
              selected: _slot,
              presets: timerStore.presets,
              onSelect: _selectSlot,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildPreviewPanel()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildSequenceBoard()),
                      ],
                    )
                  : ListView(
                      children: [
                        _buildPreviewPanel(),
                        const SizedBox(height: 16),
                        _buildSequenceBoard(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return WidgetGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '케어 프로그램 이름',
              hintStyle: GoogleFonts.nunito(color: SoriTokens.textSecondary),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: FlipClockDisplay(
              totalSeconds: _previewSeconds,
              subtitle: '총 ${_previewSeconds ~/ 60}분 · ${_steps.length}구간',
              stepLabel: '프리뷰',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceBoard() {
    return WidgetGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '타임라인 시퀀스',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_steps.length < 5)
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('구간 추가'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TimelineStepBlock(
                index: i + 1,
                draft: step,
                onMinutesChanged: (v) => setState(() => step.minutes = v),
                onRemove: _steps.length > 1 ? () => _removeStep(i) : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PresetQuickPick extends StatelessWidget {
  const _PresetQuickPick({
    required this.selected,
    required this.presets,
    required this.onSelect,
  });

  final int selected;
  final List<CareProgramTemplate> presets;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(5, (i) {
          final p = i < presets.length ? presets[i] : null;
          final label = p != null && p.name.trim().isNotEmpty
              ? p.name.trim()
              : '슬롯 ${i + 1}';
          final isSelected = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
              labelStyle: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
              ),
              selectedColor: SoriTokens.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              side: BorderSide(
                color: isSelected
                    ? SoriTokens.primary
                    : Colors.black.withValues(alpha: 0.08),
              ),
              onSelected: (_) => onSelect(i),
            ),
          );
        }),
      ),
    );
  }
}

class _StepDraft {
  _StepDraft({required String label, required this.minutes})
      : labelCtrl = TextEditingController(text: label);

  final TextEditingController labelCtrl;
  int minutes;
}

class _TimelineStepBlock extends StatelessWidget {
  const _TimelineStepBlock({
    required this.index,
    required this.draft,
    required this.onMinutesChanged,
    this.onRemove,
  });

  final int index;
  final _StepDraft draft;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VolumeGlassTheme.cardFillColor(alpha: 0.88),
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.67),
        boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.04),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SoriTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: SoriTokens.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: draft.labelCtrl,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '구간명',
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                onMinutesChanged((draft.minutes - 1).clamp(1, 180)),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${draft.minutes}분',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                onMinutesChanged((draft.minutes + 1).clamp(1, 180)),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
