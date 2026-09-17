import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/care_schedule_entry.dart';

class MemoTimeSlotEditor extends StatefulWidget {
  const MemoTimeSlotEditor({
    super.key,
    required this.store,
    required this.day,
  });

  final SoriStore store;
  final DateTime day;

  @override
  State<MemoTimeSlotEditor> createState() => _MemoTimeSlotEditorState();
}

class _MemoSlotDraft {
  _MemoSlotDraft({
    this.id,
    required this.at,
    required this.note,
    required this.customerName,
    this.existing = false,
  });

  String? id;
  DateTime at;
  String note;
  String customerName;
  bool existing;
  bool removed = false;
}

class _MemoTimeSlotEditorState extends State<MemoTimeSlotEditor> {
  late List<_MemoSlotDraft> _slots;

  @override
  void initState() {
    super.initState();
    final existing = widget.store.careScheduleEntries
        .where(
          (e) =>
              e.isSameDay(widget.day) &&
              e.status != CareScheduleStatus.cancelled,
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (existing.isEmpty) {
      _slots = [_defaultSlot()];
    } else {
      _slots = [
        for (final e in existing)
          _MemoSlotDraft(
            id: e.id,
            at: e.scheduledAt,
            note: e.note,
            customerName: e.customerName,
            existing: true,
          ),
      ];
    }
  }

  _MemoSlotDraft _defaultSlot() {
    final base = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      12,
      0,
    );
    return _MemoSlotDraft(
      at: base,
      note: '',
      customerName: '',
    );
  }

  void _addSlot() {
    setState(() {
      final last = _slots.isNotEmpty ? _slots.last.at : _defaultSlot().at;
      _slots.add(
        _MemoSlotDraft(
          at: last.add(const Duration(minutes: 30)),
          note: '',
          customerName: '',
        ),
      );
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots[index].removed = true;
    });
  }

  Future<void> _save() async {
    for (final slot in _slots) {
      if (slot.removed && slot.id != null) {
        await widget.store.updateCareScheduleStatus(
          slot.id!,
          CareScheduleStatus.cancelled,
        );
        continue;
      }
      if (slot.removed) continue;
      if (slot.note.trim().isEmpty && slot.customerName.trim().isEmpty) {
        continue;
      }
      if (slot.existing && slot.id != null) {
        await widget.store.addManualCareSchedule(
          scheduledAt: slot.at,
          customerName: slot.customerName,
          note: slot.note,
        );
      } else {
        await widget.store.addManualCareSchedule(
          scheduledAt: slot.at,
          customerName: slot.customerName,
          note: slot.note,
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (var i = 0; i < _slots.length; i++)
        if (!_slots[i].removed) MapEntry(i, _slots[i]),
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.day.month}/${widget.day.day} 메모',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final entry = visible[idx];
                      final i = entry.key;
                      final slot = entry.value;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: TextFormField(
                              initialValue:
                                  '${slot.at.hour.toString().padLeft(2, '0')}:'
                                  '${slot.at.minute.toString().padLeft(2, '0')}',
                              decoration: const InputDecoration(
                                labelText: '시간',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                final parts = v.split(':');
                                if (parts.length == 2) {
                                  final h = int.tryParse(parts[0]) ?? 12;
                                  final m = int.tryParse(parts[1]) ?? 0;
                                  slot.at = DateTime(
                                    widget.day.year,
                                    widget.day.month,
                                    widget.day.day,
                                    h.clamp(0, 23),
                                    m.clamp(0, 59),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: slot.note,
                              decoration: const InputDecoration(
                                labelText: '메모',
                                isDense: true,
                              ),
                              onChanged: (v) => slot.note = v,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeSlot(i),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add),
                      label: const Text('시간대 추가'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
