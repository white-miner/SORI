import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../models/chart_consent_texts.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_scroll_behavior.dart';
import 'my_app.dart';

/// 전자 동의서 — 필수 3항목 아코디언 + 선택 촬영 동의 + 하단 서명 패드.
class ChartConsentTab extends StatefulWidget {
  const ChartConsentTab({
    super.key,
    required this.consentCareNotice,
    required this.consentAbnormalReaction,
    required this.consentRefundPolicy,
    required this.consentPhoto,
    required this.consentMarketing,
    required this.consentOfflineOnly,
    required this.signatureController,
    required this.onCareNoticeChanged,
    required this.onAbnormalReactionChanged,
    required this.onRefundPolicyChanged,
    required this.onPhotoChanged,
    required this.onMarketingSelected,
    required this.onOfflineOnlySelected,
    required this.onClearSignature,
    this.existingSignatureUrl,
    this.quickChartMode = false,
    this.consentValidUntil,
    this.consentSectionKey,
    this.signatureFieldKey,
    this.shakeAnimation,
    this.highlightConsent = false,
    this.highlightSignature = false,
    this.showConsentError = false,
    this.showSignatureError = false,
    this.consentErrorText = '필수 동의 항목을 체크해 주세요',
    this.signatureErrorText = '서명이 누락되었습니다',
    this.onSignaturePointerActive,
  });

  final bool consentCareNotice;
  final bool consentAbnormalReaction;
  final bool consentRefundPolicy;
  final bool consentPhoto;
  final bool consentMarketing;
  final bool consentOfflineOnly;
  final SignatureController signatureController;
  final ValueChanged<bool> onCareNoticeChanged;
  final ValueChanged<bool> onAbnormalReactionChanged;
  final ValueChanged<bool> onRefundPolicyChanged;
  final ValueChanged<bool> onPhotoChanged;
  final VoidCallback onMarketingSelected;
  final VoidCallback onOfflineOnlySelected;
  final VoidCallback onClearSignature;
  final String? existingSignatureUrl;

  /// 최근 1년 이내 서명 이력 → 필수 동의/서명 검증 Bypass.
  final bool quickChartMode;
  final DateTime? consentValidUntil;

  final GlobalKey? consentSectionKey;
  final GlobalKey? signatureFieldKey;
  final Animation<double>? shakeAnimation;
  final bool highlightConsent;
  final bool highlightSignature;
  final bool showConsentError;
  final bool showSignatureError;
  final String consentErrorText;
  final String signatureErrorText;
  final ValueChanged<bool>? onSignaturePointerActive;

  @override
  State<ChartConsentTab> createState() => _ChartConsentTabState();
}

class _ChartConsentTabState extends State<ChartConsentTab> {
  bool _lockConsentScroll = false;

