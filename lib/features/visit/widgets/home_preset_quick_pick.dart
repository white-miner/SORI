import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import '../../operation/visit_timer_store.dart';
import '../home_visual_tokens.dart';

/// PRD v5.4 — home bottom preset quick-pick (Path C SSOT).
class HomePresetQuickPick extends StatelessWidget {
  const HomePresetQuickPick({
    super.key,
    required this.timerStore,
    required this.onSlotSelected,
    required this.onConfigureSlot,
  });

  final VisitTimerStore timerStore;
  final ValueChanged<int> onSlotSelected;
  final ValueChanged<int> onConfigureSlot;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timerStore,
      builder: (context, _) {
        final rows = <Widget>[];
        for (var slot = 0; slot < 5; slot++) {
          final preset = timerStore.presetAt(slot);
          if (preset.isEmpty) continue;
          rows.add(
            _PresetQuickRow(
              slot: slot,
              preset: preset,
              tint: timerStore.tintAt(slot),
              selected: timerStore.homeSelectedPresetSlot == slot,
              onTap: () => onSlotSelected(slot),
            ),
          );
        }
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              HomeVisualTokens.heroCardPaddingH,
              0,
              HomeVisualTokens.heroCardPaddingH,
              16,
            ),
            child: Material(
              color: HomeVisualTokens.heroCardFill,
              borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
              child: InkWell(
                onTap: () => onConfigureSlot(0),
                borderRadius:
                    BorderRadius.circular(HomeVisualTokens.heroCardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(HomeVisualTokens.presetCardPadding),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: HomeVisualTokens.toolboxLabelColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '프리셋을 설정하면 퀵 리스트에 표시됩니다',
                        style: GoogleFonts.nunito(
                          fontSize: HomeVisualTokens.presetLabelTextSize,
                          fontWeight: FontWeight.w700,
                          color: HomeVisualTokens.toolboxLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            HomeVisualTokens.heroCardPaddingH,
            0,
            HomeVisualTokens.heroCardPaddingH,
            16,
          ),
          child: Material(
            color: HomeVisualTokens.heroCardFill,
            borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
            child: Padding(
              padding: const EdgeInsets.all(HomeVisualTokens.presetCardPadding),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1)
                      const SizedBox(height: HomeVisualTokens.presetRowGap),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresetQuickRow extends StatelessWidget {
  const _PresetQuickRow({
    required this.slot,
    required this.preset,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final int slot;
  final CareProgramTemplate preset;
  final PresetSlotTint tint;
  final bool selected;
  final VoidCallback onTap;

  int _plannedMinutes() {
    var total = 0;
    for (final step in preset.steps) {
      total += step.minutes;
    }
    return total > 0 ? total : 60;
  }

  String _timeLabel() {
    final m = _plannedMinutes();
    return '${m.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = tint.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeVisualTokens.presetLabelRadius),
        child: Row(
          children: [
            Container(
              width: HomeVisualTokens.presetTimeChipW,
              height: HomeVisualTokens.presetTimeChipH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius:
                    BorderRadius.circular(HomeVisualTokens.presetTimeChipRadius),
                boxShadow: [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                _timeLabel(),
                style: GoogleFonts.nunito(
                  fontSize: HomeVisualTokens.presetTimeTextSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: HomeVisualTokens.presetRowGap),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: HomeVisualTokens.presetLabelFill,
                  borderRadius:
                      BorderRadius.circular(HomeVisualTokens.presetLabelRadius),
                  border: selected
                      ? Border.all(
                          color: chipColor.withValues(alpha: 0.45),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Text(
                  preset.name.trim().isEmpty ? '슬롯 ${slot + 1}' : preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: HomeVisualTokens.presetLabelTextSize,
                    fontWeight: FontWeight.w700,
                    color: HomeVisualTokens.dateTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
