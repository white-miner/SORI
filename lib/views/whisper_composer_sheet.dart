import 'dart:async';

import 'package:flutter/material.dart';

import '../models/whisper.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

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
  final Set<String> _atoms = {WhisperAtoms.peerDirectors};
  String _op = 'union';
  Timer? _debounce;
  WhisperAudiencePreview? _preview;
  bool _sending = false;
  int _displayCount = 0;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(store.refreshWhisperInbox(box: 'sent'));
    _schedulePreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bodyCtrl.dispose();
    super.dispose();
  }

  WhisperAudienceSpec get _spec => WhisperAudienceSpec(
        op: _op,
        atoms: _atoms.toList(),
        shopId: store.shop.id,
      );

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      if (_atoms.isEmpty) {
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

  void _animateCount(int target) {
    final start = _displayCount;
    const steps = 10;
    var i = 0;
    Timer.periodic(const Duration(milliseconds: 28), (t) {
      i++;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _displayCount =
            start + (((target - start) * i) / steps).round();
      });
      if (i >= steps) {
        _displayCount = target;
        t.cancel();
      }
    });
  }

  void _toggleAtom(String atom) {
    setState(() {
      if (_atoms.contains(atom)) {
        _atoms.remove(atom);
      } else {
        _atoms.add(atom);
      }
    });
    _schedulePreview();
  }

  Future<void> _loadPreset(WhisperAudiencePreset preset) async {
    setState(() {
      _op = preset.op;
      _atoms
        ..clear()
        ..addAll(preset.spec.atoms);
    });
    _schedulePreview();
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
            hintText: '예: 동료+찐팬',
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

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty || _atoms.isEmpty || (_preview?.count ?? 0) < 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surfaceElevated,
        title: const Text(
          '속삭임을 보낼까요?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${_atomSummary()} · 약 ${_preview!.count}명에게만 전달됩니다.',
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
              '보내기',
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
    setState(() => _sending = true);
    try {
      final result = await store.sendWhisper(body: body, spec: _spec);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.recipientCount}명에게 속삭임을 보냈어요'
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
          content: Text('전송 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _atomSummary() {
    return _atoms.map(WhisperAtoms.label).join(' · ');
  }

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
                      '위스퍼 작성',
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
                '누구에게만 들릴지 먼저 고르세요. 선택하지 않은 사람에게는 절대 가지 않습니다.',
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
                  for (final atom in [
                    WhisperAtoms.visited,
                    WhisperAtoms.followers,
                    WhisperAtoms.peerDirectors,
                    WhisperAtoms.superFans,
                  ])
                    _AtomChip(
                      label: WhisperAtoms.label(atom),
                      active: _atoms.contains(atom),
                      onTap: () => _toggleAtom(atom),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    '조합',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: SoriTokens.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('넓히기 ∪'),
                    selected: _op == 'union',
                    onSelected: (_) {
                      setState(() => _op = 'union');
                      _schedulePreview();
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('좁히기 ∩'),
                    selected: _op == 'intersect',
                    onSelected: (_) {
                      setState(() => _op = 'intersect');
                      _schedulePreview();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyCtrl,
                maxLines: 5,
                maxLength: 500,
                style: const TextStyle(color: SoriTokens.textPrimary),
                cursorColor: SoriTokens.primary,
                decoration: InputDecoration(
                  hintText: '편하게 속삭여 보세요…',
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
                _atoms.isEmpty
                    ? '대상을 하나 이상 선택해 주세요'
                    : '현재 약 $_displayCount명에게 속삭입니다',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _atoms.isEmpty
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
                Text(
                  '미리보기 · 이 밖에는 전달되지 않습니다',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: SoriTokens.textQuaternary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _sending ||
                        _bodyCtrl.text.trim().isEmpty ||
                        _atoms.isEmpty ||
                        (_preview?.count ?? 0) < 1
                    ? null
                    : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: SoriTokens.surfaceOverlay,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _sending ? '보내는 중…' : '속삭임 보내기',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

class _AtomChip extends StatelessWidget {
  const _AtomChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? SoriTokens.primarySoft : SoriTokens.surfaceOverlay,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? SoriTokens.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? SoriTokens.primary : SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
