import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../models/customer_merge_preview.dart';
import '../routing/sori_router.dart';
import '../services/customer_merge_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/my_app.dart';
import '../utils/remote_error_message.dart';
import '../utils/sori_bottom_sheet.dart';

/// 상세 페이지 등 1명만 있는 경우 — 추가 고객 선택 후 병합.
Future<List<Customer>?> pickCustomersForMerge({
  required BuildContext context,
  required SoriStore store,
  required Customer seed,
}) async {
  final others = store.customers.where((c) => c.id != seed.id).toList();
  if (others.isEmpty) {
    _showMergeSnackBar(
      context,
      '병합할 다른 고객이 없습니다.',
    );
    return null;
  }

  final picked = <String>{seed.id};
  return showModalBottomSheet<List<Customer>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: SoriTokens.surface,
    builder: (ctx) {
      return Padding(
        padding: soriSheetSafePadding(ctx),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '병합할 중복 고객 선택',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '유지할 고객: ${seed.name} (${seed.phone})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: others.map((c) {
                        final checked = picked.contains(c.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                picked.add(c.id);
                              } else {
                                picked.remove(c.id);
                              }
                            });
                          },
                          title: Text(c.name),
                          subtitle: Text(c.phone),
                        );
                      }).toList(),
                    ),
                  ),
                  FilledButton(
                    onPressed: picked.length < 2
                        ? null
                        : () {
                            final selected = store.customers
                                .where((c) => picked.contains(c.id))
                                .toList();
                            Navigator.pop(ctx, selected);
                          },
                    child: Text('선택 완료 (${picked.length}명)'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

void _showMergeSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 8),
}) {
  final messenger =
      MyApp.scaffoldMessengerKey.currentState ??
      ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? SoriTokens.systemRed : null,
    ),
  );
}

/// 중복 고객 병합 3단계 마법사.
Future<bool> showCustomerMergeWizard({
  required BuildContext context,
  required SoriStore store,
  required List<Customer> selected,
}) {
  // BottomSheet context가 아닌 부모 ScaffoldMessenger — SnackBar가 가려지지 않음.
  final hostContext = context;
  final navigator = Navigator.of(hostContext);

  return showModalBottomSheet<bool>(
    context: hostContext,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CustomerMergeWizard(
      store: store,
      selected: selected,
      hostContext: hostContext,
      sheetNavigator: navigator,
    ),
  ).then((v) => v ?? false);
}

class _CustomerMergeWizard extends StatefulWidget {
  const _CustomerMergeWizard({
    required this.store,
    required this.selected,
    required this.hostContext,
    required this.sheetNavigator,
  });

  final SoriStore store;
  final List<Customer> selected;
  final BuildContext hostContext;
  final NavigatorState sheetNavigator;

  @override
  State<_CustomerMergeWizard> createState() => _CustomerMergeWizardState();
}

class _CustomerMergeWizardState extends State<_CustomerMergeWizard> {
  late int _step;
  late String _primaryId;
  late CustomerMergePreview _preview;
  bool _merging = false;
  String? _inlineError;
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _step = 0;
    _primaryId = CustomerMergeService.suggestPrimaryId(widget.selected);
    _rebuildPreview();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _rebuildPreview() {
    _preview = CustomerMergeService.buildPreview(
      selected: widget.selected,
      charts: widget.store.charts,
      reviews: widget.store.reviews,
      primaryId: _primaryId,
    );
  }

  bool get _confirmNameOk => CustomerMergeService.confirmNameMatches(
        _confirmController.text,
        _preview.primaryName,
      );

