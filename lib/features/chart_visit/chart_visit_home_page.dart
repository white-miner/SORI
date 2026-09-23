import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/sori_router.dart';
import '../../theme/sori_tokens.dart';
import 'chart_visit_mock.dart';

/// 라우트 수명. 화면을 벗어나면 실제 고객 바인딩을 샘플로 되돌린다.
class ChartVisitRoutePage extends StatefulWidget {
  const ChartVisitRoutePage({super.key});

  @override
  State<ChartVisitRoutePage> createState() => _ChartVisitRoutePageState();
}

class _ChartVisitRoutePageState extends State<ChartVisitRoutePage> {
  @override
  void dispose() {
    ChartVisitPreviewStore.instance.detachIfLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ChartVisitHomePage();
}

/// 샘플 고객 차트 홈. 기존 [CustomerChartPage] 를 대체하지 않는다.
class ChartVisitHomePage extends StatelessWidget {
  const ChartVisitHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ChartVisitPreviewStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final customer = store.customer;
        final recent = store.history.isEmpty ? null : store.history.first;
        return Scaffold(
          key: const Key('chart-visit-home'),
          backgroundColor: SoriTokens.background,
          appBar: AppBar(
            backgroundColor: SoriTokens.background,
            foregroundColor: SoriTokens.textPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'CHART',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            actions: [
              if (!store.live)
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Center(
                    child: Text(
                      '샘플',
                      style: TextStyle(
                        color: SoriTokens.textTertiary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer.age > 0
                        ? '${customer.age}세 · ${customer.genderLabel}'
                        : customer.genderLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.phone,
                    style: const TextStyle(
                      fontSize: 16,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'CHECK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFFB4534A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customer.homeCheck,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (store.liveNotice.isNotEmpty) ...[
                    Text(
                      store.liveNotice,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFB4534A),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _PrimaryButton(
                    key: const Key('chart-visit-start'),
                    label: store.active == null ? '오늘 방문' : '이어서 작성',
                    onPressed: () {
                      _openTodayVisit(context, store);
                    },
                  ),
                  if (store.active != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('chart-visit-start-fresh'),
                      onPressed: () {
                        _startFreshVisit(context, store);
                      },
                      child: const Text(
                        '새 방문으로 시작',
                        style: TextStyle(
                          fontSize: 15,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  const Text(
                    'RECENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recent != null) ...[
                    Text(
                      recent.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatVisitFull(recent.date),
                      style: const TextStyle(
                        fontSize: 15,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Before',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'After',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _PhotoWell(tall: recent.hasPhotos),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PhotoWell(tall: recent.hasPhotos),
                        ),
                      ],
                    ),
                    if (recent.changeLine.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        recent.changeLine,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: SoriTokens.textPrimary,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 36),
                  const Text(
                    'HISTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final visit in store.history.skip(1))
                    _HistoryRow(visit: visit, key: Key('chart-visit-history-${visit.id}')),
                  const SizedBox(height: 18),
                  const Text(
                    '샘플 기록입니다. 서버에 저장되지 않습니다.',
                    style: TextStyle(fontSize: 13, color: SoriTokens.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({super.key, required this.visit});

  final PastVisit visit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatVisitDay(visit.date),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              visit.first ? '첫 방문' : visit.title,
              style: const TextStyle(fontSize: 16, color: SoriTokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.tall});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: tall ? const Color(0xFFE7E2DC) : const Color(0xFFF3F1EF),
        borderRadius: BorderRadius.circular(tall ? 18 : 12),
      ),
    );
    if (!tall) return SizedBox(height: 56, width: double.infinity, child: child);
    return AspectRatio(aspectRatio: 0.92, child: child);
  }
}

Future<void> _openTodayVisit(
  BuildContext context,
  ChartVisitPreviewStore store,
) async {
  if (!store.live) {
    if (store.active == null) store.startNewVisit();
    if (context.mounted) context.push(AppPaths.chartVisitWrite);
    return;
  }
  if (store.active != null) {
    context.push(AppPaths.chartVisitWrite);
    return;
  }
  if (store.drafts.isNotEmpty) {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('작성 중인 방문이 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'resume'),
              child: const Text('이어서 작성'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'fresh'),
              child: const Text('새 방문 시작'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || choice == null) return;
    final opened = choice == 'resume'
        ? await store.openLiveResume()
        : await store.openLiveFresh();
    if (!context.mounted || !opened) return;
    context.push(AppPaths.chartVisitWrite);
    return;
  }
  final opened = await store.openLiveFresh();
  if (!context.mounted || !opened) return;
  context.push(AppPaths.chartVisitWrite);
}

Future<void> _startFreshVisit(
  BuildContext context,
  ChartVisitPreviewStore store,
) async {
  if (store.live) {
    final opened = await store.openLiveFresh();
    if (!context.mounted || !opened) return;
  } else {
    store.startNewVisit();
  }
  if (context.mounted) context.push(AppPaths.chartVisitWrite);
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SoriTokens.brand,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: SoriTokens.onBrand,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
