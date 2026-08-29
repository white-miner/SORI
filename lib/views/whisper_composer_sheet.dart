import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/whisper.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

const _kWhisperDraftKey = 'sori_whisper_composer_draft_v1';

Future<void> showWhisperComposer(
  BuildContext context, {
  required SoriStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => WhisperComposerSheet(store: store),
  );
}

class WhisperComposerSheet extends StatefulWidget {
  const WhisperComposerSheet({super.key, required this.store});

  final SoriStore store;

  @override
  State<WhisperComposerSheet> createState() => _WhisperComposerSheetState();
}

class _WhisperComposerSheetState extends State<WhisperComposerSheet> {
  final _bodyCtrl = TextEditingController();
  final Set<String> _atoms = {WhisperAtoms.everyone};
  final List<WhisperPreviewPerson> _explicitPeople = [];
  Timer? _debounce;
  WhisperAudiencePreview? _preview;
  final Map<String, WhisperAudiencePreview> _chipPreviewCache = {};
  final Set<String> _loadingChipPreviews = {};
  String? _focusedAtom;
  bool _sharing = false;
  bool _savingDraft = false;
  int _displayCount = 0;

  SoriStore get store => widget.store;

  /// Share when body + audience are set — do not gate on preview count
  /// (preview may still be loading or return 0 in empty shops).
  bool get _canShare {
    final hasBody = _bodyCtrl.text.trim().isNotEmpty;
    final hasAudience = _atoms.isNotEmpty || _explicitPeople.isNotEmpty;
    return hasBody && hasAudience && !_sharing;
  }

  bool get _canSaveDraft =>
      _bodyCtrl.text.trim().isNotEmpty && !_savingDraft && !_sharing;

  @override
  void initState() {
    super.initState();
    unawaited(store.refreshWhisperPresets());
    unawaited(_restoreDraft());
    _schedulePreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _countTimer?.cancel();
    _bodyCtrl.dispose();
    super.dispose();
  }

