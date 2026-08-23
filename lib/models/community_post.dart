import '../utils/db_map.dart';
import 'shop_tier_badge.dart';

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

/// Community 공개 범위 (Give & Take).
enum CommunityVisibility {
  public,
  directorsOnly,
  regionOnly,
  goldPlus;

  String get dbValue => switch (this) {
        CommunityVisibility.public => 'public',
        CommunityVisibility.directorsOnly => 'directors_only',
        CommunityVisibility.regionOnly => 'region_only',
        CommunityVisibility.goldPlus => 'gold_plus',
      };

  String get label => switch (this) {
        CommunityVisibility.public => '전체 공개',
        CommunityVisibility.directorsOnly => '원장만',
        CommunityVisibility.regionOnly => '지역만',
        CommunityVisibility.goldPlus => '골드 등급 이상 공개',
      };

  static CommunityVisibility fromDb(String? raw) {
    final v = (raw ?? 'public').trim().toLowerCase();
    return switch (v) {
      'directors_only' || 'directors-only' => CommunityVisibility.directorsOnly,
      'region_only' || 'region-only' => CommunityVisibility.regionOnly,
      'gold_plus' || 'gold-plus' || 'gold+' => CommunityVisibility.goldPlus,
      _ => CommunityVisibility.public,
    };
  }

  /// 뷰어가 잠금 해제 본문을 볼 수 있는지.
  bool canView({
    required ShopTierBadge viewerTier,
    required bool isAuthor,
    required bool isDirector,
  }) {
    if (isAuthor) return true;
    return switch (this) {
      CommunityVisibility.public => true,
      CommunityVisibility.directorsOnly => isDirector,
      CommunityVisibility.regionOnly => true, // region filter deferred
      CommunityVisibility.goldPlus =>
        viewerTier.rank >= ShopTierBadge.gold.rank,
    };
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
    this.vendorName = '',
    this.metadata = const {},
  });

  final String id;
  final String mediaId;
  final String tagKind;
  final String label;
  final double normX;
  final double normY;
  final String? partnerId;
  final String? externalUrl;
  final String vendorName;
  final Map<String, dynamic> metadata;

  factory CommunityPostTag.fromMap(Map<String, dynamic> map) {
    final metaRaw = map['metadata'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};
    final vendor = DbMap.asText(
      map['vendor_name'] ?? map['vendorName'] ?? meta['vendor_name'],
    );
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
      vendorName: vendor,
      metadata: meta,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'media_id': mediaId,
        'tag_kind': tagKind,
        'label': label.trim(),
        'norm_x': normX.clamp(0.0, 1.0),
        'norm_y': normY.clamp(0.0, 1.0),
        if (externalUrl != null && externalUrl!.trim().isNotEmpty)
          'external_url': externalUrl!.trim(),
        'metadata': {
          ...metadata,
          if (vendorName.trim().isNotEmpty) 'vendor_name': vendorName.trim(),
        },
      };
}

/// 작성 중 핀 (미디어 업로드 전 로컬 인덱스 기준).
class CommunityTagDraft {
  const CommunityTagDraft({
    required this.mediaIndex,
    required this.label,
    required this.normX,
    required this.normY,
    this.vendorName = '',
    this.externalUrl = '',
    this.tagKind = 'product',
  });

  final int mediaIndex;
  final String label;
  final String vendorName;
  final String externalUrl;
  final String tagKind;
  final double normX;
  final double normY;
}

class DeviceReview {
  const DeviceReview({
    required this.postId,
    this.deviceName = '',
    this.brand = '',
    this.model = '',
    this.deviceCategory = '',
    this.usageMonths = 0,
    this.sessionsPerWeek = 0,
    this.rating,
    this.pros = const [],
    this.cons = const [],
    this.wouldRecommend,
  });

  final String postId;
  final String deviceName;
  final String brand;
  final String model;
  final String deviceCategory;
  final int usageMonths;
  final int sessionsPerWeek;
  final double? rating;
  final List<String> pros;
  final List<String> cons;
  final bool? wouldRecommend;

