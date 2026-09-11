import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_schedule_entry.dart';
import '../care_schedule_read_density.dart';
import '../home_visual_tokens.dart';

/// PRD v7.9 Phase 3 — 마이 오늘 일정 CRUD (note·추가·취소).
/// 홈은 미리보기만 · SOAP/고객 메모 자동 복제 금지 · Timer 미연결.
class MyTodayScheduleReadPanel extends StatelessWidget {
  const MyTodayScheduleReadPanel({
    super.key,
    required this.store,
    DateTime? now,
  }) : _now = now;

  final SoriStore store;
  final DateTime? _now;

  /// 줄 수 ≤2 → 바텀시트, 초과 → 전체 화면 (§16.2).
  static bool useFullscreenNoteEditor(String note) {
    final lines = note.trim().isEmpty
        ? 0
        : note.trim().split(RegExp(r'\r?\n')).length;
    final longLine = note.trim().length > 80;
    return lines > 2 || longLine;
  }

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final list = CareScheduleReadDensity.myTodayReadList(
      store.careScheduleEntries,
      now: now,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘 일정',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openAddSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '일정 추가',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Text(
            '메모 수정은 여기에서 · 홈에는 미리보기만',
            style: TextStyle(
              fontSize: 11,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Text(
              '오늘 예정된 일정이 없어요.',
              style: TextStyle(
                fontSize: 13,
                color: HomeVisualTokens.dateIconColor,
              ),
            )
          else
            ...list.map((e) => _ScheduleRow(
                  entry: e,
                  onEditNote: () => _openNoteEditor(context, e),
                  onCancel: e.status == CareScheduleStatus.scheduled
                      ? () => _cancelEntry(context, e)
                      : null,
                )),
        ],
      ),
    );
  }

  Future<void> _openNoteEditor(
    BuildContext context,
    CareScheduleEntry entry,
  ) async {
    final initial = entry.note;
    final fullscreen = useFullscreenNoteEditor(initial);
    final result = fullscreen
        ? await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => _NoteFullscreenPage(initialNote: initial),
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Colors.white,
            builder: (ctx) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: _NoteBottomSheet(initialNote: initial),
            ),
          );
    if (result == null || !context.mounted) return;
    if (result.trim() == entry.note.trim()) return;
    try {
      await store.updateCareScheduleEntry(entry.copyWith(note: result.trim()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정 메모를 저장했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장에 실패했어요'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.systemRed,
        ),
      );
    }
  }

  Future<void> _cancelEntry(
    BuildContext context,
    CareScheduleEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정을 취소할까요?'),
        content: Text(
          '${CareScheduleReadDensity.timeLabel(entry.scheduledAt)} '
          '${entry.customerName.trim().isEmpty ? '고객' : entry.customerName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await store.updateCareScheduleStatus(
      entry.id,
      CareScheduleStatus.cancelled,
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final now = _now ?? DateTime.now();
    final created = await showModalBottomSheet<CareScheduleEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _AddScheduleSheet(day: now),
      ),
    );
    if (created == null || !context.mounted) return;
    try {
      await store.addManualCareSchedule(
        scheduledAt: created.scheduledAt,
        customerName: created.customerName,
        customerId: created.customerId,
        careLabel: created.careLabel,
        note: created.note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정을 추가했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('일정 추가에 실패했어요'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.systemRed,
        ),
      );
    }
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.entry,
    required this.onEditNote,
    this.onCancel,
  });

  final CareScheduleEntry entry;
  final VoidCallback onEditNote;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final note = CareScheduleReadDensity.notePreview(entry);
    final completed = entry.status == CareScheduleStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CareScheduleReadDensity.timeLabel(entry.scheduledAt),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    entry.customerName.trim().isEmpty
                        ? '고객'
                        : entry.customerName.trim(),
                    if (entry.careLabel.trim().isNotEmpty)
                      entry.careLabel.trim(),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? HomeVisualTokens.dateIconColor
                        : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
              if (completed)
                Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 11,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: onEditNote,
                style: TextButton.styleFrom(
                  foregroundColor: SoriTokens.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  note == null ? '메모 추가' : '메모 수정',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: HomeVisualTokens.dateIconColor,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '일정 취소',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteBottomSheet extends StatefulWidget {
  const _NoteBottomSheet({required this.initialNote});

  final String initialNote;

  @override
  State<_NoteBottomSheet> createState() => _NoteBottomSheetState();
}

class _NoteBottomSheetState extends State<_NoteBottomSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '일정 메모',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '이 일정에만 저장돼요 · 고객 메모로 자동 복사되지 않아요',
              style: TextStyle(
                fontSize: 11,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '준비 · 요청 · 리마인더',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, _ctrl.text),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteFullscreenPage extends StatefulWidget {
  const _NoteFullscreenPage({required this.initialNote});

  final String initialNote;

  @override
  State<_NoteFullscreenPage> createState() => _NoteFullscreenPageState();
}

class _NoteFullscreenPageState extends State<_NoteFullscreenPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 메모'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ctrl,
          maxLines: null,
          expands: true,
          autofocus: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: '긴 메모는 여기에 작성해요',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _AddScheduleSheet extends StatefulWidget {
  const _AddScheduleSheet({required this.day});

  final DateTime day;

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  late TimeOfDay _time;
  final _nameCtrl = TextEditingController();
  final _careCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _time = TimeOfDay.fromDateTime(widget.day);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _careCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '일정 추가',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('시간'),
              trailing: Text(_time.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '고객 이름'),
            ),
            TextField(
              controller: _careCtrl,
              decoration: const InputDecoration(labelText: '케어/서비스'),
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                final at = DateTime(
                  widget.day.year,
                  widget.day.month,
                  widget.day.day,
                  _time.hour,
                  _time.minute,
                );
                Navigator.pop(
                  context,
                  CareScheduleEntry(
                    id: 'draft',
                    shopId: '',
                    scheduledAt: at,
                    customerName: name,
                    careLabel: _careCtrl.text.trim(),
                    note: _noteCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}
