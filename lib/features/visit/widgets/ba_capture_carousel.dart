import 'package:flutter/material.dart';

import '../../../models/ba_capture_session.dart';
import '../../../theme/sori_tokens.dart';
import '../../../utils/storage_image_url.dart';
import '../home_visual_tokens.dart';

/// PRD v7.0 ③ — B/A 등록 캐러셀.
///
/// 신호등 규약 (v7.0.2 정책 변경):
/// - 🔴 사진 누락 또는 차트 미연동 → 앞쪽에 남아 경고로 계속 노출된다.
/// - 🟢 두 장 + 차트 매핑 완료 → **사라지지 않고** 뒤쪽에 그대로 남는다.
///   카드를 탭하면 뷰어로 열린다.
///
/// 카드 순서: [빈 촬영 슬롯] → [🔴 미완성] → [🟢 완성].
class BaCaptureCarousel extends StatelessWidget {
  const BaCaptureCarousel({
    super.key,
    required this.sessions,
    required this.onCapture,
    required this.onBind,
    required this.onDefer,
    required this.onOpen,
    this.transferringId,
    this.offlineDraft = false,
  });

  final List<BaCaptureSession> sessions;

  /// 서버 세션 테이블을 못 쓰는 구간 — 촬영은 되지만 기기 로컬에만 남는다.
  final bool offlineDraft;

  /// (세션, 'before' | 'after') — 세션이 null이면 새 카드에서 촬영 시작.
  final void Function(BaCaptureSession? session, String kind) onCapture;
  final void Function(BaCaptureSession session) onBind;
  final void Function(BaCaptureSession session) onDefer;

  /// 🟢 카드 탭 — 이관된 관리 케이스를 뷰어로 연다.
  final void Function(BaCaptureSession session) onOpen;

  /// 이관 확정 애니메이션 중인 세션 (320ms 동안 제자리에서 🟢로 굳는다).
  final String? transferringId;

  @override
  Widget build(BuildContext context) {
    final incomplete = sessions.where((s) => !s.isComplete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HomeVisualTokens.sectionGutter,
            0,
            HomeVisualTokens.sectionGutter,
            8,
          ),
          child: Row(
            children: [
              const Text(
                'B/A 등록',
                style: TextStyle(
                  fontSize: HomeVisualTokens.sectionLabelSize,
                  fontWeight: FontWeight.w700,
                  color: HomeVisualTokens.sectionLabelColor,
                ),
              ),
              const Spacer(),
              if (offlineDraft)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    '이 기기에만 저장 중',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
              if (incomplete > 0) _NudgeBadge(count: incomplete),
            ],
          ),
        ),
        SizedBox(
          // 고정 높이 — 세로 제약이 캐러셀 밖으로 전파되지 않게 차단한다.
          height: HomeVisualTokens.baCarouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeVisualTokens.sectionGutter,
            ),
            itemCount: sessions.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HomeVisualTokens.baCardGap),
            itemBuilder: (context, index) {
              // 첫 슬롯은 항상 새 촬영 — 스크롤 없이 즉시 진입 가능해야 한다.
              if (index == 0) {
                return _BaCard(
                  session: null,
                  transferring: false,
                  onCapture: (kind) => onCapture(null, kind),
                  onBind: null,
                  onDefer: null,
                  onOpen: null,
                );
              }
              final session = sessions[index - 1];
              return _BaCard(
                session: session,
                transferring: session.id == transferringId,
                onCapture: (kind) => onCapture(session, kind),
                onBind: () => onBind(session),
                onDefer: () => onDefer(session),
                onOpen: () => onOpen(session),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NudgeBadge extends StatelessWidget {
  const _NudgeBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: HomeVisualTokens.baDotSize,
          height: HomeVisualTokens.baDotSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: HomeVisualTokens.baDotRed,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: HomeVisualTokens.baDotRed,
          ),
        ),
      ],
    );
  }
}

