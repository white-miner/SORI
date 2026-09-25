import 'package:flutter/material.dart';

import '../../features/visit/visit_new_customer_form_page.dart';
import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'chart_workspace_state.dart';

/// CHART tab default first screen — search, today, recent, start new.
/// No No.N file rail / drawer rail on the default path.
class ChartEmptyDesk extends StatefulWidget {
  const ChartEmptyDesk({
    super.key,
    required this.store,
    required this.onSelectCustomer,
  });

  final SoriStore store;
  final ValueChanged<Customer> onSelectCustomer;

  @override
  State<ChartEmptyDesk> createState() => _ChartEmptyDeskState();
}

class _ChartEmptyDeskState extends State<ChartEmptyDesk> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Customer> get _todayCustomers {
    final out = <Customer>[];
    for (final c in widget.store.customers) {
      if (todayChartForCustomer(widget.store, c.id) != null) {
        out.add(c);
      }
    }
    out.sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    return out;
  }

  List<Customer> get _recentCustomers {
    final all = List<Customer>.of(widget.store.customers)
      ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    return all.take(5).toList();
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return widget.store.customers.where((c) {
      final name = c.name.toLowerCase();
      final phone = c.phone.replaceAll(RegExp(r'\D'), '');
      return name.contains(q) ||
          (digits.isNotEmpty && phone.contains(digits));
    }).toList();
  }

  Future<void> _startNewCustomer() async {
    final saved = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => VisitNewCustomerFormPage(store: widget.store),
      ),
    );
    if (!mounted || saved == null) return;
    widget.onSelectCustomer(saved);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final today = _todayCustomers;
    final recent = _recentCustomers;
    final hits = _filtered;

    return ColoredBox(
      key: const Key('chart-empty-desk'),
      color: SoriTokens.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          TextField(
            key: const Key('chart-empty-desk-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '이름 또는 연락처 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: SoriTokens.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SoriTokens.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SoriTokens.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SoriTokens.textCharcoal),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (searching) ...[
            const _SectionLabel(label: '검색 결과'),
            const SizedBox(height: 8),
            if (hits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '일치하는 고객이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              )
            else
              _CustomerCardList(
                customers: hits,
                keyPrefix: 'chart-empty-desk-hit',
                onTap: widget.onSelectCustomer,
              ),
          ] else ...[
            if (today.isNotEmpty) ...[
              const _SectionLabel(label: '오늘'),
              const SizedBox(height: 8),
              _CustomerCarousel(
                customers: today,
                keyPrefix: 'chart-empty-desk-today',
                onTap: widget.onSelectCustomer,
              ),
              const SizedBox(height: 16),
            ],
            const _SectionLabel(label: '최근'),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '최근 고객이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              )
            else
              _CustomerCarousel(
                customers: recent,
                keyPrefix: 'chart-empty-desk-recent',
                onTap: widget.onSelectCustomer,
              ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton(
              key: const Key('chart-empty-desk-new-start'),
              onPressed: _startNewCustomer,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                foregroundColor: SoriTokens.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '신규로 시작',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: SoriTokens.textTertiary,
      ),
    );
  }
}

/// Horizontal compact-card carousel for 오늘 / 최근.
class _CustomerCarousel extends StatelessWidget {
  const _CustomerCarousel({
    required this.customers,
    required this.keyPrefix,
    required this.onTap,
  });

  final List<Customer> customers;
  final String keyPrefix;
  final ValueChanged<Customer> onTap;

  static const double _cardWidth = 150;
  static const double _rowHeight = 88;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: customers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final c = customers[index];
          return SizedBox(
            width: _cardWidth,
            child: _CompactCustomerCard(
              key: Key('$keyPrefix-${c.id}'),
              customer: c,
              onTap: () => onTap(c),
            ),
          );
        },
      ),
    );
  }
}

class _CompactCustomerCard extends StatelessWidget {
  const _CompactCustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final Customer customer;
  final VoidCallback onTap;

  String get _subtitle {
    final phone = customer.phone.trim();
    if (phone.isNotEmpty) {
      return phone.length > 13 ? '${phone.substring(0, 13)}…' : phone;
    }
    final d = customer.lastTreatmentDate;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical list — kept for temporary 검색 결과.
class _CustomerCardList extends StatelessWidget {
  const _CustomerCardList({
    required this.customers,
    required this.keyPrefix,
    required this.onTap,
  });

  final List<Customer> customers;
  final String keyPrefix;
  final ValueChanged<Customer> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in customers) ...[
          _CustomerCard(
            key: Key('$keyPrefix-${c.id}'),
            customer: c,
            onTap: () => onTap(c),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone.trim();
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textCharcoal,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