  factory DeviceReview.fromMap(Map<String, dynamic> map) {
    final rawRating = map['rating'];
    double? rating;
    if (rawRating is num) rating = rawRating.toDouble();
    return DeviceReview(
      postId: DbMap.asText(map['post_id'] ?? map['postId']),
      deviceName: DbMap.asText(map['device_name'] ?? map['deviceName']),
      brand: DbMap.asText(map['brand']),
      model: DbMap.asText(map['model']),
      deviceCategory: DbMap.asText(
        map['device_category'] ?? map['deviceCategory'],
      ),
      usageMonths: DbMap.asInt(map['usage_months'] ?? map['usageMonths']),
      sessionsPerWeek: DbMap.asInt(
        map['sessions_per_week'] ?? map['sessionsPerWeek'],
      ),
      rating: rating,
      pros: DbMap.asStringList(map['pros']),
      cons: DbMap.asStringList(map['cons']),
      wouldRecommend: map['would_recommend'] is bool
          ? map['would_recommend'] as bool
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'device_name': deviceName.trim(),
        'brand': brand.trim(),
        'model': model.trim(),
        'device_category': deviceCategory.trim(),
        'usage_months': usageMonths,
        'sessions_per_week': sessionsPerWeek,
        if (rating != null) 'rating': rating,
        'pros': pros,
        'cons': cons,
        if (wouldRecommend != null) 'would_recommend': wouldRecommend,
      };
}

class DeviceReviewDraft {
  const DeviceReviewDraft({
    required this.deviceName,
    this.brand = '',
    this.model = '',
    this.usageMonths = 0,
    this.rating = 5,
    this.pros = const [],
    this.cons = const [],
    this.wouldRecommend = true,
  });

  final String deviceName;
  final String brand;
  final String model;
  final int usageMonths;
  final double rating;
  final List<String> pros;
  final List<String> cons;
  final bool wouldRecommend;
}

class MarketListingDraft {
  const MarketListingDraft({
    required this.deviceName,
    required this.price,
    this.brand = '',
    this.condition = 'good',
    this.contactPhone = '',
    this.contactNote = '',
    this.status = MarketListingStatus.active,
  });

  final String deviceName;
  final String brand;
  final int price;
  final String condition;
  final String contactPhone;
  final String contactNote;
  final MarketListingStatus status;
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

  MarketListing copyWith({MarketListingStatus? status}) {
    return MarketListing(
      id: id,
      postId: postId,
      shopId: shopId,
      deviceName: deviceName,
      brand: brand,
      model: model,
      price: price,
      condition: condition,
      status: status ?? this.status,
      contactPhone: contactPhone,
      contactNote: contactNote,
      region: region,
    );
  }

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
    this.deviceReview,
    this.createdAt,
    this.shopName = '',
    this.shopOwnerName = '',
    this.shopAvatarUrl,
    this.tierBadge = ShopTierBadge.none,
    this.businessVerified = false,
    this.visibility = CommunityVisibility.public,
    this.sourceChartId,
    this.isBodyLocked = false,
    this.unlockCost = 5,
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
  final DeviceReview? deviceReview;
  final DateTime? createdAt;
  final String shopName;
  final String shopOwnerName;
  final String? shopAvatarUrl;
  final ShopTierBadge tierBadge;
  final bool businessVerified;
  final CommunityVisibility visibility;
  final String? sourceChartId;

  /// 서버 `list_community_posts_safe` 가 마스킹한 본문 (클라 변조 불가).
  final bool isBodyLocked;

  /// Echo 페이월 해금 비용 (1E=₩100).
  final int unlockCost;

  String get authorDisplayName {
    final owner = shopOwnerName.trim();
    if (owner.isNotEmpty) return owner;
    final name = shopName.trim();
    if (name.isNotEmpty) return name;
    return '원장';
  }

  String? get primaryImageUrl {
    for (final m in media) {
      final u = m.imageUrl.trim();
      if (u.startsWith('http') || u.startsWith('data:')) return u;
    }
    return null;
  }

  List<CommunityPostTag> tagsForMedia(String mediaId) =>
      tags.where((t) => t.mediaId == mediaId).toList(growable: false);

