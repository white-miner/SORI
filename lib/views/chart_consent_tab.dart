import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../theme/sori_tokens.dart';
import 'my_app.dart';

/// 전자 동의서 체크 + 하단 고정 서명 패드.
class ChartConsentTab extends StatelessWidget {
  const ChartConsentTab({
    super.key,
    required this.consentMandatory,
    required this.consentPhoto,
    required this.consentMarketing,
    required this.consentOfflineOnly,
    required this.signatureController,
    required this.onMandatoryChanged,
    required this.onPhotoChanged,
    required this.onMarketingSelected,
    required this.onOfflineOnlySelected,
    required this.onClearSignature,
    this.existingSignatureUrl,
  });

  final bool consentMandatory;
  final bool consentPhoto;
  final bool consentMarketing;
  final bool consentOfflineOnly;
  final SignatureController signatureController;
  final ValueChanged<bool> onMandatoryChanged;
  final ValueChanged<bool> onPhotoChanged;
  final VoidCallback onMarketingSelected;
  final VoidCallback onOfflineOnlySelected;
  final VoidCallback onClearSignature;
  final String? existingSignatureUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  '시술 전 고객 확인용 전자 동의서입니다. 작성하지 않아도 차트만 저장할 수 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ConsentCard(
                child: CheckboxListTile(
                  value: consentMandatory,
                  onChanged: (v) => onMandatoryChanged(v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: MyApp.soriPurple,
                  title: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '[필수] ',
                          style: TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '부작용 및 시술 주의사항 안내 동의',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  subtitle: const Text(
                    '시술 과정·주의사항·예상 부작용에 대한 설명을 듣고 이해했습니다.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ConsentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: consentPhoto,
                      onChanged: (v) => onPhotoChanged(v ?? false),
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
                              text: '시술 전/중/후 임상 사진 및 영상 촬영 동의',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (consentPhoto) ...[
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
                        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                        child: Column(
                          children: [
                            _PhotoUseOption(
                              selected: consentMarketing,
                              title: '온라인 마케팅 활용 동의 (SNS 등 / 눈 가림 처리)',
                              onTap: onMarketingSelected,
                            ),
                            const SizedBox(height: 8),
                            _PhotoUseOption(
                              selected: consentOfflineOnly,
                              title: '오프라인 상담 전용 (원내부 차트 기록용)',
                              onTap: onOfflineOnlySelected,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (existingSignatureUrl != null &&
                  existingSignatureUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '이전에 저장된 서명이 있습니다. 새로 서명하면 교체됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        Container(
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onClearSignature,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시 쓰기'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: Signature(
                  controller: signatureController,
                  backgroundColor: const Color(0xFFF8F7FC),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '손가락 또는 터치펜으로 서명해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
