import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';

/// 전국/단골 B/A 커뮤니티 피드 항목.
class CommunityCaseItem {
  const CommunityCaseItem({
    required this.chart,
    required this.shop,
    this.review,
  });

  final CustomerChart chart;
  final Shop shop;
  final CustomerReview? review;

  bool get hasVerifiedReview =>
      review != null && review!.displayText.trim().isNotEmpty;
}
