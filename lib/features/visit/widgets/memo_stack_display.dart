import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_schedule_entry.dart';
import '../../operation/widgets/volume_glass_theme.dart';
import 'memo_display_policy.dart';

class MemoStackDisplay extends StatelessWidget {
  const MemoStackDisplay({
    super.key,
    required this.entries,
    required this.expanded,
    required this.onToggleExpand,
    this.now,
  });

  final List<CareScheduleEntry> entries;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tick = now ?? DateTime.now();
    final chip = MemoDisplayPolicy.collapsedChip(entries: entries, now: tick);

    if (chip == null && !expanded) {
      return const SizedBox.shrink();
    }

    if (expanded) {
      final list = MemoDisplayPolicy.expandedList(entries: entries, now: tick);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleExpand,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  _MemoChip(
                    label: MemoDisplayPolicy.formatChipLabel(list[i]),
                    front: i == 0,
                  ),
                  if (i < list.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggleExpand,
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            if (chip != null)
              _MemoChip(
                label: MemoDisplayPolicy.formatChipLabel(chip),
                front: true,
              ),
            Positioned(
              right: 0,
              child: Icon(
                Icons.layers_rounded,
                size: 20,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoChip extends StatelessWidget {
  const _MemoChip({required this.label, required this.front});

  final String label;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: front ? const Color(0xFF34C759) : const Color(0xFFE8F8EC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: front ? VolumeGlassTheme.volumeShadow(alpha: 0.04) : null,
      ),
      child: Row(
        children: [
          if (front)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: front ? Colors.white : const Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
