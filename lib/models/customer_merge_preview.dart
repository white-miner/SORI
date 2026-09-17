import '../models/customer.dart';
import '../models/customer_membership.dart';

/// 병합 미리보기 DTO (Step 2 마법사).
class CustomerMergePreview {
  const CustomerMergePreview({
    required this.candidates,
    required this.suggestedPrimaryId,
    required this.phoneMismatch,
    required this.totalChartsAfter,
    required this.totalReviewsAfter,
    required this.mergedMemberships,
    required this.primaryName,
  });

  final List<CustomerMergeCandidate> candidates;
  final String suggestedPrimaryId;
  final bool phoneMismatch;
  final int totalChartsAfter;
  final int totalReviewsAfter;
  final List<CustomerMembership> mergedMemberships;
  final String primaryName;

  int get sourceCount => candidates.length - 1;
}

class CustomerMergeCandidate {
  const CustomerMergeCandidate({
    required this.customer,
    required this.chartCount,
    required this.reviewCount,
    required this.membershipRemain,
  });

  final Customer customer;
  final int chartCount;
  final int reviewCount;
  final int membershipRemain;
}

class CustomerMergeResult {
  const CustomerMergeResult({
    required this.primaryId,
    required this.mergedIds,
    required this.chartsTotal,
    required this.reviewsMoved,
    required this.walletsMerged,
  });

  factory CustomerMergeResult.fromMap(Map<String, dynamic> map) {
    final mergedRaw = map['merged_ids'];
    final mergedIds = <String>[];
    if (mergedRaw is List) {
      for (final item in mergedRaw) {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty) mergedIds.add(id);
      }
    }
    return CustomerMergeResult(
      primaryId: map['primary_id']?.toString() ?? '',
      mergedIds: mergedIds,
      chartsTotal: (map['charts_total'] as num?)?.toInt() ?? 0,
      reviewsMoved: (map['reviews_moved'] as num?)?.toInt() ?? 0,
      walletsMerged: (map['wallets_merged'] as num?)?.toInt() ?? 0,
    );
  }

  final String primaryId;
  final List<String> mergedIds;
  final int chartsTotal;
  final int reviewsMoved;
  final int walletsMerged;
}