  String _fmtUntil(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  void _setSignaturePointerActive(bool active) {
    if (_lockConsentScroll == active) return;
    setState(() => _lockConsentScroll = active);
    widget.onSignaturePointerActive?.call(active);
  }

  @override
  void dispose() {
    if (_lockConsentScroll) {
      widget.onSignaturePointerActive?.call(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: const SoriMouseWheelScrollBehavior(),
            child: ListView(
              physics: _lockConsentScroll
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
              if (widget.quickChartMode && widget.consentValidUntil != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Text(
                    '✅ 1년 포괄적 동의 완료 (유효기간: ${_fmtUntil(widget.consentValidUntil!)} 까지)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text(
                    '단골 고객 간편 차트 모드입니다. 필수 동의·자필 서명 없이 바로 저장할 수 있어요. (선택 촬영 동의는 필요 시 갱신 가능)',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text(
                    '신규·갱신 고객은 필수 동의 3항목과 자필 서명이 모두 완료되어야 차트를 저장할 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ConsentValidationBlock(
                  anchorKey: widget.consentSectionKey,
                  highlighted: widget.highlightConsent,
                  showError: widget.showConsentError,
                  errorText: widget.consentErrorText,
                  shake: widget.shakeAnimation,
                  child: Column(
                    children: [
                      _MandatoryAccordion(
                        title: ChartConsentTexts.mandatoryCareTitle,
                        bullets: ChartConsentTexts.mandatoryCareBody,
                        checked: widget.consentCareNotice,
                        onChanged: widget.onCareNoticeChanged,
                      ),
                      const SizedBox(height: 10),
                      _MandatoryAccordion(
                        title: ChartConsentTexts.mandatoryReactionTitle,
                        bullets: ChartConsentTexts.mandatoryReactionBody,
                        checked: widget.consentAbnormalReaction,
                        onChanged: widget.onAbnormalReactionChanged,
                      ),
                      const SizedBox(height: 10),
                      _MandatoryAccordion(
                        title: ChartConsentTexts.mandatoryRefundTitle,
                        bullets: ChartConsentTexts.mandatoryRefundBody,
                        checked: widget.consentRefundPolicy,
                        onChanged: widget.onRefundPolicyChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _ConsentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: widget.consentPhoto,
                      onChanged: (v) => widget.onPhotoChanged(v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: MyApp.soriPurple,
                      title: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '[선택] ',
                              style: TextStyle(
                                color: MyApp.soriPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ChartConsentTexts.optionalPhotoTitle,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.consentPhoto) ...[
                      const Divider(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          '활용 범위 (택 1)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 4,
                          bottom: 8,
                        ),
                        child: Column(
                          children: [
                            _PhotoUseOption(
                              selected: widget.consentMarketing,
                              title: ChartConsentTexts.photoUseMarketing,
                              onTap: widget.onMarketingSelected,
                            ),
                            const SizedBox(height: 8),
                            _PhotoUseOption(
                              selected: widget.consentOfflineOnly,
                              title: ChartConsentTexts.photoUseOffline,
                              onTap: widget.onOfflineOnlySelected,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.quickChartMode &&
                  widget.existingSignatureUrl != null &&
                  widget.existingSignatureUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '이전에 저장된 서명이 있습니다. 새로 서명하면 교체됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
            ),
          ),
        ),
        if (!widget.quickChartMode)
          _ConsentValidationBlock(
            anchorKey: widget.signatureFieldKey,
            highlighted: widget.highlightSignature,
            showError: widget.showSignatureError,
            errorText: widget.signatureErrorText,
            shake: widget.shakeAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        '고객 서명',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: widget.onClearSignature,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('다시 쓰기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.highlightSignature ||
                                widget.showSignatureError
                            ? const Color(0xFFE53935)
                            : Colors.grey.shade300,
                        width: widget.highlightSignature ||
                                widget.showSignatureError
                            ? 1.6
                            : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _SignatureGestureSurface(
                      onPointerActive: _setSignaturePointerActive,
                      child: Signature(
                        controller: widget.signatureController,
                        backgroundColor: const Color(0xFFF8F7FC),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '손가락 또는 터치펜으로 서명해 주세요 (필수)',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            color: const Color(0xFFE8F8EF),
            child: const Text(
              '서명 패드 생략 · 기존 1년 포괄 동의를 재사용합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
      ],
    );
  }
}

/// 서명 패드 포인터를 가로채 부모 스크롤/PageView로 버블링되지 않게 한다.
class _SignatureGestureSurface extends StatelessWidget {
  const _SignatureGestureSurface({
    required this.onPointerActive,
    required this.child,
  });

  final ValueChanged<bool> onPointerActive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerActive(true),
      onPointerMove: (_) => onPointerActive(true),
      onPointerUp: (_) => onPointerActive(false),
      onPointerCancel: (_) => onPointerActive(false),
      child: child,
    );
  }
}

class _MandatoryAccordion extends StatefulWidget {
  const _MandatoryAccordion({
    required this.title,
    required this.bullets,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final List<String> bullets;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  State<_MandatoryAccordion> createState() => _MandatoryAccordionState();
}

class _MandatoryAccordionState extends State<_MandatoryAccordion> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return _ConsentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: widget.checked,
                  activeColor: MyApp.soriPurple,
                  onChanged: (v) {
                    final next = v ?? false;
                    widget.onChanged(next);
                    if (next && !_expanded) {
                      setState(() => _expanded = true);
                    }
                  },
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '[필수] ',
                                style: TextStyle(
                                  color: Color(0xFFC62828),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.35,
                                  color: SoriTokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _expanded ? '내용 접기' : '내용 보기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MyApp.soriPurple.withValues(alpha: 0.95),
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: MyApp.soriPurple,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in widget.bullets) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '· ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      height: 1.45,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.45,
                                        color: SoriTokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _PhotoUseOption extends StatelessWidget {
  const _PhotoUseOption({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MyApp.soriPurple.withValues(alpha: 0.08)
          : const Color(0xFFF8F7FC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? MyApp.soriPurple : Colors.grey.shade500,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _ConsentValidationBlock extends StatelessWidget {
  const _ConsentValidationBlock({
    required this.child,
    required this.highlighted,
    required this.showError,
    required this.errorText,
    this.anchorKey,
    this.shake,
  });

  final GlobalKey? anchorKey;
  final bool highlighted;
  final bool showError;
  final String errorText;
  final Animation<double>? shake;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (shake != null) {
      content = AnimatedBuilder(
        animation: shake!,
        builder: (context, child) {
          final dx = highlighted ? shake!.value : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: content,
      );
    }

    return KeyedSubtree(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(highlighted ? 3 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFFE53935)
                    : Colors.transparent,
                width: highlighted ? 1.5 : 0,
              ),
            ),
            child: content,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: showError
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: Text(
                        '* $errorText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
