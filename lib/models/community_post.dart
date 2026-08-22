import '../utils/db_map.dart';

/// B2B Community 포스트 유형.
enum CommunityPostType {
  interior,
  deviceReview,
  marketplace,
  caseShare,
  seminar;

  String get dbValue => switch (this) {
        CommunityPostType.interior => 'interior',
        CommunityPostType.deviceReview => 'device_review',
        CommunityPostType.marketplace => 'marketplace',
        CommunityPostType.caseShare => 'case_share',
        CommunityPostType.seminar => 'seminar',
      };

  String get label => switch (this) {
        CommunityPostType.interior => '인테리어',
        CommunityPostType.deviceReview => '기기 리뷰',
        CommunityPostType.marketplace => '중고',
        CommunityPostType.caseShare => '케이스',
        CommunityPostType.seminar => '세미나',
      };

  static CommunityPostType fromDb(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return switch (v) {
      'device_review' || 'device-review' => CommunityPostType.deviceReview,
      'marketplace' || 'market' => CommunityPostType.marketplace,
      'case_share' || 'case' => CommunityPostType.caseShare,
      'seminar' => CommunityPostType.seminar,
      _ => CommunityPostType.interior,
    };
  }
}

enum MarketListingStatus {
  draft,
  active,
  reserved,
  sold,
  hidden,
  removed;

  String get dbValue => name;

  String get label => switch (this) {
        MarketListingStatus.draft => '초안',
        MarketListingStatus.active => '판매 중',
        MarketListingStatus.reserved => '예약 중',
        MarketListingStatus.sold => '거래 완료',
        MarketListingStatus.hidden => '숨김',
        MarketListingStatus.removed => '삭제',
      };

  static MarketListingStatus fromDb(String? raw) {
    final v = (raw ?? 'active').trim().toLowerCase();
    return MarketListingStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => MarketListingStatus.active,
    );
  }
}

class CommunityPostMedia {
  const CommunityPostMedia({
    required this.id,
    required this.postId,
    required this.imageUrl,
    this.sortOrder = 0,
    this.width,
    this.height,
  });

  final String id;
  final String postId;
  final String imageUrl;
  final int sortOrder;
  final int? width;
  final int? height;

  factory CommunityPostMedia.fromMap(Map<String, dynamic> map) {
    return CommunityPostMedia(
      id: DbMap.asText(map['id']),
      postId: DbMap.asText(map['post_id'] ?? map['postId']),
      imageUrl: DbMap.asText(map['image_url'] ?? map['imageUrl']),
      sortOrder: DbMap.asInt(map['sort_order'] ?? map['sortOrder']),
      width: () {
        final v = map['width'];
        if (v == null) return null;
        return DbMap.asInt(v);
      }(),
      height: () {
        final v = map['height'];
        if (v == null) return null;
        return DbMap.asInt(v);
      }(),
    );
  }
}

/// 인테리어 핫스팟 / 외부 링크 태그 (Affiliate Phase 3).
class CommunityPostTag {
  const CommunityPostTag({
    required this.id,
    required this.mediaId,
    required this.label,
    this.tagKind = 'product',
    this.normX = 0.5,
    this.normY = 0.5,
    this.partnerId,
    this.externalUrl,
  });

  final String id;
  final String mediaId;
  final String tagKind;
  final String label;
  final double normX;
  final double normY;
  final String? partnerId;
  final String? externalUrl;

  factory CommunityPostTag.fromMap(Map<String, dynamic> map) {
    return CommunityPostTag(
      id: DbMap.asText(map['id']),
      mediaId: DbMap.asText(map['media_id'] ?? map['mediaId']),
      tagKind: DbMap.asText(map['tag_kind'] ?? map['tagKind'], 'product'),
      label: DbMap.asText(map['label']),
      normX: () {
        final v = map['norm_x'] ?? map['normX'];
        if (v is num) return v.toDouble().clamp(0.0, 1.0).toDouble();
        return 0.5;
      }(),
      normY: () {
        final v = map['norm_y'] ?? map['normY'];
        if (v is num) return v.toDouble().clamp(0.0, 1.0).toDouble();
        return 0.5;
      }(),
      partnerId: DbMap.asTextOrNull(map['partner_id'] ?? map['partnerId']),
      externalUrl: DbMap.asTextOrNull(
        map['external_url'] ?? map['externalUrl'],
      ),
    );
  }
}

