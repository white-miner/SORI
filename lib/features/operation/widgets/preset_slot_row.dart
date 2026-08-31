import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';

/// 5-color iOS tint picker for preset slots.
class PresetSlotColorPicker extends StatelessWidget {
  const PresetSlotColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PresetSlotTint selected;
  final ValueChanged<PresetSlotTint> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final tint in PresetSlotTint.palette) ...[
          _TintDot(
            tint: tint,
            isSelected: tint == selected,
            onTap: () => onSelected(tint),
          ),
          if (tint != PresetSlotTint.palette.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _TintDot extends StatelessWidget {
  const _TintDot({
    required this.tint,
    required this.isSelected,
    required this.onTap,
  });

  final PresetSlotTint tint;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tint.label} 슬롯 색',
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 34 : 28,
          height: isSelected ? 34 : 28,
          decoration: BoxDecoration(
            color: tint.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.color.withValues(alpha: isSelected ? 0.45 : 0.22),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Horizontal row of 5 preset slot chips with custom tint colors.
class PresetSlotRow extends StatelessWidget {
  const PresetSlotRow({
    super.key,
    required this.selected,
    required this.presets,
    required this.tintAt,
    required this.onSelect,
  });

  final int selected;
  final List<CareProgramTemplate> presets;
  final PresetSlotTint Function(int slot) tintAt;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final p = i < presets.length ? presets[i] : null;
        final hasPreset = p != null && !p.isEmpty;
        final label = hasPreset ? p.name.trim() : '슬롯 ${i + 1}';
        final isSelected = i == selected;
        final tint = tintAt(i);
        final fill = isSelected ? tint.color : tint.color.withValues(alpha: 0.18);
        final border = isSelected ? tint.color : tint.color.withValues(alpha: 0.35);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 4 ? 5 : 0),
            child: Material(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
