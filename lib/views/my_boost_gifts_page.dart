import 'package:flutter/material.dart';

import '../models/boost_contribution_report.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';

/// 고객 — 내가 후원한 케이스 + 기여 리포트 (E5-lite).
class MyBoostGiftsPage extends StatefulWidget {
  const MyBoostGiftsPage({super.key, required this.store});

  final SoriStore store;

  static Future<void> open(BuildContext context, {required SoriStore store}) {
    return pushRootPage<void>(
      context,
      MyBoostGiftsPage(store: store),
    );
  }

  @override
  State<MyBoostGiftsPage> createState() => _MyBoostGiftsPageState();
}

class _MyBoostGiftsPageState extends State<MyBoostGiftsPage> {
  SoriStore get store => widget.store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await store.refreshMyBoostGifts();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = store.boostGiftImpactReports;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('내가 후원한 케이스'),
        backgroundColor: SoriTokens.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SoriTokens.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            '아직 후원한 케이스가 없어요.\n피드에서 원장님 케이스를 응원해 보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: SoriTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '후원한 케이스가 비슷한 고민을 가진 분들에게 더 잘 보이도록 도와줍니다.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: SoriTokens.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          );
                        }
                        final g = items[i - 1];
                        return _BoostGiftImpactTile(report: g);
                      },
                    ),
            ),
    );
  }
}

class _BoostGiftImpactTile extends StatelessWidget {
  const _BoostGiftImpactTile({required this.report});

  final BoostGiftImpactReport report;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        title: Text(
          report.caseTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${report.shopName} · ${report.tierLabel} · ${report.echoSpent}E',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              report.impactLine,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: report.boostStillActive
                    ? SoriTokens.primary
                    : SoriTokens.textSecondary,
              ),
            ),
            if (report.hasThankYou) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: Color(0xFFF472B6),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '원장님 감사 위스퍼 도착',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: report.hasThankYou
            ? const Icon(
                Icons.mark_email_read_outlined,
                color: SoriTokens.textSecondary,
              )
            : Icon(
                report.boostStillActive
                    ? Icons.trending_up_rounded
                    : Icons.local_fire_department_rounded,
                color: report.boostStillActive
                    ? SoriTokens.primary
                    : const Color(0xFFF472B6),
              ),
      ),
    );
  }
}
