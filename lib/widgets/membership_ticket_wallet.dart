import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/membership_ticket.dart';

/// 스마트 회원권 디지털 티켓 지갑 리스트.
class MembershipTicketWallet extends StatelessWidget {
  const MembershipTicketWallet({
    super.key,
    required this.tickets,
    this.onRefresh,
  });

  final List<MembershipTicket> tickets;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 36, color: Colors.grey[350]),
            const SizedBox(height: 10),
            Text(
              '보유 중인 회원권이 없어요',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '원장님이 회원권을 등록하면 지갑에 티켓이 쌓여요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => onRefresh?.call(),
                child: const Text('새로고침'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final t in tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TicketCard(ticket: t),
          ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final MembershipTicket ticket;

  Future<void> _book(BuildContext context) async {
    final url = ticket.naverPlaceUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '만료일 미등록';
    return '만료 ${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = ticket.isLow ? const Color(0xFFE17055) : const Color(0xFF6C5CE7);
    final soft = ticket.isLow ? const Color(0xFFFFF0EC) : const Color(0xFFEEF0FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: soft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (ticket.isLow)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '소진 임박',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  ticket.shopName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Icon(Icons.confirmation_number_rounded,
                  size: 18, color: accent.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.ticketName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '잔여 ${ticket.remainingVisits}회 / 총 ${ticket.totalVisits}회 · ${_fmtDate(ticket.expiresAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ticket.progress,
              minHeight: 9,
              backgroundColor: soft,
              color: accent,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: () => _book(context),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '이 티켓으로 샵 예약하기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
