import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';
import 'program_unit_price.dart';

/// 단건 요약과 비교 열에서 같은 구성 어휘를 쓴다.
class ProgramPackageSummary extends StatelessWidget {
  const ProgramPackageSummary({
    super.key,
    required this.side,
    this.peer,
    this.selected = false,
    this.onChoose,
  });

  final ProgramPackageSnapshot side;
  final ProgramPackageSnapshot? peer;
  final bool selected;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final peerSide = peer;
    final unitWins =
        peerSide != null && side.unitPriceKrw < peerSide.unitPriceKrw;
    final steps = side.lines.where((l) => l.kind == ProgramLineKind.step);
    final devices = side.lines.where((l) => l.kind == ProgramLineKind.device);
    final ampoules = side.lines.where((l) => l.kind == ProgramLineKind.ampoule);
    final perks = side.lines.where((l) => l.kind == ProgramLineKind.perk);
    final accent = Color(ProgramAccent.argbOf(side.accentHex));

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
            Expanded(
              child: Text(
                side.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        if (side.categoryName.trim().isNotEmpty)
          Text(
            side.categoryName,
            style: const TextStyle(
              fontSize: 11,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
        const SizedBox(height: 10),
        _kv('횟수', '${side.visitCount}회'),
        _kv(
          '회당 단가',
          ProgramPricing.formatKrw(side.unitPriceKrw),
          emphasize: unitWins,
        ),
        ProgramUnitPriceBlock(
          unitPriceKrw: side.unitPriceKrw,
          visitCount: side.visitCount,
          walkInPriceKrw: side.walkInPriceKrw,
        ),
        const SizedBox(height: 6),
        _kv(
          '정가',
          ProgramPricing.formatKrw(side.listPriceKrw),
          large: true,
        ),
        const SizedBox(height: 8),
        const Text(
          '구성',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeVisualTokens.dateIconColor,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Text(
            '${i + 1}. ${steps.elementAt(i).label}'
            '${steps.elementAt(i).minutes == null ? '' : ' ${steps.elementAt(i).minutes}분'}',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        for (final perk in perks)
          Text(
            '· ${perk.label}',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in devices) _chip(d.label),
            ],
          ),
        ],
        if (ampoules.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in ampoules) _chip(a.label),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _kv('시간 합', '${side.stepMinutes}분'),
      ],
    );

    return Material(
      color: selected ? HomeVisualTokens.canvasBg : Colors.transparent,
      child: onChoose == null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: body,
            )
          : InkWell(
              onTap: onChoose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: body,
              ),
            ),
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 22 : 14,
                fontWeight: emphasize || large ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomeVisualTokens.canvasBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
