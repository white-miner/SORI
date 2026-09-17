import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import 'volume_glass_theme.dart';

/// PRD v5.2 — bottom expandable preset list (replaces top 5-chip row).
class PresetExpandPanel extends StatefulWidget {
  const PresetExpandPanel({
    super.key,
    required this.presets,
    required this.tintAt,
    required this.selectedSlot,
    required this.onPresetSelected,
    required this.onConfigureSlot,
    required this.onOpenEditor,
  });

  final List<CareProgramTemplate> presets;
  final PresetSlotTint Function(int slot) tintAt;
  final int selectedSlot;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int> onConfigureSlot;
  final VoidCallback onOpenEditor;

  @override
  State<PresetExpandPanel> createState() => _PresetExpandPanelState();
}

class _PresetExpandPanelState extends State<PresetExpandPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  late final AnimationController _chevronController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronController.forward();
    } else {
      _chevronController.reverse();
    }
  }

  CareProgramTemplate _presetAt(int slot) {
    if (slot >= 0 && slot < widget.presets.length) {
      return widget.presets[slot];
    }
    return CareProgramTemplate.empty(shopId: '', slotIndex: slot);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.58),
          child: InkWell(
            onTap: _toggle,
            borderRadius:
                BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.58),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.58),
                border: Border.all(
                  color: const Color(0xFF3A3A3C).withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: VolumeGlassTheme.vibrantCareGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '타이머 프리셋 설정 및 선택',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(
                        CurvedAnimation(
                          parent: _chevronController,
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _PresetList(
                    presetAt: _presetAt,
                    tintAt: widget.tintAt,
                    selectedSlot: widget.selectedSlot,
                    onPresetSelected: (slot) {
                      widget.onPresetSelected(slot);
                    },
                    onConfigureSlot: widget.onConfigureSlot,
                    onOpenEditor: widget.onOpenEditor,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList({
    required this.presetAt,
    required this.tintAt,
    required this.selectedSlot,
    required this.onPresetSelected,
    required this.onConfigureSlot,
    required this.onOpenEditor,
  });

  final CareProgramTemplate Function(int) presetAt;
  final PresetSlotTint Function(int) tintAt;
  final int selectedSlot;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int> onConfigureSlot;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VolumeGlassTheme.cardFillColor(),
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.65),
        boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.05),
        border: Border.all(
          color: const Color(0xFF3A3A3C).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            _PresetRow(
              slot: i,
              preset: presetAt(i),
              tint: tintAt(i),
              isSelected: i == selectedSlot,
              onTap: () {
                final p = presetAt(i);
                if (p.isEmpty) {
                  onConfigureSlot(i);
                } else {
                  onPresetSelected(i);
                }
              },
            ),
            if (i < 4)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: const Color(0xFF3A3A3C).withValues(alpha: 0.06),
              ),
          ],
          Divider(
            height: 1,
            color: const Color(0xFF3A3A3C).withValues(alpha: 0.06),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenEditor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(VolumeGlassTheme.cardRadius * 0.65),
                bottomRight: Radius.circular(VolumeGlassTheme.cardRadius * 0.65),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: const Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '프리셋 편집기 열기',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.slot,
    required this.preset,
    required this.tint,
    required this.isSelected,
    required this.onTap,
  });

  final int slot;
  final CareProgramTemplate preset;
  final PresetSlotTint tint;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPreset = !preset.isEmpty;
    final name = hasPreset ? preset.name.trim() : '슬롯 ${slot + 1}';
    final stepCount = preset.steps.length;

    return Material(
      color: isSelected && hasPreset
          ? tint.color.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hasPreset
                      ? tint.color
                      : const Color(0xFF8E8E93).withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPreset ? name : '+ 설정',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasPreset
                        ? const Color(0xFF111111)
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ),
              if (hasPreset) ...[
                Text(
                  '$stepCount구간',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: tint.color.withValues(alpha: 0.85),
                ),
              ] else
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: const Color(0xFF8E8E93).withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