class _BaCard extends StatelessWidget {
  const _BaCard({
    required this.session,
    required this.transferring,
    required this.onCapture,
    required this.onBind,
    required this.onDefer,
    required this.onOpen,
  });

  final BaCaptureSession? session;
  final bool transferring;
  final void Function(String kind) onCapture;
  final VoidCallback? onBind;
  final VoidCallback? onDefer;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final reason = s?.reason ?? BaDraftReason.empty;
    // 이관 요청 직후에는 서버 응답 전이라도 🟢로 먼저 굳혀 보여준다.
    final complete = transferring || (s?.isComplete ?? false);
    final label = s?.label.trim() ?? '';

    // 완성 카드는 촬영 대상이 아니라 참고용 뷰어다.
    final slotTap = complete && onOpen != null
        ? (String _) => onOpen!()
        : onCapture;

    return AnimatedScale(
      // 제자리 확정 — 밖으로 밀어내면 🟢 카드가 캐러셀에서 사라진다.
      scale: transferring ? 1.04 : 1.0,
      duration: HomeVisualTokens.baTransferDuration,
      curve: HomeVisualTokens.baTransferCurve,
      child: SizedBox(
        width: HomeVisualTokens.baCardW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: HomeVisualTokens.baDotSize,
                  height: HomeVisualTokens.baDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete
                        ? HomeVisualTokens.baDotGreen
                        : HomeVisualTokens.baDotRed,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label.isNotEmpty ? label : reason.badgeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: HomeVisualTokens.baLabelSize,
                      fontWeight: FontWeight.w600,
                      color: complete
                          ? HomeVisualTokens.baDotGreen
                          : HomeVisualTokens.dateIconColor,
                    ),
                  ),
                ),
                if (s != null && onDefer != null && !complete)
                  _MiniIconButton(
                    icon: s.isDeferred
                        ? Icons.push_pin_rounded
                        : Icons.check_rounded,
                    onTap: onDefer!,
                  ),
                if (complete)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: HomeVisualTokens.baDotGreen,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Expanded로 잔여 높이를 흡수해 "고객 연결" 칩이 붙어도 넘치지 않는다.
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _Slot(
                      url: s?.beforeImageUrl,
                      caption: 'Before',
                      radius: const BorderRadius.horizontal(
                        left: Radius.circular(
                          HomeVisualTokens.baCardRadius,
                        ),
                      ),
                      onTap: () => slotTap('before'),
                    ),
                  ),
                  const SizedBox(width: HomeVisualTokens.baSlotGap),
                  Expanded(
                    child: _Slot(
                      url: s?.afterImageUrl,
                      caption: 'After',
                      radius: const BorderRadius.horizontal(
                        right: Radius.circular(
                          HomeVisualTokens.baCardRadius,
                        ),
                      ),
                      onTap: () => slotTap('after'),
                    ),
                  ),
                ],
              ),
            ),
            if (s != null &&
                reason == BaDraftReason.unlinked &&
                onBind != null &&
                !complete) ...[
              const SizedBox(height: 4),
              _BindChip(onTap: onBind!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.url,
    required this.caption,
    required this.radius,
    required this.onTap,
  });

  final String? url;
  final String caption;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = StorageImageUrl.resolve(url);
    final hasImage =
        resolved != null && StorageImageUrl.isNetworkUrl(resolved);

    return Material(
      color: HomeVisualTokens.baSlotFill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: hasImage
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => _AddGlyph(caption: caption),
              )
            : _AddGlyph(caption: caption),
      ),
    );
  }
}

class _AddGlyph extends StatelessWidget {
  const _AddGlyph({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: HomeVisualTokens.baAddCircle,
        height: HomeVisualTokens.baAddCircle,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 20,
          color: HomeVisualTokens.dateTextColor,
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 14,
          color: HomeVisualTokens.dateIconColor,
        ),
      ),
    );
  }
}

class _BindChip extends StatelessWidget {
  const _BindChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: double.infinity,
          height: 22,
          child: Center(
            child: Text(
              '고객 연결',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