  CommunityPost copyWith({
    MarketListing? listing,
    DeviceReview? deviceReview,
    List<CommunityPostTag>? tags,
    String? shopName,
    String? shopOwnerName,
    String? shopAvatarUrl,
    ShopTierBadge? tierBadge,
    bool? businessVerified,
    CommunityVisibility? visibility,
    String? sourceChartId,
    bool? isBodyLocked,
    int? unlockCost,
  }) {
    return CommunityPost(
      id: id,
      shopId: shopId,
      authorUserId: authorUserId,
      postType: postType,
      title: title,
      body: body,
      styleTags: styleTags,
      regionCode: regionCode,
      likeCount: likeCount,
      commentCount: commentCount,
      saveCount: saveCount,
      media: media,
      tags: tags ?? this.tags,
      listing: listing ?? this.listing,
      deviceReview: deviceReview ?? this.deviceReview,
      createdAt: createdAt,
      shopName: shopName ?? this.shopName,
      shopOwnerName: shopOwnerName ?? this.shopOwnerName,
      shopAvatarUrl: shopAvatarUrl ?? this.shopAvatarUrl,
      tierBadge: tierBadge ?? this.tierBadge,
      businessVerified: businessVerified ?? this.businessVerified,
      visibility: visibility ?? this.visibility,
      sourceChartId: sourceChartId ?? this.sourceChartId,
      isBodyLocked: isBodyLocked ?? this.isBodyLocked,
      unlockCost: unlockCost ?? this.unlockCost,
    );
  }

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    final mediaRaw = map['post_media'] ?? map['media'];
    final media = <CommunityPostMedia>[];
    final tags = <CommunityPostTag>[];
    if (mediaRaw is List) {
      for (final e in mediaRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        media.add(CommunityPostMedia.fromMap(m));
        final nestedTags = m['post_tags'] ?? m['tags'];
        if (nestedTags is List) {
          for (final t in nestedTags) {
            if (t is Map) {
              tags.add(
                CommunityPostTag.fromMap(Map<String, dynamic>.from(t)),
              );
            }
          }
        }
      }
      media.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final tagsRaw = map['post_tags'] ?? map['tags'];
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

    DeviceReview? review;
    final reviewRaw = map['device_reviews'] ?? map['device_review'];
    if (reviewRaw is Map) {
      review = DeviceReview.fromMap(Map<String, dynamic>.from(reviewRaw));
    } else if (reviewRaw is List && reviewRaw.isNotEmpty) {
      final first = reviewRaw.first;
      if (first is Map) {
        review = DeviceReview.fromMap(Map<String, dynamic>.from(first));
      }
    }

    final shopRaw = map['shops'] ?? map['shop'];
    var shopName = '';
    var shopOwnerName = '';
    String? shopAvatarUrl;
    var tier = ShopTierBadge.none;
    if (shopRaw is Map) {
      final s = Map<String, dynamic>.from(shopRaw);
      shopName = DbMap.asText(s['name']);
      shopOwnerName = DbMap.asText(s['owner_name'] ?? s['ownerName']);
      shopAvatarUrl = DbMap.asTextOrNull(
        s['profile_image_url'] ?? s['profileImageUrl'],
      );
      tier = ShopTierBadge.fromDb(
        DbMap.asText(s['tier_badge'] ?? s['tierBadge']),
      );
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
      deviceReview: review,
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      shopName: shopName,
      shopOwnerName: shopOwnerName,
      shopAvatarUrl: shopAvatarUrl,
      tierBadge: tier,
      businessVerified: map['business_verified'] == true ||
          map['businessVerified'] == true,
      visibility: CommunityVisibility.fromDb(
        DbMap.asText(map['visibility'], 'public'),
      ),
      sourceChartId: DbMap.asTextOrNull(
        map['source_chart_id'] ?? map['sourceChartId'],
      ),
      isBodyLocked: map['is_body_locked'] == true ||
          map['isBodyLocked'] == true,
      unlockCost: DbMap.asInt(map['unlock_cost'] ?? map['unlockCost'], 5),
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
        if (sourceChartId != null && sourceChartId!.trim().isNotEmpty)
          'source_chart_id': sourceChartId!.trim(),
        'status': 'published',
        'visibility': visibility.dbValue,
      };
}