  WhisperAudienceSpec get _spec => WhisperAudienceSpec(
        op: 'union',
        atoms: [
          ..._atoms,
          if (_explicitPeople.isNotEmpty) WhisperAtoms.explicit,
        ],
        explicitUserIds: _explicitPeople.map((p) => p.userId).toList(),
        shopId: store.shop.id,
      );

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWhisperDraftKey);
      if (raw == null || raw.isEmpty || !mounted) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      final body = (map['body'] ?? '').toString();
      final atoms = (map['atoms'] is List)
          ? (map['atoms'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty && e != WhisperAtoms.peerDirectors)
              .toSet()
          : <String>{};
      if (!mounted) return;
      setState(() {
        if (body.isNotEmpty) _bodyCtrl.text = body;
        if (atoms.isNotEmpty) {
          _atoms
            ..clear()
            ..addAll(atoms);
        }
      });
      _schedulePreview();
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kWhisperDraftKey);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    if (!_canSaveDraft) return;
    setState(() => _savingDraft = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kWhisperDraftKey,
        jsonEncode({
          'body': _bodyCtrl.text.trim(),
          'atoms': _atoms.toList(),
          'saved_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('임시저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임시저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      if (_atoms.isEmpty && _explicitPeople.isEmpty) {
        setState(() {
          _preview = const WhisperAudiencePreview(count: 0);
          _displayCount = 0;
        });
        return;
      }
      final p = await store.previewWhisperAudience(_spec);
      if (!mounted) return;
      setState(() {
        _preview = p;
      });
      _animateCount(p.count);
    });
  }

  Timer? _countTimer;

  void _animateCount(int target) {
    _countTimer?.cancel();
    if ((target - _displayCount).abs() <= 1) {
      setState(() => _displayCount = target);
      return;
    }
    final start = _displayCount;
    const steps = 10;
    var i = 0;
    _countTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      i++;
      if (!mounted) {
        t.cancel();
        return;
      }
      final val = start + (((target - start) * i) / steps).round();
      if (i >= steps) {
        t.cancel();
        setState(() => _displayCount = target);
      } else {
        setState(() => _displayCount = val);
      }
    });
  }

  void _toggleAtom(String atom) {
    _countTimer?.cancel();
    setState(() {
      if (_atoms.contains(atom)) {
        _atoms.remove(atom);
      } else {
        _atoms.add(atom);
      }
      _focusedAtom = atom;
    });
    _schedulePreview();
    unawaited(_ensureChipPreview(atom));
  }

  Future<void> _loadPreset(WhisperAudiencePreset preset) async {
    setState(() {
      _atoms
        ..clear()
        ..addAll(
          preset.spec.atoms.where((a) => a != WhisperAtoms.peerDirectors),
        );
      _focusedAtom = _atoms.isEmpty ? null : _atoms.first;
    });
    _schedulePreview();
  }

  Future<void> _ensureChipPreview(String atom) async {
    if (_chipPreviewCache.containsKey(atom) ||
        _loadingChipPreviews.contains(atom)) {
      return;
    }
    _loadingChipPreviews.add(atom);
    try {
      final preview = await store.previewWhisperAudience(
        WhisperAudienceSpec(
          op: 'union',
          atoms: [atom],
          shopId: store.shop.id,
        ),
      );
      if (!mounted) return;
      setState(() {
        _chipPreviewCache[atom] = preview;
      });
    } finally {
      _loadingChipPreviews.remove(atom);
    }
  }

  Future<void> _savePreset() async {
    if (_atoms.isEmpty) return;
    final nameCtrl = TextEditingController(text: '나의 그룹');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surfaceElevated,
        title: const Text('그룹으로 저장', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '예: 전체 공지, Supporter 소식',
            hintStyle: TextStyle(color: SoriTokens.textQuaternary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '저장',
              style: TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.saveWhisperPreset(name: nameCtrl.text, spec: _spec);
    nameCtrl.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('그룹이 저장되었어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  Future<void> _share() async {
    final body = _bodyCtrl.text.trim();
    if (!_canShare) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surfaceElevated,
        title: const Text(
          'Whisper를 공유할까요?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${_atomSummary()} · 약 ${_preview?.count ?? _displayCount}명에게만 보이는 게시물로 공유됩니다.',
          style: const TextStyle(color: SoriTokens.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '공유하기',
              style: TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sharing = true);
    try {
      final result = await store.sendWhisper(body: body, spec: _spec);
      await _clearDraft();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.recipientCount}명에게 Whisper를 공유했어요'
            '${result.truncated ? ' (상한 적용)' : ''}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공유 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openAccountSearch() async {
    final result = await showModalBottomSheet<WhisperPreviewPerson>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _AccountSearchSheet(store: store),
    );
    if (result == null || !mounted) return;
    if (_explicitPeople.any((p) => p.userId == result.userId)) return;
    setState(() => _explicitPeople.add(result));
    _schedulePreview();
  }

  String _atomSummary() {
    final chips = _atoms.map(WhisperAtoms.label).toList();
    if (_explicitPeople.isNotEmpty) {
      chips.add('지정 ${_explicitPeople.length}명');
    }
    return chips.join(' · ');
  }

  WhisperAudiencePreview? get _focusedPreview =>
      _focusedAtom == null ? null : _chipPreviewCache[_focusedAtom!];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final presets = store.whisperPresets;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + kSoriFloatingNavClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SoriTokens.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Whisper',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _atoms.isEmpty ? null : _savePreset,
                    child: const Text(
                      '그룹 저장',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '누구에게만 보일지 먼저 고르세요. 선택하지 않은 사람에게는 공유되지 않습니다.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: SoriTokens.textTertiary,
                ),
              ),
              if (presets.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = presets[i];
                      return ActionChip(
                        label: Text(p.name),
                        onPressed: () => _loadPreset(p),
                        backgroundColor: SoriTokens.surfaceOverlay,
                        labelStyle: const TextStyle(
                          color: SoriTokens.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final atom in WhisperAtoms.composerChips)
                    _AtomChip(
                      label: WhisperAtoms.label(atom),
                      active: _atoms.contains(atom),
                      onTap: () => _toggleAtom(atom),
                      onPreviewStart: () {
                        if (_focusedAtom != atom) {
                          setState(() => _focusedAtom = atom);
                          unawaited(_ensureChipPreview(atom));
                        }
                      },
                      onPreviewEnd: () {},
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _ExplicitAccountRow(
                people: _explicitPeople,
                onAdd: _openAccountSearch,
                onRemove: (person) {
                  setState(() => _explicitPeople.remove(person));
                  _schedulePreview();
                },
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _focusedAtom == null
                    ? const SizedBox(width: double.infinity)
                    : _ChipAudiencePreview(
                        key: ValueKey(_focusedAtom),
                        label: WhisperAtoms.label(_focusedAtom!),
                        preview: _focusedPreview,
                        loading: _loadingChipPreviews.contains(_focusedAtom),
                      ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyCtrl,
                maxLines: 5,
                maxLength: 500,
                style: const TextStyle(color: SoriTokens.textPrimary),
                cursorColor: SoriTokens.primary,
                decoration: InputDecoration(
                  hintText: '타겟에게만 보일 게시물을 작성하세요…',
                  hintStyle: const TextStyle(color: SoriTokens.textQuaternary),
                  filled: true,
                  fillColor: SoriTokens.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                _atoms.isEmpty && _explicitPeople.isEmpty
                    ? '대상을 하나 이상 선택해 주세요'
                    : '현재 약 $_displayCount명에게 공유됩니다',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _atoms.isEmpty && _explicitPeople.isEmpty
                      ? SoriTokens.warningText
                      : SoriTokens.primary,
                ),
              ),
              if ((_preview?.preview.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _preview!.preview.length,
                    separatorBuilder: (_, _) => const SizedBox(width: -8),
                    itemBuilder: (context, i) {
                      final p = _preview!.preview[i];
                      return Align(
                        widthFactor: 0.72,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: SoriTokens.surfaceOverlay,
                          backgroundImage: p.avatarUrl.isNotEmpty
                              ? NetworkImage(p.avatarUrl)
                              : null,
                          child: p.avatarUrl.isEmpty
                              ? Text(
                                  p.nickname.characters.first,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '미리보기 · 이 밖에는 공유되지 않습니다',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: SoriTokens.textQuaternary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canSaveDraft ? _saveDraft : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SoriTokens.textPrimary,
                        disabledForegroundColor: SoriTokens.textQuaternary,
                        side: BorderSide(
                          color: _canSaveDraft
                              ? SoriTokens.border
                              : SoriTokens.surfaceOverlay,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _savingDraft ? '저장 중…' : '임시저장',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _canShare ? _share : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                        foregroundColor: SoriTokens.onPrimary,
                        disabledBackgroundColor: SoriTokens.surfaceOverlay,
                        disabledForegroundColor: SoriTokens.textQuaternary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _sharing ? '공유 중…' : '공유하기',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtomChip extends StatelessWidget {
  const _AtomChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onPreviewStart,
    required this.onPreviewEnd,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onPreviewStart;
  final VoidCallback onPreviewEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onPreviewStart(),
      onExit: (_) => onPreviewEnd(),
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onPreviewStart(),
        onLongPressEnd: (_) => onPreviewEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? SoriTokens.primary : SoriTokens.chipIdleBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? SoriTokens.onPrimary : SoriTokens.tabUnselected,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipAudiencePreview extends StatelessWidget {
  const _ChipAudiencePreview({
    super.key,
    required this.label,
    required this.preview,
    required this.loading,
  });

  final String label;
  final WhisperAudiencePreview? preview;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final people = preview?.preview.take(6).toList() ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: SoriTokens.surfaceOverlay,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SoriTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label 미리보기',
            style: const TextStyle(
              color: SoriTokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loading
                ? '조건에 맞는 계정을 불러오는 중…'
                : '대략 ${preview?.count ?? 0}명 · 좌우로 밀어 어떤 사람들이 있는지 살펴볼 수 있어요.',
            style: const TextStyle(
              fontSize: 11.5,
              color: SoriTokens.textSecondary,
              height: 1.35,
            ),
          ),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: people.length,
                separatorBuilder: (_, _) => const SizedBox(width: -18),
                itemBuilder: (context, index) {
                  final person = people[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 140 + (index * 45)),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset((1 - value) * 18, 0),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: _PreviewAvatarCard(person: person),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewAvatarCard extends StatelessWidget {
  const _PreviewAvatarCard({required this.person});

  final WhisperPreviewPerson person;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SoriTokens.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: SoriTokens.primarySoft,
            backgroundImage:
                person.avatarUrl.isNotEmpty ? NetworkImage(person.avatarUrl) : null,
            child: person.avatarUrl.isEmpty
                ? Text(
                    person.nickname.characters.first,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            person.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplicitAccountRow extends StatelessWidget {
  const _ExplicitAccountRow({
    required this.people,
    required this.onAdd,
    required this.onRemove,
  });

  final List<WhisperPreviewPerson> people;
  final VoidCallback onAdd;
  final void Function(WhisperPreviewPerson) onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SoriTokens.surfaceOverlay,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: people.isNotEmpty
                    ? SoriTokens.primary
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 15,
                  color: people.isNotEmpty
                      ? SoriTokens.primary
                      : SoriTokens.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  people.isEmpty
                      ? '계정 지정'
                      : '지정 ${people.length}명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: people.isNotEmpty
                        ? SoriTokens.primary
                        : SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (people.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final p = people[i];
                  return Chip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: SoriTokens.primarySoft,
                      child: Text(
                        p.nickname.characters.first,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    label: Text(
                      p.nickname,
                      style: const TextStyle(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => onRemove(p),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: SoriTokens.surfaceOverlay,
                    side: BorderSide.none,
                    labelPadding: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountSearchSheet extends StatefulWidget {
  const _AccountSearchSheet({required this.store});

  final SoriStore store;

  @override
  State<_AccountSearchSheet> createState() => _AccountSearchSheetState();
}

class _AccountSearchSheetState extends State<_AccountSearchSheet> {
  final _ctrl = TextEditingController();
  List<WhisperPreviewPerson> _results = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final directors = widget.store.discoverDirectors
        .where((d) =>
            d.nickname.toLowerCase().contains(query) ||
            d.shopName.toLowerCase().contains(query))
        .take(12)
        .map((d) => WhisperPreviewPerson(
              userId: d.ownerUserId ?? d.shopId,
              nickname: d.nickname,
              avatarUrl: d.avatarUrl,
            ))
        .toList();
    setState(() => _results = directors);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: SoriTokens.textPrimary),
                decoration: InputDecoration(
                  hintText: '이름 또는 샵 이름으로 검색',
                  hintStyle:
                      const TextStyle(color: SoriTokens.textQuaternary),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: SoriTokens.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _search,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final p = _results[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: SoriTokens.primarySoft,
                      backgroundImage: p.avatarUrl.isNotEmpty
                          ? NetworkImage(p.avatarUrl)
                          : null,
                      child: p.avatarUrl.isEmpty
                          ? Text(
                              p.nickname.characters.first,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      p.nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
            if (_results.isEmpty && _ctrl.text.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '검색 결과가 없어요',
                  style: TextStyle(
                    color: SoriTokens.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
