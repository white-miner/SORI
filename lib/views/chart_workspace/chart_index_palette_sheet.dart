import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/sori_tokens.dart';
import 'chart_index_label.dart';
import 'chart_index_palette.dart';

/// 0~9 끝자리 색상 설정. Chart 헤더의 조용한 아이콘에서 진입한다.
///
/// Material 버튼 나열이 아니라, 실제 rail 라벨([ChartIndexLabel])로 실시간
/// 미리보기를 보여주는 SORI 파일 라벨 시스템의 설정 도구로 구현한다.
Future<void> showChartIndexPaletteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SoriTokens.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _ChartIndexPaletteSheet(),
  );
}

class _ChartIndexPaletteSheet extends StatelessWidget {
  const _ChartIndexPaletteSheet();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.84;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: ListenableBuilder(
          listenable: ChartIndexPaletteStore.instance,
          builder: (context, _) {
            final palette = ChartIndexPaletteStore.instance.palette;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 2),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '인덱스 색상',
                          key: Key('chart-index-color-title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textCharcoal,
                          ),
                        ),
                      ),
                      InkWell(
                        key: const Key('chart-index-color-reset'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            ChartIndexPaletteStore.instance.resetToDefault(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            '기본값으로',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'No.N · vN의 끝자리 숫자가 파일과 기록지를 찾는 색이 '
                    '됩니다. 항목을 눌러 색을 바꾸세요. No와 v는 같은 색을 '
                    '공유합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    itemCount: 10,
                    separatorBuilder: (_, __) => const Divider(
                      height: 18,
                      thickness: 1,
                      color: Color(0xFFEDEAE4),
                    ),
                    itemBuilder: (context, digit) {
                      final color =
                          palette[digit] ?? kDefaultChartIndexPalette[digit]!;
                      return _PaletteRow(digit: digit, color: color);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.digit, required this.color});

  final int digit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 끝자리가 실제로 보이는 두 자리 예시 번호. 0→10, 1→11 ... 9→19.
    final previewNumber = 10 + digit;
    return InkWell(
      key: Key('chart-index-color-row-$digit'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$digit',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: ChartIndexLabel.laneHeight,
              child: IgnorePointer(
                child: ChartIndexLabel(
                  key: Key('chart-index-color-preview-no-$digit'),
                  text: 'No.$previewNumber',
                  selected: false,
                  baseColor: color,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: ChartIndexLabel.laneHeight,
              child: IgnorePointer(
                child: ChartIndexLabel(
                  key: Key('chart-index-color-preview-v-$digit'),
                  text: 'v$previewNumber',
                  selected: true,
                  baseColor: color,
                  compact: true,
                ),
              ),
            ),
            const Spacer(),
            _Swatch(color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: SoriTokens.surface,
      showDragHandle: true,
      builder: (ctx) => _ChartColorPickerSheet(digit: digit, current: color),
    );
    if (picked != null) {
      await ChartIndexPaletteStore.instance.setColor(digit, picked);
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ChartIndexColor.border(color), width: 1.4),
      ),
    );
  }
}

/// 큐레이션 스와치 팔레트 + 직접 HEX 입력. 색 선택기를 한 시트에서 둘 다
/// 제공한다 — 별도 색 선택 패키지 의존 없이 SORI 톤과 어울리는 후보만.
const List<Color> kChartSwatchOptions = [
  Color(0xFFFFFFFF),
  Color(0xFFF4F0E6),
  Color(0xFFE7E5E4),
  Color(0xFF9CA3AF),
  Color(0xFF6B7280),
  Color(0xFF374151),
  Color(0xFF111111),
  Color(0xFFEF4444),
  Color(0xFFDC2626),
  Color(0xFFF97316),
  Color(0xFFEA580C),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFFFDE047),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF16A34A),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF2563EB),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFA855F7),
  Color(0xFFD946EF),
  Color(0xFFEC4899),
  Color(0xFFF472B6),
  Color(0xFFFB7185),
  Color(0xFF78716C),
];

class _ChartColorPickerSheet extends StatefulWidget {
  const _ChartColorPickerSheet({required this.digit, required this.current});

  final int digit;
  final Color current;

  @override
  State<_ChartColorPickerSheet> createState() =>
      _ChartColorPickerSheetState();
}

class _ChartColorPickerSheetState extends State<_ChartColorPickerSheet> {
  late final TextEditingController _hex;
  Color? _hexPreview;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController(text: _toHex(widget.current));
    _hexPreview = widget.current;
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _toHex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return v.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  static Color? _parseHex(String input) {
    final cleaned = input.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  void _onHexChanged(String value) {
    final parsed = _parseHex(value);
    setState(() {
      _hexPreview = parsed;
      _hexError = parsed == null && value.trim().isNotEmpty ? '6자리 16진수(예: 8B5CF6)' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.digit} 끝자리 색',
              key: Key('chart-color-picker-title-${widget.digit}'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textCharcoal,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in kChartSwatchOptions)
                  _SwatchOption(
                    key: Key(
                      'chart-color-picker-swatch-${widget.digit}-'
                      '${_toHex(swatch)}',
                    ),
                    color: swatch,
                    selected: swatch.toARGB32() == widget.current.toARGB32(),
                    onTap: () => Navigator.of(context).pop(swatch),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '직접 입력 (HEX)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _hexPreview ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD6D3D1),
                      width: 1.2,
                    ),
                  ),
                  child: const SizedBox(width: 28, height: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('chart-color-picker-hex-field'),
                    controller: _hex,
                    onChanged: _onHexChanged,
                    maxLength: 7,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9A-Fa-f#]'),
                      ),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: '8B5CF6',
                      errorText: _hexError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  key: const Key('chart-color-picker-hex-apply'),
                  onPressed: _hexPreview == null
                      ? null
                      : () => Navigator.of(context).pop(_hexPreview),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.textCharcoal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchOption extends StatelessWidget {
  const _SwatchOption({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? SoriTokens.textCharcoal
                : ChartIndexColor.border(color),
            width: selected ? 2.2 : 1.2,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 16,
                color: ChartIndexColor.onFill(color),
              )
            : null,
      ),
    );
  }
}
