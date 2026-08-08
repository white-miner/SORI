import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';
import '../models/shop_gallery_slide.dart';

/// 앱 초기 로드용 스냅샷 (Repository → Store).
class SoriSnapshot {
  const SoriSnapshot({
    required this.shop,
    required this.customers,
    required this.charts,
    required this.reviews,
    required this.aiReplies,
    required this.gallerySlides,
    this.todayHomecareTip =
        '미지근한 물로 가볍게 클렌징하고, 보습 세럼을 손바닥 온기로 펴 발라 주세요.',
    this.reviewRequestedCustomerIds = const {},
  });

  final Shop shop;
  final List<Customer> customers;
  final List<CustomerChart> charts;
  final List<CustomerReview> reviews;
  final List<AiReply> aiReplies;
  final List<ShopGallerySlide> gallerySlides;
  final String todayHomecareTip;
  final Set<String> reviewRequestedCustomerIds;
}

/// 데이터 소스 추상화 (Memory | Supabase).
abstract class SoriRepository {
  bool get isRemote;

  Future<SoriSnapshot> loadInitialData();
}