  void _toast(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 8),
  }) {
    if (!widget.hostContext.mounted) return;
    _showMergeSnackBar(
      widget.hostContext,
      message,
      isError: isError,
      duration: duration,
    );
  }

  Future<void> _onMergePressed() async {
    if (_merging) return;

    if (!_confirmNameOk) {
      setState(() {
        _inlineError =
            '이름이 일치하지 않습니다. "${_preview.primaryName.trim()}" 을(를) 입력해 주세요.';
      });
      _toast(_inlineError!, isError: true);
      return;
    }

    setState(() {
      _merging = true;
      _inlineError = null;
    });

    final sources = widget.selected
        .map((c) => c.id)
        .where((id) => id != _primaryId)
        .toList();

    try {
      await widget.store.mergeShopCustomers(
        primaryId: _primaryId,
        sourceIds: sources,
      );

      if (!mounted) return;

      widget.sheetNavigator.pop(true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.hostContext.mounted) return;
        _toast(
          '${_preview.primaryName.trim()} 계정으로 ${sources.length}명 병합 완료',
        );
        GoRouter.of(widget.hostContext)
            .push(AppPaths.customerDetail(_primaryId));
      });
    } catch (e, st) {
      debugPrint('mergeShopCustomers failed: $e\n$st');
      if (!mounted) return;
      final msg = formatRemoteError(e);
      setState(() {
        _inlineError = msg;
      });
      _toast('병합 실패\n$msg', isError: true, duration: const Duration(seconds: 12));
    } finally {
      if (mounted) {
        setState(() => _merging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    // Cap height so Flexible cannot expand into a full white overlay when the
    // keyboard opens (isScrollControlled sheets otherwise get unbounded height).
    final maxHeight = (mq.size.height - bottomInset) * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SoriTokens.outlinePurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  switch (_step) {
                    0 => '1/3 · 유지할 계정 선택',
                    1 => '2/3 · 병합 미리보기',
                    _ => '3/3 · 최종 확인',
                  },
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: switch (_step) {
                      0 => _buildStepPrimary(),
                      1 => _buildStepPreview(),
                      _ => _buildStepConfirm(),
                    },
                  ),
                ),
                if (_inlineError != null && _step == 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    _inlineError!,
                    style: const TextStyle(
                      color: SoriTokens.systemRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed:
                            _merging ? null : () => setState(() => _step--),
                        child: const Text('이전'),
                      ),
                    const Spacer(),
                    if (_step < 2)
                      FilledButton(
                        onPressed:
                            _merging ? null : () => setState(() => _step++),
                        child: const Text('다음'),
                      )
                    else
                      FilledButton(
                        onPressed: _merging ? null : _onMergePressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primaryDark,
                          disabledBackgroundColor:
                              SoriTokens.primaryDark.withValues(
                            alpha: _merging ? 0.45 : 1,
                          ),
                        ),
                        child: Text(_merging ? '병합 중…' : '병합 실행'),
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

  Widget _buildStepPrimary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '선택한 유지 계정만 남습니다. 나머지는 삭제되며 데이터는 이전됩니다.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ..._preview.candidates.map((c) {
          final isPrimary = c.customer.id == _primaryId;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isPrimary ? SoriTokens.primary : SoriTokens.outlinePurple,
                width: isPrimary ? 2 : 1,
              ),
            ),
            child: RadioListTile<String>(
              value: c.customer.id,
              groupValue: _primaryId,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _primaryId = v;
                  _rebuildPreview();
                });
              },
              title: Text(
                c.customer.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${c.customer.phone}\n'
                '차트 ${c.chartCount}건 · 후기 ${c.reviewCount}건 · 잔여 ${c.membershipRemain}회',
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_preview.phoneMismatch)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: SoriTokens.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.warningText.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: SoriTokens.warningText),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '전화번호가 다릅니다. 동일 인물인지 다시 확인해 주세요.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.warningText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _PreviewRow(
          label: '병합 후 차트',
          value: '${_preview.totalChartsAfter}건 (visit_number 재정렬)',
        ),
        _PreviewRow(
          label: '병합 후 후기',
          value: '${_preview.totalReviewsAfter}건',
        ),
        const _PreviewRow(
          label: 'B/A 사진',
          value: '전량 보존 (차트 URL 유지)',
        ),
        const _PreviewRow(
          label: '회원권 전략',
          value: 'combine_by_name (동일 서비스 합산)',
        ),
        const SizedBox(height: 8),
        if (_preview.mergedMemberships.isNotEmpty) ...[
          const Text(
            '병합 후 회원권',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 6),
          ..._preview.mergedMemberships.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${m.serviceName}: 총 ${m.totalVisits}회 / 사용 ${m.usedVisits}회 / 잔여 ${m.remainingVisits}회',
                style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'B2C Wallet(포인트) 잔액은 유지할 계정으로 합산됩니다.',
          style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStepConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SoriTokens.systemRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SoriTokens.systemRed.withValues(alpha: 0.35)),
          ),
          child: Text(
            '병합되는 ${_preview.sourceCount}명의 고객 정보는 영구 삭제됩니다. 되돌릴 수 없습니다.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: SoriTokens.systemRed,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '확인을 위해 "${_preview.primaryName.trim()}" 을(를) 입력해 주세요.',
          style: const TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmController,
          onChanged: (_) => setState(() {
            if (_inlineError != null && _confirmNameOk) {
              _inlineError = null;
            }
          }),
          decoration: InputDecoration(
            hintText: '유지할 고객의 이름',
            border: const OutlineInputBorder(),
            errorText: _confirmNameOk || _confirmController.text.isEmpty
                ? null
                : '입력값이 유지할 고객의 이름과 다릅니다.',
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
