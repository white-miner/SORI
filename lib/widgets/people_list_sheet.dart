import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/fan_supporter.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/my_page_fandom_hub.dart';

enum PeopleListKind { follower, supporter, following }

/// 마이페이지 지표 Click-to-Modal — Follower / Supporter / Following.
Future<void> showPeopleListSheet(
  BuildContext context, {
  required SoriStore store,
  required PeopleListKind kind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PeopleListSheet(store: store, kind: kind),
  );
}

class _PeopleListSheet extends StatefulWidget {
  const _PeopleListSheet({required this.store, required this.kind});

  final SoriStore store;
  final PeopleListKind kind;

  @override
  State<_PeopleListSheet> createState() => _PeopleListSheetState();
}

class _PeopleListSheetState extends State<_PeopleListSheet> {
  bool _loading = true;
  List<_PersonRow> _rows = const [];

  String get _title => switch (widget.kind) {
        PeopleListKind.follower => 'Follower',
        PeopleListKind.supporter => 'Supporter',
        PeopleListKind.following => 'Following',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final store = widget.store;
    final rows = <_PersonRow>[];

    switch (widget.kind) {
      case PeopleListKind.supporter:
        await store.refreshShopSupporterHeader();
        for (final s in FanSupporterEntry.ranked(store.shopSupporterHeader.facepile)) {
          rows.add(_PersonRow(
            id: s.customerId ?? '',
            name: s.name.trim().isEmpty ? 'Supporter' : s.name.trim(),
            subtitle: '${s.echoSpent}E',
            avatarUrl: s.avatarUrl,
            routeKind: _PersonRouteKind.customer,
          ));
        }
        break;
      case PeopleListKind.follower:
        await store.refreshShopSupporterHeader();
        final n = store.shopSupporterHeader.followerCount;
        if (n > 0) {
          rows.add(_PersonRow(
            id: 'followers',
            name: 'Follower $n',
            subtitle: 'Open Follower hub',
            routeKind: _PersonRouteKind.fandomHub,
          ));
        }
        break;
      case PeopleListKind.following:
        await store.refreshDiscoverDirectors(soft: true);
        for (final id in store.followedShopIds) {
          final hit = store.discoverDirectors.where((d) => d.shopId == id);
          final d = hit.isEmpty ? null : hit.first;
          rows.add(_PersonRow(
            id: id,
            name: d?.shopName.trim().isNotEmpty == true
                ? d!.shopName.trim()
                : 'Shop',
            subtitle: d?.nickname.trim() ?? '',
            avatarUrl: d?.avatarUrl,
            routeKind: _PersonRouteKind.fandomHub,
          ));
        }
        break;
    }

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _openRow(_PersonRow row) async {
    Navigator.pop(context);
    switch (row.routeKind) {
      case _PersonRouteKind.customer:
        final cid = row.id.trim();
        if (cid.isEmpty) return;
        if (!context.mounted) return;
        context.go(AppPaths.customerDetail(cid));
      case _PersonRouteKind.fandomHub:
        if (!context.mounted) return;
        await MyPageFandomHubPage.open(context, store: widget.store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.62;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SoriTokens.primary,
                      ),
                    )
                  : _rows.isEmpty
                      ? const Center(
                          child: Text(
                            'No entries yet.',
                            style: TextStyle(
                              color: SoriTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final row = _rows[i];
                            return ListTile(
                              onTap: () => _openRow(row),
                              leading: CircleAvatar(
                                backgroundColor: SoriTokens.primarySoft,
                                backgroundImage:
                                    (row.avatarUrl?.startsWith('http') ??
                                            false)
                                        ? NetworkImage(row.avatarUrl!)
                                        : null,
                                child: (row.avatarUrl?.startsWith('http') ??
                                        false)
                                    ? null
                                    : Text(
                                        row.name.characters.first,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: SoriTokens.primary,
                                        ),
                                      ),
                              ),
                              title: Text(
                                row.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: row.subtitle.isEmpty
                                  ? null
                                  : Text(
                                      row.subtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: SoriTokens.textSecondary,
                                      ),
                                    ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: SoriTokens.textSecondary,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PersonRouteKind { customer, fandomHub }

class _PersonRow {
  const _PersonRow({
    required this.id,
    required this.name,
    required this.routeKind,
    this.subtitle = '',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final _PersonRouteKind routeKind;
}