class MarketListing {
  const MarketListing({
    required this.id,
    required this.postId,
    required this.shopId,
    required this.deviceName,
    this.brand = '',
    this.model = '',
    this.price = 0,
    this.condition = 'good',
    this.status = MarketListingStatus.active,
    this.contactPhone,
    this.contactNote = '',
    this.region,
  });

  final String id;
  final String postId;
  final String shopId;
  final String deviceName;
  final String brand;
  final String model;
  final int price;
  final String condition;
  final MarketListingStatus status;
  final String? contactPhone;
  final String contactNote;
  final String? region;

  factory MarketListing.fromMap(Map<String, dynamic> map) {
    return MarketListing(
      id: DbMap.asText(map['id']),
      postId: DbMap.asText(map['post_id'] ?? map['postId']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      deviceName: DbMap.asText(map['device_name'] ?? map['deviceName']),
      brand: DbMap.asText(map['brand']),
      model: DbMap.asText(map['model']),
      price: DbMap.asInt(map['price']),
      condition: DbMap.asText(map['condition'], 'good'),
      status: MarketListingStatus.fromDb(
        DbMap.asText(map['listing_status'] ?? map['listingStatus']),
      ),
      contactPhone: DbMap.asTextOrNull(
        map['contact_phone'] ?? map['contactPhone'],
      ),
      contactNote: DbMap.asText(map['contact_note'] ?? map['contactNote']),
      region: DbMap.asTextOrNull(map['region']),
    );
  }
}

/// Community 피드 카드용 집계 모델.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.shopId,
    required this.postType,
    required this.body,
    this.authorUserId,
    this.title = '',
    this.styleTags = const [],
    this.regionCode,
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    this.media = const [],
    this.tags = const [],
    this.listing,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String? authorUserId;
  final CommunityPostType postType;
  final String title;
  final String body;
  final List<String> styleTags;
  final String? regionCode;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final List<CommunityPostMedia> media;
  final List<CommunityPostTag> tags;
  final MarketListing? listing;
  final DateTime? createdAt;

  String? get primaryImageUrl {
    for (final m in media) {
      final u = m.imageUrl.trim();
      if (u.startsWith('http') || u.startsWith('data:')) return u;
    }
    return null;
  }

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    final mediaRaw = map['post_media'] ?? map['media'];
    final media = <CommunityPostMedia>[];
    if (mediaRaw is List) {
      for (final e in mediaRaw) {
        if (e is Map) {
          media.add(CommunityPostMedia.fromMap(Map<String, dynamic>.from(e)));
        }
      }
      media.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final tagsRaw = map['post_tags'] ?? map['tags'];
    final tags = <CommunityPostTag>[];
    if (tagsRaw is List) {
      for (final e in tagsRaw) {
        if (e is Map) {
          tags.add(CommunityPostTag.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    MarketListing? listing;
    final listingRaw = map['market_listings'] ?? map['listing'];
    if (listingRaw is Map) {
      listing = MarketListing.fromMap(Map<String, dynamic>.from(listingRaw));
    } else if (listingRaw is List && listingRaw.isNotEmpty) {
      final first = listingRaw.first;
      if (first is Map) {
        listing = MarketListing.fromMap(Map<String, dynamic>.from(first));
      }
    }

    return CommunityPost(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      authorUserId: DbMap.asTextOrNull(
        map['author_user_id'] ?? map['authorUserId'],
      ),
      postType: CommunityPostType.fromDb(
        DbMap.asText(map['post_type'] ?? map['postType']),
      ),
      title: DbMap.asText(map['title']),
      body: DbMap.asText(map['body']),
      styleTags: DbMap.asStringList(map['style_tags'] ?? map['styleTags']),
      regionCode: DbMap.asTextOrNull(map['region_code'] ?? map['regionCode']),
      likeCount: DbMap.asInt(map['like_count'] ?? map['likeCount']),
      commentCount: DbMap.asInt(map['comment_count'] ?? map['commentCount']),
      saveCount: DbMap.asInt(map['save_count'] ?? map['saveCount']),
      media: media,
      tags: tags,
      listing: listing,
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'shop_id': shopId,
        if (authorUserId != null && authorUserId!.isNotEmpty)
          'author_user_id': authorUserId,
        'post_type': postType.dbValue,
        'title': title.trim(),
        'body': body.trim(),
        'style_tags': styleTags,
        if (regionCode != null && regionCode!.trim().isNotEmpty)
          'region_code': regionCode!.trim(),
        'status': 'published',
        'visibility': 'public',
      };
}
