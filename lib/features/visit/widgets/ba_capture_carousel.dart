import 'package:flutter/material.dart';

import '../../../models/ba_capture_session.dart';
import '../../../theme/sori_tokens.dart';
import '../../../utils/storage_image_url.dart';
import '../home_visual_tokens.dart';

/// PRD v7.0 ③ — B/A 등록 캐러셀.
///
/// 헌법 (v7.0.3):
/// 1. 좌측 맨 앞은 **'B/A 촬영' 고정 슬롯 단 1개**다. 빈 슬롯이 둘로 늘어나는
///    일은 없다. 여기서 찍은 사진은 고객을 연결하기 전까지 이 자리에 머문다.
/// 2. 고객을 연결해야만 고객 이름 + 🔴가 달린 독립 카드로 분리되어 우측에
///    쌓인다.
/// 3. 🟢 두 장 + 차트 매핑 완료 → **사라지지 않고** 뒤쪽에 그대로 남는다.
///    카드를 탭하면 뷰어로 열린다.
///
/// 카드 순서: [B/A 촬영 고정 슬롯] → [🔴 미완성] → [🟢 완성].
class BaCaptureCarousel extends StatelessWidget {
  const BaCaptureCarousel({
    super.key,
    required this.sessions,
    this.pending,
    required this.onCapture,
    required this.onBind,
    required this.onDefer,
    required this.onOpen,
    this.incompleteCount,
    this.transferringId,
    this.offlineDraft = false,
  });

  /// 고객이 연결되어 독립 카드로 분리된 세션들.
  final List<BaCaptureSession> sessions;

  /// 고정 슬롯에 머무는 미연결 촬영. null이면 슬롯은 비어 있다.
  final BaCaptureSession? pending;

  /// 서버 세션 테이블을 못 쓰는 구간 — 촬영은 되지만 기기 로컬에만 남는다.
  final bool offlineDraft;

  /// (세션, 'before' | 'after') — 세션이 null이면 고정 슬롯에서 촬영 시작.
  final void Function(BaCaptureSession? session, String kind) onCapture;

  /// 고객 차트 연결 — 고정 슬롯의 사진을 탭했을 때도 이 경로로 들어온다.
  final void Function(BaCaptureSession session) onBind;
  final void Function(BaCaptureSession session) onDefer;

  /// 🟢 카드 탭 — 이관된 관리 케이스를 뷰어로 연다.
  final void Function(BaCaptureSession session) onOpen;

  /// 넛지 배지 숫자. 생략하면 카드 목록에서 계산한다.
  final int? incompleteCount;

  /// 이관 확정 애니메이션 중인 세션 (320ms 동안 제자리에서 🟢로 굳는다).
  final String? transferringId;

  @override
  Widget build(BuildContext context) {
    final incomplete = incompleteCount ??
        (sessions.where((s) => !s.isComplete).length +
            (pending == null ? 0 : 1));

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
              // 헌법 1 — 첫 칸은 언제나 이 고정 슬롯 하나뿐이다. 촬영본이
              // 있어도 고객을 연결하기 전까지 여기 머문다.
              if (index == 0) {
                final p = pending;
                return _BaCard(
                  key: const Key('ba-fixed-capture-slot'),
                  session: p,
                  fixedSlot: true,
                  transferring: false,
                  onCapture: (kind) => onCapture(null, kind),
                  onBind: p == null ? null : () => onBind(p),
                  onDefer: null,
                  onOpen: null,
                );
              }
              final session = sessions[index - 1];
              return _BaCard(
                session: session,
                fixedSlot: false,
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
    super.key,
    required this.session,
    required this.fixedSlot,
    required this.transferring,
    required this.onCapture,
    required this.onBind,
    required this.onDefer,
    required this.onOpen,
  });

  final BaCaptureSession? session;

  /// 좌측 고정 'B/A 촬영' 슬롯인지. 고정 슬롯은 비워도 카드가 유지된다.
  final bool fixedSlot;
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
    final hasPhoto = s?.hasPhoto ?? false;
    final label = fixedSlot ? '' : (s?.label.trim() ?? '');

    // 고정 슬롯은 항상 '무엇을 하는 자리'인지로 읽혀야 한다.
    final title = fixedSlot
        ? 'B/A 촬영'
        : (label.isNotEmpty ? label : reason.badgeLabel);

    // 완성 카드는 촬영 대상이 아니라 참고용 뷰어다.
    // 고정 슬롯의 사진을 탭하면 곧장 고객 연결로 간다(헌법 3).
    final void Function(String kind) slotTap;
    if (complete && onOpen != null) {
      slotTap = (_) => onOpen!();
    } else if (fixedSlot && hasPhoto && onBind != null) {
      slotTap = (kind) {
        final filled = kind == 'after'
            ? (s?.hasAfter ?? false)
            : (s?.hasBefore ?? false);
        if (filled) {
          onBind!();
        } else {
          onCapture(kind);
        }
      };
    } else {
      slotTap = onCapture;
    }

    // 헌법 2 — 고객을 연결해야 독립 카드로 분리된다. 고정 슬롯에 사진이
    // 들어온 순간부터 연결 동선이 눈에 보여야 한다.
    // 헤더가 이미 사유를 말하고 있으면(라벨 없음) 아래에 또 쓰지 않는다.
    final Widget? footer;
    if (complete || s == null) {
      footer = null;
    } else if (fixedSlot) {
      footer = hasPhoto && onBind != null ? _BindChip(onTap: onBind!) : null;
    } else if (reason == BaDraftReason.unlinked && onBind != null) {
      footer = _BindChip(onTap: onBind!);
    } else {
      footer = label.isEmpty ? null : _ReasonChip(label: reason.badgeLabel);
    }

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
                // 빈 고정 슬롯에는 신호등을 켜지 않는다 — 할 일이 없는 자리다.
                if (!fixedSlot || hasPhoto)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Container(
                      width: HomeVisualTokens.baDotSize,
                      height: HomeVisualTokens.baDotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: complete
                            ? HomeVisualTokens.baDotGreen
                            : HomeVisualTokens.baDotRed,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: HomeVisualTokens.baLabelSize,
                      fontWeight: FontWeight.w700,
                      color: complete
                          ? HomeVisualTokens.baDotGreen
                          : (fixedSlot && !hasPhoto
                              ? HomeVisualTokens.dateTextColor
                              : HomeVisualTokens.dateIconColor),
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
            if (footer != null) ...[
              const SizedBox(height: 4),
              footer,
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

/// 이미 고객이 붙은 카드에서 "무엇이 비었는지"만 조용히 알린다.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomeVisualTokens.baDotRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeVisualTokens.baDotRed,
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
